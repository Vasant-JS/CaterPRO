# CaterPro Backend

Node API for the Flutter frontend.

## Run Locally

```powershell
cd D:\Projects\CaterPro\backend
npm install
$env:ALLOW_DB_JSON_STORAGE='true'
npm start
```

Base URL:

```text
http://127.0.0.1:8787/api
```

Demo login:

```text
admin@caterpro.in / password
```

## Supabase Storage

CaterPro uses the Supabase JavaScript client only. It does not require Firebase config or a direct database connection string.
In production, Supabase is the backend's primary storage: the API loads the app state from Supabase on startup and every backend write is persisted back to Supabase.

Required production env vars:

```text
SUPABASE_URL=<your Supabase project URL>
SUPABASE_SERVICE_ROLE_KEY=<your Supabase service role key>
SUPABASE_STATE_ID=default
ALLOW_DB_JSON_STORAGE=false
```

Run [supabase-schema.sql](D:/Projects/CaterPro/backend/supabase-schema.sql) once in the Supabase SQL editor before deploying.

The backend stores the complete application state used by all API routes in:

```text
caterpro_state
```

It also mirrors the same live app data into export-friendly tables such as:

```text
cp_users
cp_clients
cp_events
cp_event_dates
cp_menu_slots
cp_event_payments
cp_attendance
cp_manual_invoices
cp_menu_items
cp_raw_materials
cp_produce_items
cp_vessel_items
```

Useful authenticated endpoints:

- `GET /api/storage/status`
- `GET /api/storage/tables`
- `POST /api/storage/push-local-to-supabase`
- `POST /api/storage/pull-supabase-to-local`
- `POST /api/storage/import-menu-items-from-supabase`
