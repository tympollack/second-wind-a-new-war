-- ============================================================
-- War: Second Wind  -  Supabase Schema
-- ============================================================

-- 1. Users table: player profiles & win/loss records
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Anonymous',
  wins int not null default 0,
  losses int not null default 0,
  games_played int not null default 0,
  wars_triggered int not null default 0,
  second_winds_used int not null default 0,
  selected_card_back text not null default 'evolution_matrix',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.users enable row level security;

create policy "Users can read any profile"
  on public.users for select
  using (true);

create policy "Users can insert their own profile"
  on public.users for insert
  with check (auth.uid() = id);

create policy "Users can update their own profile"
  on public.users for update
  using (auth.uid() = id);

-- 2. Matches table: lobby state and player assignments
create type match_status as enum ('waiting', 'in-progress', 'completed');

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  join_code text unique not null default upper(substr(md5(random()::text), 1, 6)),
  status match_status not null default 'waiting',
  player1_id uuid references public.users(id) on delete set null,
  player2_id uuid references public.users(id) on delete set null,
  winner_id uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.matches enable row level security;

create policy "Anyone authenticated can view matches"
  on public.matches for select
  using (auth.uid() is not null);

create policy "Authenticated users can create matches"
  on public.matches for insert
  with check (auth.uid() is not null and auth.uid() = player1_id);

create policy "Match participants can update"
  on public.matches for update
  using (
    auth.uid() = player1_id or auth.uid() = player2_id
  );

create policy "Match creator can delete"
  on public.matches for delete
  using (auth.uid() = player1_id);

-- 3. Game States table: serialized game state as JSONB
create table if not exists public.game_states (
  id uuid primary key default gen_random_uuid(),
  match_id uuid unique not null references public.matches(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  version int not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.game_states enable row level security;

create policy "Match participants can read game state"
  on public.game_states for select
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and (m.player1_id = auth.uid() or m.player2_id = auth.uid())
    )
  );

create policy "Match participants can insert game state"
  on public.game_states for insert
  with check (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and (m.player1_id = auth.uid() or m.player2_id = auth.uid())
    )
  );

create policy "Match participants can update game state"
  on public.game_states for update
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and (m.player1_id = auth.uid() or m.player2_id = auth.uid())
    )
  );

create policy "Match participants can delete game state"
  on public.game_states for delete
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and (m.player1_id = auth.uid() or m.player2_id = auth.uid())
    )
  );

-- 4. Achievements table: per-user achievement unlocks
create table if not exists public.user_achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  achievement_id text not null,
  unlocked_at timestamptz not null default now(),
  unique (user_id, achievement_id)
);

alter table public.user_achievements enable row level security;

create policy "Users can read any achievements"
  on public.user_achievements for select
  using (true);

create policy "Users can insert their own achievements"
  on public.user_achievements for insert
  with check (auth.uid() = user_id);

-- 5. Auto-update timestamps
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger users_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

create trigger matches_updated_at
  before update on public.matches
  for each row execute function public.set_updated_at();

create trigger game_states_updated_at
  before update on public.game_states
  for each row execute function public.set_updated_at();

-- 6. Enable Realtime on game_states and matches
alter publication supabase_realtime add table public.game_states;
alter publication supabase_realtime add table public.matches;
alter publication supabase_realtime add table public.users;
