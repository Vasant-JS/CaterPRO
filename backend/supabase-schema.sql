create table if not exists caterpro_state (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists cp_users (
  state_id text not null,
  id text not null,
  name text,
  email text,
  role text,
  raw jsonb not null,
  primary key (state_id, id)
);

create table if not exists cp_business_profiles (
  state_id text not null,
  user_id text not null,
  business_name text,
  service_type text,
  gstin text,
  gst_type text,
  gst_rate numeric,
  phone text,
  email text,
  raw jsonb not null,
  primary key (state_id, user_id)
);

create table if not exists cp_clients (
  state_id text not null,
  user_id text not null,
  id text not null,
  name text,
  mobile text,
  city text,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists cp_employees (
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

create table if not exists cp_events (
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

create table if not exists cp_event_dates (
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

create table if not exists cp_menu_slots (
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

create table if not exists cp_event_payments (
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

create table if not exists cp_event_assignments (
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

create table if not exists cp_attendance (
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

create table if not exists cp_additional_services (
  state_id text not null,
  user_id text not null,
  id text not null,
  name text,
  unit text,
  price numeric,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists cp_custom_menus (
  state_id text not null,
  user_id text not null,
  id text not null,
  name text,
  type text,
  item_ids jsonb not null default '[]'::jsonb,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists cp_requirement_lists (
  state_id text not null,
  user_id text not null,
  id text not null,
  type text,
  title text,
  item_count integer,
  raw jsonb not null,
  primary key (state_id, user_id, id)
);

create table if not exists cp_manual_invoices (
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

create table if not exists cp_manual_invoice_items (
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

create table if not exists cp_menu_items (
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

create table if not exists cp_raw_materials (
  state_id text not null,
  id text not null,
  name text,
  category text,
  unit text,
  raw jsonb not null,
  primary key (state_id, id)
);

create table if not exists cp_produce_items (
  state_id text not null,
  id text not null,
  name text,
  category text,
  unit text,
  raw jsonb not null,
  primary key (state_id, id)
);

create table if not exists cp_vessel_items (
  state_id text not null,
  id text not null,
  name text,
  category text,
  unit text,
  raw jsonb not null,
  primary key (state_id, id)
);
