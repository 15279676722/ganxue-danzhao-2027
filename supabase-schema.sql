-- 赣学单招学习系统 Supabase 数据库结构
-- 在 Supabase Dashboard → SQL Editor 中整段执行一次。

create extension if not exists pgcrypto;

create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null default '我的家庭',
  code text not null unique,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('parent', 'child')),
  full_name text not null default '',
  family_id uuid not null references public.families(id),
  created_at timestamptz not null default now()
);

create table if not exists public.questions (
  id text primary key,
  source_no integer,
  subject text not null,
  knowledge_point text not null,
  type text not null default '单选题',
  difficulty text not null default '基础',
  stem text not null,
  options jsonb not null default '{}'::jsonb,
  answer text not null default '',
  answer_text text not null default '',
  explanation text not null default '',
  source text not null default '',
  source_level text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.attempts (
  id text primary key,
  student_id uuid not null references auth.users(id) on delete cascade,
  question_id text not null,
  correct boolean not null,
  mode text not null default 'practice',
  ts bigint not null default extract(epoch from now()) * 1000
);

create table if not exists public.wrong_book (
  student_id uuid not null references auth.users(id) on delete cascade,
  question_id text not null,
  updated_at bigint not null default extract(epoch from now()) * 1000,
  primary key (student_id, question_id)
);

create index if not exists idx_questions_subject on public.questions(subject);
create index if not exists idx_questions_knowledge on public.questions(knowledge_point);
create index if not exists idx_attempts_student_ts on public.attempts(student_id, ts desc);
create index if not exists idx_wrong_student on public.wrong_book(student_id);

create or replace function public.generate_family_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  chars text[] := array['A','B','C','D','E','F','G','H','J','K','M','N','P','Q','R','S','T','U','V','W','X','Y','Z','2','3','4','5','6','7','8','9'];
  new_code text;
  code_exists boolean;
begin
  loop
    new_code := '';
    for i in 1..6 loop
      new_code := new_code || chars[1 + floor(random() * array_length(chars, 1))::int];
    end loop;
    select exists(select 1 from public.families f where f.code = new_code) into code_exists;
    exit when not code_exists;
  end loop;
  return new_code;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  user_role text := lower(coalesce(new.raw_user_meta_data ->> 'role', 'child'));
  user_name text := coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), case user_role when 'parent' then '家长' else '孩子' end);
  family_code text := upper(trim(coalesce(new.raw_user_meta_data ->> 'family_code', '')));
  family_id uuid;
begin
  if user_role not in ('parent', 'child') then
    raise exception 'role must be parent or child';
  end if;

  if user_role = 'parent' and family_code <> '' then
    select f.id into family_id from public.families f where f.code = family_code;
    if family_id is null then
      raise exception '家庭码不存在，请留空以创建新家庭';
    end if;
  elsif user_role = 'parent' then
    insert into public.families(name, code, created_by)
    values (user_name || '家庭', public.generate_family_code(), new.id)
    returning id into family_id;
  else
    if family_code = '' then
      raise exception '孩子注册必须填写家长提供的家庭码';
    end if;
    select f.id into family_id from public.families f where f.code = family_code;
    if family_id is null then
      raise exception '家庭码不存在';
    end if;
  end if;

  insert into public.profiles(id, role, full_name, family_id)
  values (new.id, user_role, user_name, family_id)
  on conflict (id) do update
    set role = excluded.role,
        full_name = excluded.full_name,
        family_id = excluded.family_id;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.current_family_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select family_id from public.profiles where id = auth.uid();
$$;

create or replace function public.is_parent()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'parent'
  );
$$;

alter table public.families enable row level security;
alter table public.profiles enable row level security;
alter table public.questions enable row level security;
alter table public.attempts enable row level security;
alter table public.wrong_book enable row level security;

-- 家庭：仅家庭成员可见
drop policy if exists families_member_select on public.families;
create policy families_member_select on public.families
  for select to authenticated
  using (id = public.current_family_id());

-- 资料：同一家庭互见；用户只能更新自己的资料
drop policy if exists profiles_family_select on public.profiles;
create policy profiles_family_select on public.profiles
  for select to authenticated
  using (family_id = public.current_family_id());

drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- 题库：登录后可读；仅家长可维护
drop policy if exists questions_authenticated_select on public.questions;
create policy questions_authenticated_select on public.questions
  for select to authenticated
  using (true);

drop policy if exists questions_parent_insert on public.questions;
create policy questions_parent_insert on public.questions
  for insert to authenticated
  with check (public.is_parent());

drop policy if exists questions_parent_update on public.questions;
create policy questions_parent_update on public.questions
  for update to authenticated
  using (public.is_parent())
  with check (public.is_parent());

drop policy if exists questions_parent_delete on public.questions;
create policy questions_parent_delete on public.questions
  for delete to authenticated
  using (public.is_parent());

-- 做题记录：本人可写；本人和同家庭家长可读
drop policy if exists attempts_select on public.attempts;
create policy attempts_select on public.attempts
  for select to authenticated
  using (
    student_id = auth.uid()
    or (
      public.is_parent()
      and exists (
        select 1 from public.profiles p
        where p.id = attempts.student_id
          and p.family_id = public.current_family_id()
      )
    )
  );

drop policy if exists attempts_self_insert on public.attempts;
create policy attempts_self_insert on public.attempts
  for insert to authenticated
  with check (student_id = auth.uid());

drop policy if exists attempts_self_update on public.attempts;
create policy attempts_self_update on public.attempts
  for update to authenticated
  using (student_id = auth.uid())
  with check (student_id = auth.uid());

-- 错题本：本人可写；本人和同家庭家长可读
drop policy if exists wrong_select on public.wrong_book;
create policy wrong_select on public.wrong_book
  for select to authenticated
  using (
    student_id = auth.uid()
    or (
      public.is_parent()
      and exists (
        select 1 from public.profiles p
        where p.id = wrong_book.student_id
          and p.family_id = public.current_family_id()
      )
    )
  );

drop policy if exists wrong_self_insert on public.wrong_book;
create policy wrong_self_insert on public.wrong_book
  for insert to authenticated
  with check (student_id = auth.uid());

drop policy if exists wrong_self_update on public.wrong_book;
create policy wrong_self_update on public.wrong_book
  for update to authenticated
  using (student_id = auth.uid())
  with check (student_id = auth.uid());

drop policy if exists wrong_self_delete on public.wrong_book;
create policy wrong_self_delete on public.wrong_book
  for delete to authenticated
  using (student_id = auth.uid());
