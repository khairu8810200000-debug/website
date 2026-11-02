-- KHAIRUL CONSULTANCY: jadual bayaran bulanan
create table if not exists public.payment_customers (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 phone text not null,
 vehicle_model text not null,
 plate_number text,
 monthly_amount numeric(12,2) not null check (monthly_amount > 0),
 due_day int not null check (due_day between 1 and 31),
 next_due_date date not null,
 whatsapp_opt_in boolean not null default false,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.payment_records (
 id uuid primary key default gen_random_uuid(),
 customer_id uuid not null references public.payment_customers(id) on delete restrict,
 amount numeric(12,2) not null check (amount > 0),
 paid_at date not null default current_date,
 paid_for_month date not null,
 created_at timestamptz not null default now()
);
create table if not exists public.payment_reminder_logs (
 id bigint generated always as identity primary key,
 customer_id uuid not null references public.payment_customers(id) on delete cascade,
 due_date date not null,
 reminder_type text not null check (reminder_type in ('3_days','1_day','due_today','overdue')),
 sent_at timestamptz not null default now(),
 whatsapp_message_id text,
 unique(customer_id,due_date,reminder_type)
);
create or replace function public.advance_payment_due_date()
returns trigger language plpgsql security definer set search_path=public as $$
declare c public.payment_customers%rowtype; next_month date; last_day int;
begin
 select * into c from public.payment_customers where id=new.customer_id for update;
 next_month := (date_trunc('month',c.next_due_date)::date + interval '1 month')::date;
 last_day := extract(day from (next_month + interval '1 month - 1 day'))::int;
 update public.payment_customers
 set next_due_date = make_date(extract(year from next_month)::int,extract(month from next_month)::int,least(c.due_day,last_day))
 where id=new.customer_id;
 return new;
end; $$;
drop trigger if exists trg_advance_payment_due_date on public.payment_records;
create trigger trg_advance_payment_due_date after insert on public.payment_records
for each row execute function public.advance_payment_due_date();
alter table public.payment_customers enable row level security;
alter table public.payment_records enable row level security;
alter table public.payment_reminder_logs enable row level security;
drop policy if exists "admin read payment customers" on public.payment_customers;
create policy "admin read payment customers" on public.payment_customers for select to authenticated using (auth.jwt()->>'email'='khairu881020@gmail.com');
drop policy if exists "admin insert payment customers" on public.payment_customers;
create policy "admin insert payment customers" on public.payment_customers for insert to authenticated with check (auth.jwt()->>'email'='khairu881020@gmail.com');
drop policy if exists "admin update payment customers" on public.payment_customers;
create policy "admin update payment customers" on public.payment_customers for update to authenticated using (auth.jwt()->>'email'='khairu881020@gmail.com') with check (auth.jwt()->>'email'='khairu881020@gmail.com');
drop policy if exists "admin read payment records" on public.payment_records;
create policy "admin read payment records" on public.payment_records for select to authenticated using (auth.jwt()->>'email'='khairu881020@gmail.com');
drop policy if exists "admin insert payment records" on public.payment_records;
create policy "admin insert payment records" on public.payment_records for insert to authenticated with check (auth.jwt()->>'email'='khairu881020@gmail.com');
drop policy if exists "admin read reminder logs" on public.payment_reminder_logs;
create policy "admin read reminder logs" on public.payment_reminder_logs for select to authenticated using (auth.jwt()->>'email'='khairu881020@gmail.com');
-- Edge Function menggunakan service role untuk menulis log. Jangan dedahkan service role key dalam website.
