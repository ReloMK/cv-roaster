-- CV Roasted: authentication, saved roasts, and privacy-safe public wall.
-- Run this in the Supabase SQL editor (or as a migration).

create extension if not exists pgcrypto;

create table if not exists public.roasts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  cv_text text not null,
  job_title text,
  score integer not null check (score between 0 and 100),
  verdict text not null,
  tagline text,
  killing_chances text,
  missed_opportunities text,
  quick_wins text,
  what_works text,
  payment_status text not null default 'free' check (payment_status in ('free', 'paid')),
  full_rewrite text,
  cover_letter text,
  linkedin_headline text,
  ats_keywords text,
  latex_code text
);

-- Safe for an existing early version of the table.
alter table public.roasts add column if not exists tagline text;
alter table public.roasts add column if not exists killing_chances text;
alter table public.roasts add column if not exists missed_opportunities text;
alter table public.roasts add column if not exists quick_wins text;
alter table public.roasts add column if not exists what_works text;
alter table public.roasts add column if not exists payment_status text not null default 'free';
alter table public.roasts add column if not exists full_rewrite text;
alter table public.roasts add column if not exists cover_letter text;
alter table public.roasts add column if not exists linkedin_headline text;
alter table public.roasts add column if not exists ats_keywords text;
alter table public.roasts add column if not exists latex_code text;

create index if not exists roasts_user_created_at_idx on public.roasts (user_id, created_at desc);
create index if not exists roasts_wall_idx on public.roasts (score asc, created_at desc) where score < 50;

alter table public.roasts enable row level security;

drop policy if exists "Users can read only their own roasts" on public.roasts;
create policy "Users can read only their own roasts"
on public.roasts for select to authenticated
using (user_id = auth.uid());

drop policy if exists "Users can insert only their own roasts" on public.roasts;
create policy "Users can insert only their own roasts"
on public.roasts for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users can update only their own roasts" on public.roasts;
create policy "Users can update only their own roasts"
on public.roasts for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- The wall cannot SELECT the table directly: that would violate the RLS rule above.
-- This function deliberately returns only the four approved public fields.
create or replace function public.public_wall_of_shame(max_rows integer default 20)
returns table (score integer, verdict text, job_title text, created_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select r.score, r.verdict, r.job_title, r.created_at
  from public.roasts r
  where r.score < 50
  order by r.score asc, r.created_at desc
  limit least(greatest(coalesce(max_rows, 20), 1), 50);
$$;

revoke all on function public.public_wall_of_shame(integer) from public;
grant execute on function public.public_wall_of_shame(integer) to anon, authenticated;
