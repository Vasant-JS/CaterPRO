# CaterPro Render Deployment

Repository: https://github.com/Vasant-JS/CaterPRO

## Folder Layout

```text
CaterPRO/
  backend/     # Node API, deploy this as Render Web Service
  frontend/    # Flutter Android/iOS/web app
  render.yaml  # Render Blueprint for backend
```

## Local API

```powershell
cd D:\Projects\CaterPro\backend
npm install
npm start
```

Open:

```text
http://127.0.0.1:8787/api/docs
```

Demo login:

```text
admin@caterpro.in
password
```

## Render Backend Deployment

1. Push `backend/` and `render.yaml` to `https://github.com/Vasant-JS/CaterPRO`.
2. Open Render Dashboard.
3. Click **New +**.
4. Choose **Blueprint** if you want Render to use `render.yaml`, or choose **Web Service** for manual setup.
5. Connect GitHub repo `Vasant-JS/CaterPRO`.
6. For manual Web Service setup:
   - Runtime: `Node`
   - Root Directory: `backend`
   - Build Command: `npm install`
   - Start Command: `npm start`
   - Health Check Path: `/health`
   - Environment Variable: `NODE_VERSION=20`
   - Environment Variable: `DATABASE_URL=<your Render PostgreSQL internal connection string>`
7. Deploy.
8. After deploy, open:

```text
https://YOUR-RENDER-SERVICE.onrender.com/api/docs
```

## Flutter Frontend API URL

For local web:

```powershell
C:\flutter\bin\flutter.bat run -d chrome --web-hostname 127.0.0.1 --web-port 53217
```

For hosted API:

```powershell
C:\flutter\bin\flutter.bat run -d chrome --dart-define=CATERPRO_API_URL=https://YOUR-RENDER-SERVICE.onrender.com/api
```

For Android emulator, use your computer IP instead of `127.0.0.1`, or use a hosted Render URL.

## Data Ownership

- Universal data: menu items and raw materials.
- User-owned data: events, clients, employees, additional services, payments.

## PostgreSQL Sync

The backend keeps `backend/db.json` as a local fallback and syncs the full app state into PostgreSQL when `DATABASE_URL` is present.

Render setup:

1. Create a Render PostgreSQL database.
2. Copy the database **Internal Database URL**.
3. Add it to the `caterpro-api` web service as `DATABASE_URL`.
4. Redeploy the service.
5. Open `/api/storage/status` with a bearer token to confirm `postgres.connected: true`.

The PostgreSQL table is:

```sql
select id, updated_at, data from caterpro_state;
```

To visualize it, use Render's PostgreSQL console, pgAdmin, DBeaver, TablePlus, or any PostgreSQL client.

Authenticated sync endpoints:

```text
GET  /api/storage/status
POST /api/storage/push-local-to-postgres
POST /api/storage/pull-postgres-to-local
```

Universal catalog data is protected during sync so menu items, raw materials, and vegetables/fruits are merged instead of being deleted by an empty state.
