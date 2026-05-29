const express = require('express');
const swaggerUi = require('swagger-ui-express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
const dbPath = path.join(__dirname, 'db.json');
const port = Number(process.env.PORT || 8787);

app.use(express.json({ limit: '1mb' }));
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

function readDb() {
  return JSON.parse(fs.readFileSync(dbPath, 'utf8'));
}

function writeDb(db) {
  fs.writeFileSync(dbPath, `${JSON.stringify(db, null, 2)}\n`);
}

function makeId(prefix) {
  return `${prefix}_${crypto.randomUUID().slice(0, 8)}`;
}

function decodeToken(req) {
  const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!token) return null;
  try {
    return Buffer.from(token, 'base64url').toString('utf8').split(':')[0];
  } catch {
    return null;
  }
}

function requireUser(req, res, db) {
  const userId = decodeToken(req);
  const user = db.users.find((item) => item.id === userId);
  if (!user) {
    res.status(401).json({ message: 'Unauthorized' });
    return null;
  }
  db.userData[user.id] = db.userData[user.id] || emptyUserData();
  return user;
}

function emptyUserData() {
  return { events: [], clients: [], employees: [], additionalServices: [], payments: [] };
}

function ensureUniversal(db) {
  db.universal = db.universal || {};
  db.universal.menuItems = db.universal.menuItems || [];
  db.universal.rawMaterials = db.universal.rawMaterials || [];
}

function findUserEvent(db, userId, eventId) {
  const events = db.userData[userId].events;
  return events.find((event) => event.id === eventId);
}

function upsertById(list, item) {
  const index = list.findIndex((existing) => existing.id === item.id);
  if (index === -1) {
    list.push(item);
  } else {
    list[index] = { ...list[index], ...item };
  }
  return item;
}

