import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

// Note: To use FCM HTTP v1 API, you usually need to generate an OAuth2 token 
// from a Google Service Account. There are Deno-compatible libraries for this,
// or you can use the legacy FCM API with a Server Key (easier, but deprecated).
// For this example, we assume you're using the HTTP v1 API and have a mechanism
// to get the access token, or use a 3rd party wrapper.
// As a placeholder, we use a generic HTTP POST for the push service.

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: any;
  old_record: any;
}

serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();

    // 1. Validate payload
    if (payload.type !== "UPDATE" || payload.table !== "game_states") {
      return new Response("Not a game state update", { status: 400 });
    }

    const oldState = payload.old_record?.state || {};
    const newState = payload.record?.state || {};

    // 2. Check if turn actually changed
    const oldTurn = oldState.turn;
    const newTurn = newState.turn;

    if (oldTurn === newTurn) {
      return new Response("Turn did not change", { status: 200 });
    }

    // 3. Initialize Supabase Admin Client
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing Supabase environment variables");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 4. Get the Match to find player IDs
    const matchId = payload.record.match_id;
    const { data: match, error: matchError } = await supabase
      .schema("wsw")
      .from("matches")
      .select("player1_id, player2_id")
      .eq("id", matchId)
      .single();

    if (matchError || !match) {
      throw new Error("Match not found");
    }

    // 5. Determine whose turn it is now
    let nextPlayerId: string | null = null;
    if (newTurn === "Player 1") {
      nextPlayerId = match.player1_id;
    } else if (newTurn === "Player 2") {
      nextPlayerId = match.player2_id;
    }

    if (!nextPlayerId) {
      return new Response("Next player ID not found (bot or unassigned)", { status: 200 });
    }

    // 6. Get the FCM Token of the next player
    const { data: user, error: userError } = await supabase
      .schema("wsw")
      .from("users")
      .select("fcm_token")
      .eq("id", nextPlayerId)
      .single();

    if (userError || !user || !user.fcm_token) {
      return new Response("User has no FCM token", { status: 200 });
    }

    // 7. Send Push Notification via FCM
    // WARNING: Replace [FCM_SERVER_KEY] with your actual server key 
    // or use OAuth2 for HTTP v1 API.
    const fcmToken = user.fcm_token;
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");

    if (!fcmServerKey) {
       console.log("Missing FCM_SERVER_KEY in env, skipping push.");
       return new Response("Missing FCM config", { status: 500 });
    }

    const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `key=${fcmServerKey}`,
      },
      body: JSON.stringify({
        to: fcmToken,
        notification: {
          title: "Your Turn!",
          body: "It's your move in War: Second Wind. Form up!",
          sound: "default",
        },
        data: {
          matchId: matchId,
          type: "turn_change",
        },
      }),
    });

    if (!fcmResponse.ok) {
      const errorText = await fcmResponse.text();
      console.error("FCM Error:", errorText);
      return new Response("Failed to send push", { status: 500 });
    }

    return new Response("Push notification sent successfully!", { status: 200 });
  } catch (error: any) {
    console.error("Error processing webhook:", error);
    return new Response(`Error: ${error.message}`, { status: 500 });
  }
});
