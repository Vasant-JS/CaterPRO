# CaterPro Backend

Local development API for the Flutter frontend.

Run:

```powershell
node D:\Projects\CaterPro\backend\server.js
```

Base URL:

```text
http://127.0.0.1:8787/api
```

Demo login:

```text
admin@caterpro.in / password
```

Data ownership:

- `universal.menuItems` and `universal.rawMaterials` are shared catalog data.
- `userData.{userId}` contains user-owned events, clients, employees, services, and payments.

## Storage

Local development always keeps `backend/db.json`.

When `DATABASE_URL` is configured, the backend also syncs the full app state into PostgreSQL using a single JSONB row:

```sql
select id, updated_at, data from caterpro_state;
```

Useful authenticated endpoints:

- `GET /api/storage/status`
- `POST /api/storage/push-local-to-postgres`
- `POST /api/storage/pull-postgres-to-local`

Universal catalog data is protected during sync so menu items, raw materials, and vegetables/fruits are merged instead of being wiped by an empty payload.
