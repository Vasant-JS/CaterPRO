# CaterPro Render Deployment

Repository: https://github.com/Vasant-JS/CaterPRO

## Folder Layout

```text
CaterPRO/
  backend/           # Node API, deploy this as Render Web Service
  caterpro_flutter/  # Flutter frontend
  render.yaml        # Render Blueprint for backend
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

Swagger UI is served at `/api/docs`.
OpenAPI JSON is served at `/api/openapi.json`.

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
7. Deploy.
8. After deploy, open:

```text
https://YOUR-RENDER-SERVICE.onrender.com/api/docs
```

You can test APIs from Swagger UI using **Authorize** after calling login and copying the returned token.

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

The current local backend uses `backend/db.json`. Render free instances have ephemeral filesystem behavior, so production should move this to PostgreSQL before real use.

## Accessing The Current DB

Local DB file:

```text
backend/db.json
```

On Render, `db.json` is inside the deployed service filesystem and should be treated as temporary. For real access, create a Render PostgreSQL database and connect the API with `DATABASE_URL`.
