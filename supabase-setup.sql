
-- joard. secure collaborative whiteboard schema
-- Run the whole file in Supabase Dashboard -> SQL Editor.
-- IMPORTANT: Enable Anonymous Sign-Ins under Authentication settings after running this.
-- This file removes the old broad anonymous policies from the original joard starter.
-- Publishable keys are public; room passwords are checked server-side and room data is gated by RLS.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.whiteboard_boards (
  id text primary key,
  title text not null default 'Untitled whiteboard',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists whiteboard_boards_updated_at_idx
  on public.whiteboard_boards (updated_at desc);

create table if not exists public.whiteboard_items (
  id uuid primary key,
  board_id text not null references public.whiteboard_boards(id) on delete cascade,
  data jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists whiteboard_items_board_id_idx
  on public.whiteboard_items (board_id);

-- Kept for compatibility with older installations.
-- The joard. interface no longer uses revision history.
create table if not exists public.whiteboard_versions (
  id uuid primary key,
  board_id text not null references public.whiteboard_boards(id) on delete cascade,
  title text not null default 'Untitled whiteboard',
  snapshot jsonb not null default '[]'::jsonb,
  note text not null default 'Autosave',
  created_at timestamptz not null default now()
);
create index if not exists whiteboard_versions_board_created_idx
  on public.whiteboard_versions (board_id, created_at desc);

create table if not exists public.whiteboard_room_settings (
  board_id text primary key references public.whiteboard_boards(id) on delete cascade,
  room_name text not null,
  room_name_key text not null unique,
  owner_id uuid references auth.users(id) on delete set null,
  is_public boolean not null default true,
  password_hash text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint whiteboard_private_rooms_need_password
    check (is_public or password_hash is not null)
);
create index if not exists whiteboard_room_settings_owner_idx
  on public.whiteboard_room_settings (owner_id);

create table if not exists public.whiteboard_room_members (
  board_id text not null references public.whiteboard_room_settings(board_id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (board_id,user_id)
);
create index if not exists whiteboard_room_members_user_idx
  on public.whiteboard_room_members (user_id,board_id);

-- Migrate older boards to public rooms.
-- The first authenticated visitor can claim ownership.
with ranked as (
  select b.id,
         coalesce(nullif(btrim(b.title),''),'Untitled whiteboard') as clean_title,
         count(*) over (
           partition by lower(coalesce(nullif(btrim(b.title),''),'Untitled whiteboard'))
         ) as same_name_count
  from public.whiteboard_boards b
)
insert into public.whiteboard_room_settings
  (board_id,room_name,room_name_key,owner_id,is_public,password_hash)
select r.id,
       case when r.same_name_count > 1
         then r.clean_title || ' (' || left(r.id,6) || ')'
         else r.clean_title
       end,
       lower(case when r.same_name_count > 1
         then r.clean_title || ' (' || left(r.id,6) || ')'
         else r.clean_title
       end),
       null,true,null
from ranked r
where not exists (
  select 1 from public.whiteboard_room_settings s where s.board_id=r.id
)
on conflict (board_id) do nothing;

alter table public.whiteboard_boards enable row level security;
alter table public.whiteboard_items enable row level security;
alter table public.whiteboard_versions enable row level security;
alter table public.whiteboard_room_settings enable row level security;
alter table public.whiteboard_room_members enable row level security;

-- Remove existing policies on these five tables so older permissive
-- policies cannot override the room-scoped policies below.
do $$
declare p record;
begin
  for p in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname='public'
      and tablename in (
        'whiteboard_boards',
        'whiteboard_items',
        'whiteboard_versions',
        'whiteboard_room_settings',
        'whiteboard_room_members'
      )
  loop
    execute format(
      'drop policy if exists %I on %I.%I',
      p.policyname,p.schemaname,p.tablename
    );
  end loop;
end $$;

-- Room settings contain password hashes; clients access them through RPC only.
revoke all on public.whiteboard_room_settings from anon, authenticated;
revoke all on public.whiteboard_room_members from anon, authenticated;
revoke all on public.whiteboard_boards from anon;
revoke all on public.whiteboard_items from anon;
revoke all on public.whiteboard_versions from anon;

grant select, insert, update, delete on public.whiteboard_boards to authenticated;
grant select, insert, update, delete on public.whiteboard_items to authenticated;
grant select, insert, update, delete on public.whiteboard_versions to authenticated;
grant select on public.whiteboard_room_members to authenticated;

create policy "joard members select boards"
on public.whiteboard_boards for select to authenticated
using (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_boards.id and m.user_id=(select auth.uid())
  )
);

create policy "joard members insert boards"
on public.whiteboard_boards for insert to authenticated
with check (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_boards.id and m.user_id=(select auth.uid())
  )
);

create policy "joard owners update boards"
on public.whiteboard_boards for update to authenticated
using (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_boards.id
      and m.user_id=(select auth.uid()) and m.role='owner'
  )
)
with check (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_boards.id
      and m.user_id=(select auth.uid()) and m.role='owner'
  )
);

create policy "joard owners delete boards"
on public.whiteboard_boards for delete to authenticated
using (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_boards.id
      and m.user_id=(select auth.uid()) and m.role='owner'
  )
);

