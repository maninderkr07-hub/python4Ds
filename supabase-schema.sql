-- ============================================================
-- PyDataPro — Supabase PostgreSQL Schema
-- Run this in: Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- Enable UUID generation
create extension if not exists "pgcrypto";

-- ─────────────────────────────────────────
-- ENUMS
-- ─────────────────────────────────────────
create type plan_type as enum ('free', 'weekly', 'monthly', 'yearly');
create type difficulty as enum ('easy', 'medium', 'hard');
create type tier_level as enum ('beginner', 'intermediate', 'advanced');
create type submission_status as enum ('accepted', 'wrong_answer', 'runtime_error', 'timeout');
create type payment_status as enum ('pending', 'success', 'failed', 'refunded');
create type badge_type as enum (
  'streak_7', 'streak_30', 'streak_60',
  'beginner_complete', 'intermediate_complete', 'advanced_complete',
  'speed_coder', 'project_builder', 'referral_5', 'first_submit'
);

-- ─────────────────────────────────────────
-- USERS (extends Supabase auth.users)
-- ─────────────────────────────────────────
create table public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  email           text not null,
  full_name       text,
  avatar_url      text,
  plan            plan_type not null default 'free',
  plan_expires_at timestamptz,
  streak_days     int not null default 0,
  longest_streak  int not null default 0,
  last_active_date date,
  xp_points       int not null default 0,
  problems_solved int not null default 0,
  referral_code   text unique default substring(md5(random()::text), 1, 8),
  referred_by     uuid references public.profiles(id),
  referral_count  int not null default 0,
  created_at      timestamptz default now()
);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─────────────────────────────────────────
-- PROBLEMS
-- ─────────────────────────────────────────
create table public.problems (
  id              uuid primary key default gen_random_uuid(),
  slug            text unique not null,
  title           text not null,
  description     text not null,
  difficulty      difficulty not null,
  tier            tier_level not null,
  topic           text not null,          -- e.g. 'numpy', 'pandas', 'ml'
  starter_code    text not null,
  solution_code   text not null,
  explanation     text,                   -- line-by-line explanation (markdown)
  hints           jsonb default '[]',     -- array of hint strings
  test_cases      jsonb not null,         -- [{ input, expected_output }]
  is_free         boolean default false,
  order_index     int default 0,
  created_at      timestamptz default now()
);

-- ─────────────────────────────────────────
-- SUBMISSIONS
-- ─────────────────────────────────────────
create table public.submissions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  problem_id      uuid not null references public.problems(id),
  code            text not null,
  status          submission_status not null,
  score           int default 0,          -- 0-100
  execution_ms    int,
  hint_used       boolean default false,
  submitted_at    timestamptz default now()
);

create index idx_submissions_user on public.submissions(user_id);
create index idx_submissions_problem on public.submissions(problem_id);

-- ─────────────────────────────────────────
-- TYPING SESSIONS (60-day challenge)
-- ─────────────────────────────────────────
create table public.typing_sessions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  wpm             int not null,
  accuracy        numeric(5,2) not null,   -- percentage
  duration_sec    int not null,
  challenge_day   int,                     -- 1–60 for the 60-day challenge
  code_snippet_id uuid references public.problems(id),
  recorded_at     timestamptz default now()
);

create index idx_typing_user on public.typing_sessions(user_id);

-- ─────────────────────────────────────────
-- PROJECTS
-- ─────────────────────────────────────────
create table public.projects (
  id              uuid primary key default gen_random_uuid(),
  slug            text unique not null,
  title           text not null,
  description     text not null,
  tier            tier_level not null,
  tech_stack      text[] not null,
  dataset_url     text,
  notebook_url    text,
  thumbnail_url   text,
  is_free         boolean default false,
  order_index     int default 0,
  created_at      timestamptz default now()
);

create table public.user_projects (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  project_id  uuid not null references public.projects(id),
  progress    int default 0,              -- 0-100 percent
  completed   boolean default false,
  started_at  timestamptz default now(),
  completed_at timestamptz,
  unique(user_id, project_id)
);

-- ─────────────────────────────────────────
-- PAYMENTS (Razorpay)
-- ─────────────────────────────────────────
create table public.payments (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references public.profiles(id) on delete cascade,
  razorpay_order_id   text unique not null,
  razorpay_payment_id text,
  razorpay_signature  text,
  plan                plan_type not null,
  amount_paise        int not null,        -- amount in paise (₹299 = 29900)
  status              payment_status not null default 'pending',
  created_at          timestamptz default now(),
  verified_at         timestamptz
);

create index idx_payments_user on public.payments(user_id);

-- Auto-upgrade plan on successful payment
create or replace function public.handle_payment_success()
returns trigger language plpgsql security definer as $$
declare
  expiry timestamptz;
