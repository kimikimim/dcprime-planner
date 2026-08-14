-- ============================================================
-- 대치프라임 플래너 (dcprime-planner) - planner 스키마 셋업
-- dcprime-academy와 같은 Supabase 프로젝트(DB)를 공유하되,
-- 스키마를 분리해서(public과 별개) 독립 운영
-- Supabase SQL Editor에 전체 붙여넣고 한 번에 실행
--
-- ⚠️ 실행 후 수동 설정 필요:
--   Supabase Dashboard → Project Settings → Data API →
--   "Exposed schemas"에 `planner` 추가 (기본은 public만 노출됨,
--   이걸 안 하면 PostgREST가 planner 스키마를 API로 못 찾음)
-- ============================================================

create schema if not exists planner;
grant usage on schema planner to anon, authenticated;

-- ────────────────────────────────────────────
-- 1. students (학생, PIN 로그인)
-- ────────────────────────────────────────────
create table if not exists planner.students (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  school text,
  grade text,               -- 고2 / 고3
  pin text not null unique, -- 4자리 숫자, 로그인 자격증명
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table planner.students enable row level security;
-- 정책 없음 = anon 직접 select/insert/update/delete 전부 차단 (verify_pin RPC로만 조회)

create or replace function planner.verify_pin(p_pin text)
returns table (id uuid, name text, grade text)
language plpgsql
security definer
set search_path = planner, pg_temp
as $$
begin
  return query
    select s.id, s.name, s.grade
    from planner.students s
    where s.pin = p_pin and s.is_active = true;
end;
$$;
grant execute on function planner.verify_pin(text) to anon;

-- ────────────────────────────────────────────
-- 2. admin_config (관리자 비밀번호) — admin_config 패턴과 동일
-- ────────────────────────────────────────────
create table if not exists planner.admin_config (
  key text primary key,
  value text not null
);
alter table planner.admin_config enable row level security;
-- 정책 없음 = anon 직접 조회 불가

insert into planner.admin_config (key, value)
values ('admin_password', 'Planner0979!')
on conflict (key) do nothing;
-- ⚠️ 위 기본 비밀번호는 배포 전에 아래 UPDATE로 반드시 바꾸세요:
-- update planner.admin_config set value = '원하는비밀번호' where key = 'admin_password';

create or replace function planner.verify_admin_password(pw text)
returns boolean
language plpgsql
security definer
set search_path = planner, pg_temp
as $$
declare
  stored_pw text;
begin
  select value into stored_pw from planner.admin_config where key = 'admin_password';
  return stored_pw = pw;
end;
$$;
grant execute on function planner.verify_admin_password(text) to anon;

-- 관리자 화면(students 테이블 CRUD)은 RLS 정책 없이 위 RPC로 세션 게이트만 하고,
-- anon 직접 접근은 dcprime-academy의 admin_config/adminssh 방식과 동일하게
-- "테이블 자체는 잠그고 관리자 페이지에서만 별도 처리"하는 대신,
-- students CRUD는 프론트가 로그인 게이트 뒤에서 anon 키로 직접 하므로 select/insert/update/delete 정책을 연다.
drop policy if exists "anon all students" on planner.students;
create policy "anon all students" on planner.students
  for all to anon using (true) with check (true);
grant select, insert, update, delete on planner.students to anon;

-- ────────────────────────────────────────────
-- 3. todos (일일/주간 할일 체크리스트)
-- ────────────────────────────────────────────
create table if not exists planner.todos (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references planner.students(id) on delete cascade,
  item_date date not null,              -- daily: 해당 날짜 / weekly: 그 주 월요일
  scope text not null default 'daily',  -- 'daily' | 'weekly'
  subject text,
  content text not null,
  is_done boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
alter table planner.todos enable row level security;
drop policy if exists "anon all todos" on planner.todos;
create policy "anon all todos" on planner.todos
  for all to anon using (true) with check (true);
grant select, insert, update, delete on planner.todos to anon;

create index if not exists idx_todos_student_date on planner.todos(student_id, scope, item_date);

-- ────────────────────────────────────────────
-- 4. study_logs (학습시간 기록)
-- ────────────────────────────────────────────
create table if not exists planner.study_logs (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references planner.students(id) on delete cascade,
  log_date date not null,
  subject text,
  minutes int not null check (minutes > 0),
  memo text,
  created_at timestamptz not null default now()
);
alter table planner.study_logs enable row level security;
drop policy if exists "anon all study_logs" on planner.study_logs;
create policy "anon all study_logs" on planner.study_logs
  for all to anon using (true) with check (true);
grant select, insert, update, delete on planner.study_logs to anon;

create index if not exists idx_study_logs_student_date on planner.study_logs(student_id, log_date);

-- ────────────────────────────────────────────
-- 5. goals (목표 / D-Day)
-- ────────────────────────────────────────────
create table if not exists planner.goals (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references planner.students(id) on delete cascade,
  title text not null,
  target_date date not null,
  category text,
  memo text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table planner.goals enable row level security;
drop policy if exists "anon all goals" on planner.goals;
create policy "anon all goals" on planner.goals
  for all to anon using (true) with check (true);
grant select, insert, update, delete on planner.goals to anon;

create index if not exists idx_goals_student on planner.goals(student_id, is_active, target_date);

-- ────────────────────────────────────────────
-- 6. timetable_entries (학생이 직접 등록하는 개인 시간표)
-- ────────────────────────────────────────────
create table if not exists planner.timetable_entries (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references planner.students(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6), -- 0=월 ... 6=일
  start_time time not null,
  end_time time,
  subject text,
  content text not null,
  created_at timestamptz not null default now()
);
alter table planner.timetable_entries enable row level security;
drop policy if exists "anon all timetable_entries" on planner.timetable_entries;
create policy "anon all timetable_entries" on planner.timetable_entries
  for all to anon using (true) with check (true);
grant select, insert, update, delete on planner.timetable_entries to anon;

create index if not exists idx_timetable_entries_student on planner.timetable_entries(student_id, day_of_week, start_time);