create policy "joard members select items"
on public.whiteboard_items for select to authenticated
using (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_items.board_id and m.user_id=(select auth.uid())
  )
);

create policy "joard members insert items"
on public.whiteboard_items for insert to authenticated
with check (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_items.board_id and m.user_id=(select auth.uid())
  )
);

create policy "joard members update items"
on public.whiteboard_items for update to authenticated
using (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_items.board_id and m.user_id=(select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_items.board_id and m.user_id=(select auth.uid())
  )
);

create policy "joard members delete items"
on public.whiteboard_items for delete to authenticated
using (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_items.board_id and m.user_id=(select auth.uid())
  )
);

create policy "joard members select versions legacy"
on public.whiteboard_versions for select to authenticated
using (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_versions.board_id and m.user_id=(select auth.uid())
  )
);

create policy "joard members insert versions legacy"
on public.whiteboard_versions for insert to authenticated
with check (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_versions.board_id and m.user_id=(select auth.uid())
  )
);

create policy "joard members update versions legacy"
on public.whiteboard_versions for update to authenticated
using (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_versions.board_id and m.user_id=(select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_versions.board_id and m.user_id=(select auth.uid())
  )
);

create policy "joard members delete versions legacy"
on public.whiteboard_versions for delete to authenticated
using (
  exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=whiteboard_versions.board_id and m.user_id=(select auth.uid())
  )
);

create policy "joard users read their memberships"
on public.whiteboard_room_members for select to authenticated
using (user_id=(select auth.uid()));

-- Create a room. Passwords are stored as salted one-way hashes.
create or replace function public.create_whiteboard_room(
  p_board_id text,
  p_room_name text,
  p_password text default null,
  p_is_public boolean default true
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_name text;
  v_hash text := null;
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return jsonb_build_object('ok',false,'error','Please reconnect and try again.');
  end if;

  v_name := left(btrim(coalesce(p_room_name,'')),90);
  if v_name='' then
    return jsonb_build_object('ok',false,'error','Enter a room name.');
  end if;

  if not coalesce(p_is_public,true) then
    if p_password is null or length(btrim(p_password)) < 4 then
      return jsonb_build_object('ok',false,'error','A private room password must be at least 4 characters.');
    end if;
    v_hash := extensions.crypt(p_password,extensions.gen_salt('bf'));
  end if;

  if exists (select 1 from public.whiteboard_boards b where b.id=p_board_id)
     or exists (
       select 1 from public.whiteboard_room_settings s
       where s.room_name_key=lower(v_name)
     ) then
    return jsonb_build_object('ok',false,'error','A room with that ID or name already exists. Choose another name.');
  end if;

  insert into public.whiteboard_boards(id,title) values (p_board_id,v_name);

  insert into public.whiteboard_room_settings
    (board_id,room_name,room_name_key,owner_id,is_public,password_hash)
  values
    (p_board_id,v_name,lower(v_name),v_user,coalesce(p_is_public,true),v_hash);

  insert into public.whiteboard_room_members(board_id,user_id,role)
  values (p_board_id,v_user,'owner');

  return jsonb_build_object(
    'ok',true,
    'board_id',p_board_id,
    'title',v_name,
    'room_name',v_name,
    'is_public',coalesce(p_is_public,true),
    'has_password',v_hash is not null,
    'is_owner',true,
    'is_member',true
  );
end;
$$;

-- Return safe room metadata; never expose password hashes.
create or replace function public.get_whiteboard_room(p_board_id text)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'board_id',s.board_id,
    'room_name',s.room_name,
    'title',b.title,
    'is_public',s.is_public,
    'has_password',(s.password_hash is not null),
    'is_member',exists(
      select 1 from public.whiteboard_room_members m
      where m.board_id=s.board_id and m.user_id=(select auth.uid())
    ),
    'is_owner',(s.owner_id=(select auth.uid()))
  )
  from public.whiteboard_room_settings s
  join public.whiteboard_boards b on b.id=s.board_id
  where s.board_id=p_board_id
  limit 1;
$$;