begin
  if new.status = 'success' and old.status != 'success' then
    expiry := case new.plan
      when 'weekly'  then now() + interval '7 days'
      when 'monthly' then now() + interval '30 days'
      when 'yearly'  then now() + interval '365 days'
      else now()
    end;
    update public.profiles
    set plan = new.plan, plan_expires_at = expiry
    where id = new.user_id;
  end if;
  return new;
end;
$$;

create trigger on_payment_verified
  after update on public.payments
  for each row execute function public.handle_payment_success();

-- ─────────────────────────────────────────
-- BADGES
-- ─────────────────────────────────────────
create table public.user_badges (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  badge       badge_type not null,
  earned_at   timestamptz default now(),
  unique(user_id, badge)
);

-- ─────────────────────────────────────────
-- BLOG POSTS (for SEO)
-- ─────────────────────────────────────────
create table public.blog_posts (
  id            uuid primary key default gen_random_uuid(),
  slug          text unique not null,
  title         text not null,
  excerpt       text,
  content       text not null,             -- MDX content
  cover_url     text,
  tags          text[] default '{}',
  meta_title    text,
  meta_desc     text,
  published     boolean default false,
  published_at  timestamptz,
  author_id     uuid references public.profiles(id),
  view_count    int default 0,
  created_at    timestamptz default now()
);

-- ─────────────────────────────────────────
-- LEADERBOARD VIEW
-- ─────────────────────────────────────────
create or replace view public.leaderboard as
select
  p.id,
  p.full_name,
  p.avatar_url,
  p.xp_points,
  p.streak_days,
  p.problems_solved,
  rank() over (order by p.xp_points desc) as rank
from public.profiles p
where p.xp_points > 0
order by p.xp_points desc
limit 100;

-- ─────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ─────────────────────────────────────────
alter table public.profiles       enable row level security;
alter table public.submissions     enable row level security;
alter table public.typing_sessions enable row level security;
alter table public.user_projects   enable row level security;
alter table public.payments        enable row level security;
alter table public.user_badges     enable row level security;

-- Users can read/update their own profile
create policy "own profile" on public.profiles
  for all using (auth.uid() = id);

-- Leaderboard is public-readable
create policy "leaderboard public" on public.profiles
  for select using (true);

-- Submissions: own rows only
create policy "own submissions" on public.submissions
  for all using (auth.uid() = user_id);

-- Typing sessions: own rows only
create policy "own typing" on public.typing_sessions
  for all using (auth.uid() = user_id);

-- Projects progress: own rows only
create policy "own projects" on public.user_projects
  for all using (auth.uid() = user_id);

-- Payments: own rows only
create policy "own payments" on public.payments
  for all using (auth.uid() = user_id);

-- Problems + projects: readable by all authenticated, free ones by anyone
create policy "problems public" on public.problems
  for select using (is_free = true or auth.uid() is not null);

-- ─────────────────────────────────────────
-- SEED: SAMPLE PROBLEMS
-- ─────────────────────────────────────────
insert into public.problems (slug, title, description, difficulty, tier, topic, starter_code, solution_code, explanation, hints, test_cases, is_free, order_index) values
(
  'fibonacci-series',
  'Fibonacci series generator',
  'Write a function `fibonacci(n)` that returns a list of the first `n` Fibonacci numbers.',
  'easy', 'beginner', 'functions',
  'def fibonacci(n):\n    # Your code here\n    pass',
  'def fibonacci(n):\n    seq = [0, 1]\n    for i in range(2, n):\n        seq.append(seq[-1] + seq[-2])\n    return seq[:n]',
  '## Line-by-line\n- `seq = [0, 1]` — seed the sequence with the first two values\n- `for i in range(2, n)` — generate remaining numbers\n- `seq.append(seq[-1] + seq[-2])` — each number = sum of previous two\n- `return seq[:n]` — slice to exactly n items',
  '["Start with a list containing [0, 1]", "Each new number = sum of the last two", "Use a for loop from 2 to n"]',
  '[{"input": "5", "expected": "[0, 1, 1, 2, 3]"}, {"input": "1", "expected": "[0]"}]',
  true, 1
),
(
  'moving-average',
  'Moving average calculator',
  'Given a list of numbers and a window size `k`, return the moving averages using NumPy.',
  'easy', 'beginner', 'numpy',
  'import numpy as np\n\ndef moving_average(data, k):\n    # Your code here\n    pass',
  'import numpy as np\n\ndef moving_average(data, k):\n    return np.convolve(data, np.ones(k)/k, mode=''valid'')',
  '## Explanation\n- `np.ones(k)/k` — creates a uniform kernel (equal weights summing to 1)\n- `np.convolve` — slides the kernel across data and sums\n- `mode=''valid''` — only returns values where kernel fully overlaps',
  '["Think of it as a sliding window that averages k numbers at a time", "np.convolve is your friend here"]',
  '[{"input": "[10,20,30,40,50], 3", "expected": "[20. 30. 40.]"}]',
  true, 2
);
