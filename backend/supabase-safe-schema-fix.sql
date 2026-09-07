-- Safe CaterPro Supabase schema repair generated from current code.
--
-- Purpose:
--   Make Supabase reporting/mirror tables match backend/server.js and
--   backend/supabase-schema.sql so the next app sync can push mobile data.
--
-- Safety:
--   Additive only. No DELETE, TRUNCATE, DROP, UPDATE, or data overwrite.
--   Existing app data in caterpro_state and mobile SQLite is untouched.

create table if not exists public.caterpro_state (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.cp_users (
  state_id text not null,
  id text not null,
  name text,
  email text,
  role text,
  raw jsonb not null,
  primary key (state_id, id)
);

create table if not exists public.cp_business_profiles (
  state_id text not null,
  user_id text not null,
  business_name text,
  service_type text,
  gstin text,
  gst_type text,
  gst_rate numeric,
  account_holder_name text,
  bank_name text,
  branch_name text,
  account_number text,
  ifsc text,
  phone text,
  email text,
  raw jsonb not null,
  primary key (state_id, user_id)
);

create table if not exists public.cp_clients (
  state_id text not null,
  user_id text not null,
  id text not null,
  name text,
  mobile text,
  city text,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists public.cp_employees (
  state_id text not null,
  user_id text not null,
  id text not null,
  name text,
  mobile text,
  designation text,
  pay_per_day numeric,
  pay_per_hour numeric,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists public.cp_events (
  state_id text not null,
  user_id text not null,
  id text not null,
  name text,
  primary_client text,
  mobile text,
  venue text,
  status text,
  notes text,
  add_ons jsonb not null default '[]'::jsonb,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists public.cp_event_dates (
  state_id text not null,
  user_id text not null,
  event_id text not null,
  id text not null,
  event_date text,
  label text,
  additional_services jsonb not null default '[]'::jsonb,
  raw jsonb not null,
  primary key (state_id, user_id, event_id, id)
);

create table if not exists public.cp_menu_slots (
  state_id text not null,
  user_id text not null,
  event_id text not null,
  date_id text not null,
  id text not null,
  type text,
  delivery_time text,
  pax integer,
  price_per_pax integer,
  enabled boolean,
  menu_item_ids jsonb not null default '[]'::jsonb,
  additional_services jsonb not null default '[]'::jsonb,
  raw jsonb not null,
  primary key (state_id, user_id, event_id, date_id, id)
);

create table if not exists public.cp_event_payments (
  state_id text not null,
  user_id text not null,
  event_id text not null,
  id text not null,
  amount integer,
  payment_date text,
  mode text,
  reference text,
  settled boolean,
  raw jsonb not null,
  primary key (state_id, user_id, event_id, id)
);

create table if not exists public.cp_event_assignments (
  state_id text not null,
  user_id text not null,
  event_id text not null,
  employee_id text not null,
  name text,
  designation text,
  pay_per_day numeric,
  pay_per_hour numeric,
  raw jsonb not null,
  primary key (state_id, user_id, event_id, employee_id)
);

create table if not exists public.cp_attendance (
  state_id text not null,
  user_id text not null,
  event_id text not null,
  employee_id text not null,
  attendance_date text not null,
  status text,
  hours numeric,
  pay_per_day numeric,
  pay_per_hour numeric,
  raw jsonb not null,
  primary key (state_id, user_id, event_id, employee_id, attendance_date)
);

create table if not exists public.cp_additional_services (
  state_id text not null,
  user_id text not null,
  id text not null,
  name text,
  unit text,
  price numeric,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists public.cp_custom_menus (
  state_id text not null,
  user_id text not null,
  id text not null,
  name text,
  type text,
  item_ids jsonb not null default '[]'::jsonb,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists public.cp_requirement_lists (
  state_id text not null,
  user_id text not null,
  id text not null,
  type text,
  title text,
  item_count integer,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists public.cp_manual_invoices (
  state_id text not null,
  user_id text not null,
  id text not null,
  invoice_number text,
  client_name text,
  mobile text,
  event_name text,
  event_date text,
  invoice_date text,
  total integer,
  pending integer,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists public.cp_manual_invoice_items (
  state_id text not null,
  user_id text not null,
  invoice_id text not null,
  id text not null,
  title text,
  quantity integer,
  rate integer,
  amount integer,
  raw jsonb not null,
  primary key (state_id, user_id, invoice_id, id)
);

create table if not exists public.cp_menu_items (
  state_id text not null,
  id text not null,
  english text,
  kannada text,
  title text,
  category text,
  meals jsonb not null default '[]'::jsonb,
  veg boolean,
  raw jsonb not null,
  primary key (state_id, id)
);

create table if not exists public.cp_user_menu_items (
  state_id text not null,
  user_id text not null,
  id text not null,
  english text,
  kannada text,
  title text,
  category text,
  meals jsonb not null default '[]'::jsonb,
  veg boolean,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists public.cp_raw_materials (
  state_id text not null,
  id text not null,
  name text,
  category text,
  unit text,
  raw jsonb not null,
  primary key (state_id, id)
);

create table if not exists public.cp_user_raw_materials (
  state_id text not null,
  user_id text not null,
  id text not null,
  name text,
  category text,
  unit text,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists public.cp_produce_items (
  state_id text not null,
  id text not null,
  name text,
  category text,
  unit text,
  raw jsonb not null,
  primary key (state_id, id)
);

create table if not exists public.cp_user_produce_items (
  state_id text not null,
  user_id text not null,
  id text not null,
  name text,
  category text,
  unit text,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists public.cp_vessel_items (
  state_id text not null,
  id text not null,
  name text,
  category text,
  unit text,
  raw jsonb not null,
  primary key (state_id, id)
);

create table if not exists public.cp_user_vessel_items (
  state_id text not null,
  user_id text not null,
  id text not null,
  name text,
  category text,
  unit text,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

alter table public.cp_business_profiles
  add column if not exists business_name text,
  add column if not exists service_type text,
  add column if not exists gstin text,
  add column if not exists gst_type text,
  add column if not exists gst_rate numeric,
  add column if not exists account_holder_name text,
  add column if not exists bank_name text,
  add column if not exists branch_name text,
  add column if not exists account_number text,
  add column if not exists ifsc text,
  add column if not exists phone text,
  add column if not exists email text,
  add column if not exists raw jsonb;

alter table public.cp_events
  add column if not exists add_ons jsonb default '[]'::jsonb,
  add column if not exists raw jsonb;

alter table public.cp_event_dates
  add column if not exists additional_services jsonb default '[]'::jsonb,
  add column if not exists raw jsonb;

alter table public.cp_menu_slots
  add column if not exists menu_item_ids jsonb default '[]'::jsonb,
  add column if not exists additional_services jsonb default '[]'::jsonb,
  add column if not exists raw jsonb;

alter table public.cp_custom_menus
  add column if not exists item_ids jsonb default '[]'::jsonb,
  add column if not exists raw jsonb;

alter table public.cp_menu_items
  add column if not exists meals jsonb default '[]'::jsonb,
  add column if not exists veg boolean,
  add column if not exists raw jsonb;

alter table public.cp_user_menu_items
  add column if not exists english text,
  add column if not exists kannada text,
  add column if not exists title text,
  add column if not exists category text,
  add column if not exists meals jsonb default '[]'::jsonb,
  add column if not exists veg boolean,
  add column if not exists raw jsonb;

alter table public.cp_user_raw_materials
  add column if not exists name text,
  add column if not exists category text,
  add column if not exists unit text,
  add column if not exists raw jsonb;

alter table public.cp_user_produce_items
  add column if not exists name text,
  add column if not exists category text,
  add column if not exists unit text,
  add column if not exists raw jsonb;

alter table public.cp_user_vessel_items
  add column if not exists name text,
  add column if not exists category text,
  add column if not exists unit text,
  add column if not exists raw jsonb;

grant select, insert, update, delete on table
  public.caterpro_state,
  public.cp_users,
  public.cp_business_profiles,
  public.cp_clients,
  public.cp_employees,
  public.cp_events,
  public.cp_event_dates,
  public.cp_menu_slots,
  public.cp_event_payments,
  public.cp_event_assignments,
  public.cp_attendance,
  public.cp_additional_services,
  public.cp_custom_menus,
  public.cp_requirement_lists,
  public.cp_manual_invoices,
  public.cp_manual_invoice_items,
  public.cp_menu_items,
  public.cp_user_menu_items,
  public.cp_raw_materials,
  public.cp_user_raw_materials,
  public.cp_produce_items,
  public.cp_user_produce_items,
  public.cp_vessel_items,
  public.cp_user_vessel_items
to service_role;

notify pgrst, 'reload schema';