-- Join a room by ID or exact room name.
-- Public rooms need no password.
create or replace function public.join_whiteboard_room(
  p_board_id text default null,
  p_room_name text default null,
  p_password text default null
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return jsonb_build_object('ok',false,'error','Please reconnect and try again.');
  end if;

  if p_board_id is not null and p_board_id<>'' then
    select s.*,b.title into r
    from public.whiteboard_room_settings s
    join public.whiteboard_boards b on b.id=s.board_id
    where s.board_id=p_board_id
    for update of s;
  else
    select s.*,b.title into r
    from public.whiteboard_room_settings s
    join public.whiteboard_boards b on b.id=s.board_id
    where s.room_name_key=lower(btrim(coalesce(p_room_name,'')))
    limit 1
    for update of s;
  end if;

  if not found then
    return jsonb_build_object('ok',false,'error','Room not found. Check the name and try again.');
  end if;

  if not r.is_public and not exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=r.board_id and m.user_id=v_user
  ) then
    if p_password is null or btrim(p_password)='' then
      return jsonb_build_object('ok',false,'error','PASSWORD_REQUIRED');
    end if;
    if r.password_hash is null
       or extensions.crypt(p_password,r.password_hash) <> r.password_hash then
      return jsonb_build_object('ok',false,'error','Incorrect password');
    end if;
  end if;

  if r.owner_id is null then
    update public.whiteboard_room_settings
    set owner_id=v_user,updated_at=now()
    where board_id=r.board_id;
    r.owner_id:=v_user;
  end if;

  insert into public.whiteboard_room_members(board_id,user_id,role)
  values (
    r.board_id,
    v_user,
    case when r.owner_id=v_user then 'owner' else 'member' end
  )
  on conflict(board_id,user_id) do nothing;

  return jsonb_build_object(
    'ok',true,
    'board_id',r.board_id,
    'title',r.title,
    'room_name',r.room_name,
    'is_public',r.is_public,
    'has_password',(r.password_hash is not null),
    'is_owner',(r.owner_id=v_user),
    'is_member',true
  );
end;
$$;

-- Only the owner can rename a room or change its privacy.
-- A null password keeps an existing private-room password.
create or replace function public.update_whiteboard_room_access(
  p_board_id text,
  p_room_name text,
  p_is_public boolean,
  p_password text default null
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  v_name text;
  v_hash text;
begin
  select * into r
  from public.whiteboard_room_settings
  where board_id=p_board_id
  for update;

  if not found then
    return jsonb_build_object('ok',false,'error','Room not found.');
  end if;

  if r.owner_id is distinct from auth.uid() then
    return jsonb_build_object('ok',false,'error','Only the room owner can change these settings.');
  end if;

  v_name:=left(btrim(coalesce(p_room_name,'')),90);
  if v_name='' then
    return jsonb_build_object('ok',false,'error','Enter a room name.');
  end if;

  if exists (
    select 1 from public.whiteboard_room_settings s
    where s.room_name_key=lower(v_name) and s.board_id<>p_board_id
  ) then
    return jsonb_build_object('ok',false,'error','Another room already uses that name.');
  end if;

  if coalesce(p_is_public,true) then
    v_hash:=null;
  elsif p_password is not null and btrim(p_password)<>'' then
    if length(btrim(p_password)) < 4 then
      return jsonb_build_object('ok',false,'error','A room password must be at least 4 characters.');
    end if;
    v_hash:=extensions.crypt(p_password,extensions.gen_salt('bf'));
  else
    v_hash:=r.password_hash;
    if v_hash is null then
      return jsonb_build_object('ok',false,'error','Enter a password before making this room private.');
    end if;
  end if;

  update public.whiteboard_room_settings
  set room_name=v_name,
      room_name_key=lower(v_name),
      is_public=coalesce(p_is_public,true),
      password_hash=v_hash,
      updated_at=now()
  where board_id=p_board_id;

  update public.whiteboard_boards
  set title=v_name,updated_at=now()
  where id=p_board_id;

  return jsonb_build_object(
    'ok',true,
    'board_id',p_board_id,
    'title',v_name,
    'room_name',v_name,
    'is_public',coalesce(p_is_public,true),
    'has_password',(v_hash is not null),
    'is_owner',true,
    'is_member',true
  );
end;
$$;

-- Expose only the safe RPC operations to authenticated visitors.
revoke all on function public.create_whiteboard_room(text,text,text,boolean)
  from public, anon, authenticated;
revoke all on function public.get_whiteboard_room(text)
  from public, anon, authenticated;
revoke all on function public.join_whiteboard_room(text,text,text)
  from public, anon, authenticated;
revoke all on function public.update_whiteboard_room_access(text,text,boolean,text)
  from public, anon, authenticated;

grant execute on function public.create_whiteboard_room(text,text,text,boolean)
  to authenticated;
grant execute on function public.get_whiteboard_room(text)
  to authenticated;
grant execute on function public.join_whiteboard_room(text,text,text)
  to authenticated;
grant execute on function public.update_whiteboard_room_access(text,text,boolean,text)
  to authenticated;

-- Private Realtime channels: only authenticated members of the matching room
-- may send or receive. Use a Supabase project dedicated to joard.
drop policy if exists "joard members receive room realtime" on realtime.messages;
drop policy if exists "joard members send room realtime" on realtime.messages;

create policy "joard members receive room realtime"
on realtime.messages for select to authenticated
using (
  realtime.topic() like 'joard-%'
  and realtime.messages.extension in ('broadcast','presence')
  and exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=substr(realtime.topic(),7)
      and m.user_id=(select auth.uid())
  )
);

create policy "joard members send room realtime"
on realtime.messages for insert to authenticated
with check (
  realtime.topic() like 'joard-%'
  and realtime.messages.extension in ('broadcast','presence')
  and exists (
    select 1 from public.whiteboard_room_members m
    where m.board_id=substr(realtime.topic(),7)
      and m.user_id=(select auth.uid())
  )
);

-- In Supabase Dashboard, also turn OFF Realtime Settings -> Allow public access.
-- The frontend uses private channels, and these policies enforce room membership.
