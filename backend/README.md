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

Event creation flow:

1. `POST /api/auth/login`
2. `POST /api/events`
3. `POST /api/events/{eventId}/dates`
4. `POST /api/events/{eventId}/dates/{dateId}/menu-slots`
5. `POST /api/events/{eventId}/dates/{dateId}/additional-services`
6. `POST /api/events/{eventId}/payments`

Universal catalog APIs:

- `GET/POST /api/menu-items`
- `PUT /api/menu-items/{id}`
- `GET/POST /api/raw-materials`
- `PUT /api/raw-materials/{id}`

Development reset:

- `POST /api/dev/reset-user-data`
- Requires bearer token.
- Clears events, clients, employees, additional services, and payments for the logged-in user.

Current database:

- Local development uses `db.json`.
- On Render free web services, `db.json` is not suitable for production persistence.
- Move to Render PostgreSQL before storing real customer data.