function eventFromBody(body, existing = {}) {
  return {
    ...existing,
    id: existing.id || body.id || makeId('evt'),
    name: body.name || existing.name || '',
    primaryClient: body.primaryClient || existing.primaryClient || null,
    mobile: body.mobile || existing.mobile || '',
    venue: body.venue || existing.venue || '',
    notes: body.notes || existing.notes || '',
    status: body.status || existing.status || 'draft',
    dates: existing.dates || body.dates || [],
    payments: existing.payments || body.payments || [],
    createdAt: existing.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
}

function dateFromBody(body, existing = {}) {
  return {
    ...existing,
    id: existing.id || body.id || makeId('date'),
    date: body.date || existing.date || '',
    label: body.label || existing.label || '',
    menuSlots: existing.menuSlots || body.menuSlots || [],
    additionalServices: existing.additionalServices || body.additionalServices || [],
  };
}

function menuSlotFromBody(body, existing = {}) {
  return {
    ...existing,
    id: existing.id || body.id || makeId('slot'),
    type: body.type || existing.type || '',
    time: body.time || existing.time || '',
    pax: Number(body.pax ?? existing.pax ?? 0),
    pricePerPax: Number(body.pricePerPax ?? existing.pricePerPax ?? 0),
    enabled: Boolean(body.enabled ?? existing.enabled ?? true),
    menuItemIds: body.menuItemIds || existing.menuItemIds || [],
  };
}

function serviceFromBody(body, existing = {}) {
  return {
    ...existing,
    id: existing.id || body.id || makeId('svc'),
    serviceId: body.serviceId || existing.serviceId || '',
    name: body.name || existing.name || '',
    quantity: Number(body.quantity ?? existing.quantity ?? 0),
    unit: body.unit || existing.unit || '',
    price: Number(body.price ?? existing.price ?? 0),
  };
}

const openApiSpec = {
  openapi: '3.0.3',
  info: {
    title: 'CaterPro API',
    version: '0.2.0',
    description: 'CaterPro backend API. Menu items and raw materials are universal. Events and operational data are saved under the logged-in user.',
  },
  servers: [
    { url: 'http://127.0.0.1:8787', description: 'Local development' },
    { url: 'https://YOUR-RENDER-SERVICE.onrender.com', description: 'Render production' },
  ],
  tags: [
    { name: 'Auth' },
    { name: 'Universal Catalogs' },
    { name: 'Events' },
    { name: 'User Data' },
  ],
  components: {
    securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer' } },
    schemas: {
      LoginRequest: { type: 'object', required: ['email', 'password'], properties: { email: { type: 'string', example: 'admin@caterpro.in' }, password: { type: 'string', example: 'password' } } },
      MenuItem: { type: 'object', properties: { id: { type: 'string' }, english: { type: 'string' }, kannada: { type: 'string' }, title: { type: 'string' }, category: { type: 'string' }, meals: { type: 'array', items: { type: 'string' } }, veg: { type: 'boolean' } } },
      RawMaterial: { type: 'object', properties: { id: { type: 'string' }, name: { type: 'string' }, category: { type: 'string' }, unit: { type: 'string' } } },
      Event: { type: 'object', properties: { id: { type: 'string' }, name: { type: 'string' }, mobile: { type: 'string' }, venue: { type: 'string' }, dates: { type: 'array' } } },
    },
  },
  paths: {
    '/health': { get: { summary: 'Health check', responses: { 200: { description: 'OK' } } } },
    '/api/auth/login': { post: { tags: ['Auth'], summary: 'Login', requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/LoginRequest' } } } }, responses: { 200: { description: 'Token and user' }, 401: { description: 'Invalid credentials' } } } },
    '/api/bootstrap': { get: { tags: ['User Data'], security: [{ bearerAuth: [] }], summary: 'Load universal and user-owned data', responses: { 200: { description: 'Bootstrap data' }, 401: { description: 'Unauthorized' } } } },
    '/api/menu-items': { get: { tags: ['Universal Catalogs'], summary: 'List universal menu items', responses: { 200: { description: 'Menu items' } } }, post: { tags: ['Universal Catalogs'], summary: 'Create universal menu item', requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/MenuItem' } } } }, responses: { 201: { description: 'Created' } } } },
    '/api/menu-items/{id}': { put: { tags: ['Universal Catalogs'], summary: 'Update universal menu item', parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'Updated' }, 404: { description: 'Not found' } } } },
    '/api/raw-materials': { get: { tags: ['Universal Catalogs'], summary: 'List universal raw materials', responses: { 200: { description: 'Raw materials' } } }, post: { tags: ['Universal Catalogs'], summary: 'Create universal raw material', responses: { 201: { description: 'Created' } } } },
    '/api/raw-materials/{id}': { put: { tags: ['Universal Catalogs'], summary: 'Update universal raw material', parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'Updated' }, 404: { description: 'Not found' } } } },
    '/api/events': { get: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'List user events', responses: { 200: { description: 'Events' } } }, post: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Create full event shell', requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/Event' } } } }, responses: { 201: { description: 'Created' } } } },
    '/api/events/{eventId}': { get: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Get event' }, put: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Update event' } },
    '/api/events/{eventId}/dates': { post: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Add event date' } },
    '/api/events/{eventId}/dates/{dateId}/menu-slots': { post: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Add menu type/slot for date' } },
    '/api/events/{eventId}/dates/{dateId}/additional-services': { post: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Add additional service for date' } },
    '/api/events/{eventId}/payments': { post: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Record event payment' } },
  },
};

const apiDocs = {
  name: 'CaterPro API',
  version: '0.2.0',
  swagger: '/api/docs',
  openapi: '/api/openapi.json',
  demoUser: { email: 'admin@caterpro.in', password: 'password' },
  ownership: {
    universal: ['menuItems', 'rawMaterials'],
    userOwned: ['events', 'clients', 'employees', 'additionalServices', 'payments'],
  },
};

app.get('/health', (req, res) => res.json({ ok: true, service: 'caterpro-api' }));
app.get('/api', (req, res) => res.json(apiDocs));
app.get('/api/openapi.json', (req, res) => res.json(openApiSpec));
app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(openApiSpec));

app.post('/api/auth/login', (req, res) => {
  const db = readDb();
  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');
  const user = db.users.find((item) => item.email.toLowerCase() === email && item.password === password);
  if (!user) return res.status(401).json({ message: 'Invalid email or password' });
  db.userData[user.id] = db.userData[user.id] || emptyUserData();
  writeDb(db);
  const token = Buffer.from(`${user.id}:${crypto.randomUUID()}`).toString('base64url');
  return res.json({ token, user: { id: user.id, name: user.name, email: user.email } });
});

app.post('/api/auth/forgot-password', (req, res) => {
  res.json({ message: `Password reset requested for ${req.body.email || 'unknown email'}` });
});

app.post('/api/dev/reset-user-data', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  db.userData[user.id] = emptyUserData();
  writeDb(db);
  res.json({ message: 'User data reset', userId: user.id, userData: db.userData[user.id] });
});

app.get('/api/bootstrap', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  const user = requireUser(req, res, db);
  if (!user) return;
  res.json({ universal: db.universal, userData: db.userData[user.id] });
});

app.get('/api/menu-items', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  res.json(db.universal.menuItems);
});

