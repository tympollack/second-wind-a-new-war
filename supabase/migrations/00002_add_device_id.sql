-- ============================================================
-- Add device_id to users for anonymous account linking
-- ============================================================

alter table public.users
  add column if not exists device_id text,
  add column if not exists is_anonymous boolean not null default false;

-- Index for looking up users by device_id
create index if not exists idx_users_device_id on public.users(device_id)
  where device_id is not null;
