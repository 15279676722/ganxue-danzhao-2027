-- 赣学单招学习系统：公共题库 / 私人题库改造
-- 在 Supabase Dashboard -> SQL Editor 中整段执行一次。
-- 已有 80 道题会自动成为公共题库；第一个注册的家长会被设为管理员。

-- 1. 题目增加可见范围、归属人、归属家庭
alter table public.questions
  add column if not exists visibility text not null default 'public'
    check (visibility in ('public', 'private')),
  add column if not exists owner_id uuid references auth.users(id),
  add column if not exists family_id uuid references public.families(id);

create index if not exists idx_questions_family on public.questions(family_id);
create index if not exists idx_questions_visibility on public.questions(visibility);

-- 2. 家长资料增加管理员标记
alter table public.profiles
  add column if not exists is_admin boolean not null default false;

-- 3. 把第一个注册的家长设为管理员（公共题库维护人）
update public.profiles
set is_admin = true
where role = 'parent'
  and id = (
    select id from public.profiles
    where role = 'parent'
    order by created_at asc
    limit 1
  );

-- 4. 管理员判断函数
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

-- 5. 重写题库 RLS 策略
drop policy if exists questions_authenticated_select on public.questions;
drop policy if exists questions_parent_insert on public.questions;
drop policy if exists questions_parent_update on public.questions;
drop policy if exists questions_parent_delete on public.questions;

-- 公共题所有登录用户可读；私人题只有同一家庭成员可读
create policy questions_visible_select on public.questions
  for select to authenticated
  using (
    visibility = 'public'
    or family_id = public.current_family_id()
  );

-- 新增：只有管理员能新增公共题；家长只能给自己家庭新增私人题
create policy questions_managed_insert on public.questions
  for insert to authenticated
  with check (
    (visibility = 'public' and public.is_admin())
    or
    (visibility = 'private'
      and public.is_parent()
      and family_id = public.current_family_id()
      and owner_id = auth.uid())
  );

-- 修改：公共题仅管理员；私人题仅同家庭家长
create policy questions_managed_update on public.questions
  for update to authenticated
  using (
    (visibility = 'public' and public.is_admin())
    or
    (visibility = 'private'
      and public.is_parent()
      and family_id = public.current_family_id())
  )
  with check (
    (visibility = 'public' and public.is_admin())
    or
    (visibility = 'private'
      and public.is_parent()
      and family_id = public.current_family_id())
  );

-- 删除：公共题仅管理员；私人题仅同家庭家长
create policy questions_managed_delete on public.questions
  for delete to authenticated
  using (
    (visibility = 'public' and public.is_admin())
    or
    (visibility = 'private'
      and public.is_parent()
      and family_id = public.current_family_id())
  );