app.post('/api/menu-items', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  const item = {
    id: req.body.id || makeId('mnu'),
    english: req.body.english || '',
    kannada: req.body.kannada || '',
    title: req.body.title || `${req.body.kannada || ''}/${req.body.english || ''}`,
    category: req.body.category || '',
    meals: Array.isArray(req.body.meals) ? req.body.meals : [],
    veg: Boolean(req.body.veg),
  };
  upsertById(db.universal.menuItems, item);
  writeDb(db);
  res.status(201).json(item);
});

app.put('/api/menu-items/:id', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  const existing = db.universal.menuItems.find((item) => item.id === req.params.id);
  if (!existing) return res.status(404).json({ message: 'Menu item not found' });
  const item = { ...existing, ...req.body, id: req.params.id };
  upsertById(db.universal.menuItems, item);
  writeDb(db);
  res.json(item);
});

app.get('/api/raw-materials', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  res.json(db.universal.rawMaterials);
});

app.post('/api/raw-materials', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  const item = { id: req.body.id || makeId('raw'), name: req.body.name || '', category: req.body.category || '', unit: req.body.unit || '' };
  upsertById(db.universal.rawMaterials, item);
  writeDb(db);
  res.status(201).json(item);
});

app.put('/api/raw-materials/:id', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  const existing = db.universal.rawMaterials.find((item) => item.id === req.params.id);
  if (!existing) return res.status(404).json({ message: 'Raw material not found' });
  const item = { ...existing, ...req.body, id: req.params.id };
  upsertById(db.universal.rawMaterials, item);
  writeDb(db);
  res.json(item);
});

app.get('/api/events', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  res.json(db.userData[user.id].events);
});

app.post('/api/events', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = eventFromBody(req.body);
  db.userData[user.id].events.push(event);
  writeDb(db);
  res.status(201).json(event);
});

app.get('/api/events/:eventId', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  res.json(event);
});

app.put('/api/events/:eventId', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  const updated = eventFromBody({ ...req.body, id: req.params.eventId }, event);
  Object.assign(event, updated);
  writeDb(db);
  res.json(event);
});

app.post('/api/events/:eventId/dates', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  const date = dateFromBody(req.body);
  event.dates.push(date);
  event.updatedAt = new Date().toISOString();
  writeDb(db);
  res.status(201).json(date);
});

app.put('/api/events/:eventId/dates/:dateId', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  const date = event.dates.find((item) => item.id === req.params.dateId);
  if (!date) return res.status(404).json({ message: 'Date not found' });
  Object.assign(date, dateFromBody({ ...req.body, id: req.params.dateId }, date));
  event.updatedAt = new Date().toISOString();
  writeDb(db);
  res.json(date);
});

app.post('/api/events/:eventId/dates/:dateId/menu-slots', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  const date = event?.dates.find((item) => item.id === req.params.dateId);
  if (!date) return res.status(404).json({ message: 'Event date not found' });
  const slot = menuSlotFromBody(req.body);
  date.menuSlots.push(slot);
  event.updatedAt = new Date().toISOString();
  writeDb(db);
  res.status(201).json(slot);
});

app.put('/api/events/:eventId/dates/:dateId/menu-slots/:slotId', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  const date = event?.dates.find((item) => item.id === req.params.dateId);
  const slot = date?.menuSlots.find((item) => item.id === req.params.slotId);
  if (!slot) return res.status(404).json({ message: 'Menu slot not found' });
  Object.assign(slot, menuSlotFromBody({ ...req.body, id: req.params.slotId }, slot));
  event.updatedAt = new Date().toISOString();
  writeDb(db);
  res.json(slot);
});

app.post('/api/events/:eventId/dates/:dateId/additional-services', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  const date = event?.dates.find((item) => item.id === req.params.dateId);
  if (!date) return res.status(404).json({ message: 'Event date not found' });
  const service = serviceFromBody(req.body);
  date.additionalServices.push(service);
  event.updatedAt = new Date().toISOString();
  writeDb(db);
  res.status(201).json(service);
});

app.post('/api/events/:eventId/payments', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  const payment = {
    id: req.body.id || makeId('pay'),
    amount: Number(req.body.amount || 0),
    date: req.body.date || new Date().toISOString().slice(0, 10),
    mode: req.body.mode || '',
    reference: req.body.reference || '',
    settled: Boolean(req.body.settled),
    settledDiscount: Number(req.body.settledDiscount || 0),
  };
  event.payments.push(payment);
  db.userData[user.id].payments.push({ ...payment, eventId: event.id });
  event.updatedAt = new Date().toISOString();
  writeDb(db);
  res.status(201).json(payment);
});

app.use((req, res) => res.status(404).json({ message: 'Not found' }));

app.listen(port, '0.0.0.0', () => {
  console.log(`CaterPro API running on port ${port}`);
});
