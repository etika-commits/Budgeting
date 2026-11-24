-- FINORA: run this script in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  preferred_currency text not null default 'IDR',
  theme text not null default 'pink',
  created_at timestamptz not null default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  category text not null,
  type text not null check (type in ('income','expense')),
  amount numeric(18,2) not null check (amount > 0),
  date date not null default current_date,
  account text,
  created_at timestamptz not null default now()
);
create index if not exists transactions_user_date_idx on public.transactions(user_id, date desc);

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  category text not null, amount numeric(18,2) not null check (amount >= 0), month date not null,
  created_at timestamptz not null default now(), unique(user_id, category, month)
);
create table if not exists public.savings_goals (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  name text not null, target_amount numeric(18,2) not null check (target_amount > 0), current_amount numeric(18,2) not null default 0,
  target_date date, created_at timestamptz not null default now()
);
create table if not exists public.debts (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  name text not null, total_amount numeric(18,2) not null check (total_amount >= 0), remaining_amount numeric(18,2) not null check (remaining_amount >= 0), due_date date,
  created_at timestamptz not null default now()
);
create table if not exists public.investments (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  name text not null, asset_type text not null, cost_basis numeric(18,2) not null default 0, current_value numeric(18,2) not null default 0,
  valuation_date date default current_date, created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.transactions enable row level security;
alter table public.budgets enable row level security;
alter table public.savings_goals enable row level security;
alter table public.debts enable row level security;
alter table public.investments enable row level security;

-- Every authenticated user can access only rows whose user_id equals their own auth UID.
create policy "profiles_select_own" on public.profiles for select to authenticated using (id = auth.uid());
create policy "profiles_insert_own" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles_update_own" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "transactions_own" on public.transactions for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "budgets_own" on public.budgets for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "goals_own" on public.savings_goals for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "debts_own" on public.debts for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "investments_own" on public.investments for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Create a profile row automatically when someone signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name) values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''));
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
