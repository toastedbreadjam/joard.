-- joard. collaborative whiteboard schema
-- Run in Supabase Dashboard -> SQL Editor.
-- WARNING: This starter schema allows anonymous read/write access to all boards,
-- board names, objects, and revisions. Do not use for private or sensitive content.
-- For production, add Supabase Auth and room-specific membership/RLS policies.

create table if not exists public.whiteboard_items (
  id uuid primary key,
  board_id text not null,
  data jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists whiteboard_items_board_id_idx
  on public.whiteboard_items (board_id);

create table if not exists public.whiteboard_boards (
  id text primary key,
  title text not null default 'Untitled whiteboard',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists whiteboard_boards_updated_at_idx
  on public.whiteboard_boards (updated_at desc);

create table if not exists public.whiteboard_versions (
  id uuid primary key,
  board_id text not null,
  title text not null default 'Untitled whiteboard',
  snapshot jsonb not null default '[]'::jsonb,
  note text not null default 'Autosave',
  created_at timestamptz not null default now()
);
create index if not exists whiteboard_versions_board_created_idx
  on public.whiteboard_versions (board_id, created_at desc);

alter table public.whiteboard_items enable row level security;
alter table public.whiteboard_boards enable row level security;
alter table public.whiteboard_versions enable row level security;

grant select, insert, update, delete on public.whiteboard_items to anon, authenticated;
grant select, insert, update, delete on public.whiteboard_boards to anon, authenticated;
grant select, insert, update, delete on public.whiteboard_versions to anon, authenticated;

-- Object table policies. These preserve the original starter policy names where possible.
drop policy if exists "Public board items are readable" on public.whiteboard_items;
create policy "Public board items are readable" on public.whiteboard_items
  for select to anon, authenticated using (true);
drop policy if exists "Public board items can be inserted" on public.whiteboard_items;
create policy "Public board items can be inserted" on public.whiteboard_items
  for insert to anon, authenticated with check (true);
drop policy if exists "Public board items can be updated" on public.whiteboard_items;
create policy "Public board items can be updated" on public.whiteboard_items
  for update to anon, authenticated using (true) with check (true);
drop policy if exists "Public board items can be deleted" on public.whiteboard_items;
create policy "Public board items can be deleted" on public.whiteboard_items
  for delete to anon, authenticated using (true);

-- Board library policies. Board names are globally visible with this starter policy.
drop policy if exists "Public whiteboard boards are readable" on public.whiteboard_boards;
create policy "Public whiteboard boards are readable" on public.whiteboard_boards
  for select to anon, authenticated using (true);
drop policy if exists "Public whiteboard boards can be inserted" on public.whiteboard_boards;
create policy "Public whiteboard boards can be inserted" on public.whiteboard_boards
  for insert to anon, authenticated with check (true);
drop policy if exists "Public whiteboard boards can be updated" on public.whiteboard_boards;
create policy "Public whiteboard boards can be updated" on public.whiteboard_boards
  for update to anon, authenticated using (true) with check (true);
drop policy if exists "Public whiteboard boards can be deleted" on public.whiteboard_boards;
create policy "Public whiteboard boards can be deleted" on public.whiteboard_boards
  for delete to anon, authenticated using (true);

-- Revision history policies. Anyone with the public key can read or alter all revisions.
drop policy if exists "Public whiteboard versions are readable" on public.whiteboard_versions;
create policy "Public whiteboard versions are readable" on public.whiteboard_versions
  for select to anon, authenticated using (true);
drop policy if exists "Public whiteboard versions can be inserted" on public.whiteboard_versions;
create policy "Public whiteboard versions can be inserted" on public.whiteboard_versions
  for insert to anon, authenticated with check (true);
drop policy if exists "Public whiteboard versions can be updated" on public.whiteboard_versions;
create policy "Public whiteboard versions can be updated" on public.whiteboard_versions
  for update to anon, authenticated using (true) with check (true);
drop policy if exists "Public whiteboard versions can be deleted" on public.whiteboard_versions;
create policy "Public whiteboard versions can be deleted" on public.whiteboard_versions
  for delete to anon, authenticated using (true);

-- Broadcast channels are used for live drawing and cursor updates; Postgres Changes replication is unnecessary.
