# CaterPro Render + Supabase Deployment

Repository: https://github.com/Vasant-JS/CaterPRO

## Folder Layout

```text
CaterPRO/
  backend/     # Node API, deploy this as Render Web Service
  frontend/    # Flutter Android/iOS/web app
  render.yaml  # Render Blueprint for backend
```

## 1. Create Supabase

1. Open Supabase and create a project.
2. Go to **Project Settings > API**.
3. Copy the **Project URL**.
4. Copy the **service_role** key.
5. Open **SQL Editor** and run `backend/supabase-schema.sql` once.

The backend uses the Supabase JavaScript client with the service role key. Do not expose the service role key in the Flutter app.
Supabase is the backend's primary storage, not just an import/export destination.

## 2. Render Backend Deployment

Use the included `render.yaml` Blueprint, or create a manual Web Service:

- Runtime: `Node`
- Root Directory: `backend`
- Build Command: `npm install`
- Start Command: `npm start`
- Health Check Path: `/health`

Environment variables:

```text
NODE_VERSION=20
SUPABASE_URL=<your Supabase project URL>
SUPABASE_SERVICE_ROLE_KEY=<your Supabase service role key>
SUPABASE_STATE_ID=default
ALLOW_DB_JSON_STORAGE=false
```

After deploy, open:

```text
https://YOUR-RENDER-SERVICE.onrender.com/api/docs
```

The first successful backend start seeds Supabase from `backend/db.json` if no `caterpro_state/default` row exists. After that, the backend loads from Supabase and persists backend writes to Supabase.

## 3. Local API

For local-only development without Supabase:

```powershell
cd D:\Projects\CaterPro\backend
npm install
$env:ALLOW_DB_JSON_STORAGE='true'
npm start
```

For local development connected to Supabase:

```powershell
cd D:\Projects\CaterPro\backend
npm install
$env:SUPABASE_URL='https://your-project-ref.supabase.co'
$env:SUPABASE_SERVICE_ROLE_KEY='<service-role-key>'
$env:SUPABASE_STATE_ID='default'
$env:ALLOW_DB_JSON_STORAGE='false'
npm start
```

## 4. Flutter Frontend API URL

For local web:

```powershell
C:\flutter\bin\flutter.bat run -d chrome --web-hostname 127.0.0.1 --web-port 53217 --dart-define=CATERPRO_API_URL=http://127.0.0.1:8787/api
```

For hosted API:

```powershell
C:\flutter\bin\flutter.bat run -d chrome --dart-define=CATERPRO_API_URL=https://YOUR-RENDER-SERVICE.onrender.com/api
```

For Android emulator, use your computer IP instead of `127.0.0.1`, or use the hosted Render URL.

## 5. Verify Storage

Login with:

```text
admin@caterpro.in
password
```

Then call:

```text
GET /api/storage/status
GET /api/storage/tables
```

Expected status:

```json
{
  "storage": "supabase",
  "supabase": {
    "enabled": true,
    "connected": true,
    "stateId": "default"
  }
}
```

In Supabase Table Editor, you should see `caterpro_state` plus the `cp_*` live mirror tables.
