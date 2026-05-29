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

Swagger UI:

```text
http://127.0.0.1:8787/api/docs
```

OpenAPI JSON:

```text
http://127.0.0.1:8787/api/openapi.json
```

Demo login:

```text
admin@caterpro.in / password
```

Data ownership:

- `universal.menuItems` and `universal.rawMaterials` are shared catalog data.
- `userData.{userId}` contains user-owned events, clients, employees, services, and payments.

Current database:

- Local development uses `db.json`.
- On Render free web services, `db.json` is not suitable for production persistence.
- Move to Render PostgreSQL before storing real customer data.
