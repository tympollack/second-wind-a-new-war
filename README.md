# War: Second Wind

A real-time, multiplayer mobile card game built with Flutter and Supabase. An advanced variant of the classic "War" with special card statuses, comeback mechanics, and real-time multiplayer.

## Tech Stack

- **Frontend**: Flutter (Dart) - iOS & Android
- **Backend/Database**: Supabase (PostgreSQL)
- **Realtime**: Supabase Realtime Channels
- **Auth**: Supabase Auth (Anonymous or Email/Password)
- **State Management**: Riverpod

## Game Rules

### Standard War with Twists

- **54-card deck** (52 + 2 Jokers), split into 18 cards per player + 18 reserve (Second Wind deck)
- Cards have values 2-14 (Ace high) plus Jokers (rank 15)

### Card Statuses (Hierarchy)

1. **Joker** - Beats everything
2. **Musketeer** - Beats Trump and Normal
3. **Trump** - Beats Normal
4. **Normal** - Standard card

### Trump Declaration

First time two cards share the same suit, that suit becomes **Trump** for the rest of the game.

### The "Always War" Rule

If two cards share the same numeric value, it **always** triggers a War, regardless of suit or status.

### War Resolution

Both players place 3 cards face down and 1 face up. The face-up cards follow the same comparison rules. Equal values = Double War. If a player has < 4 cards, the last card is face up with all others face down.

### War of Attrition

When a War occurs, the 2 tied battle cards are removed from the game permanently. During the first War, the remaining pair of that rank become **Musketeers**.

### Second Wind

When a player's deck hits 0 cards for the first time, they receive the 18-card reserve deck. This can only happen once per game.

## Setup

### Prerequisites

- Flutter SDK 3.44+
- A Supabase project

### Installation

```bash
flutter pub get
cp .env.example .env
# Fill in your Supabase URL and anon key
```

### Supabase Setup

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Run the SQL migration in `supabase/migrations/00001_initial_schema.sql`
3. Enable Anonymous Sign-in in Authentication > Providers
4. Set your project URL and anon key via environment variables

### Running

```bash
# With Supabase config
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Project Structure

```
lib/
  models/          - Data models (PlayingCard, GameState, Achievement)
  engine/          - Game logic engine (deck, comparison, war resolution)
  services/        - Supabase service layer
  providers/       - Riverpod state management
  screens/         - UI screens (auth, lobby, game, stats, settings, etc.)
  widgets/         - Reusable UI components
  theme/           - App theme and colors
supabase/
  migrations/      - SQL schema migrations
assets/
  images/          - Background images and card back skins
  audio/           - Sound effects
```

## Development

```bash
flutter analyze    # Run linter
flutter test       # Run tests
flutter build apk  # Build Android APK
flutter build ios  # Build iOS
```
