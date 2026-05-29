const express = require('express');
const swaggerUi = require('swagger-ui-express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const PDFDocument = require('pdfkit');

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
  const token = (req.headers.authorization || req.query.token || '').replace(/^Bearer\s+/i, '');
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

function money(value) {
  return `₹${Number(value || 0).toLocaleString('en-IN')}`;
}

function eventTotals(event) {
  const menuTotal = event.dates.reduce((dateSum, date) => dateSum + date.menuSlots.reduce((slotSum, slot) => slotSum + Number(slot.pax || 0) * Number(slot.pricePerPax || 0), 0), 0);
  const serviceTotal = event.dates.reduce((dateSum, date) => dateSum + date.additionalServices.reduce((svcSum, service) => svcSum + Number(service.price || 0), 0), 0);
  const paid = event.payments.reduce((sum, payment) => sum + Number(payment.amount || 0), 0);
  const discount = event.payments.reduce((sum, payment) => sum + Number(payment.settledDiscount || 0), 0);
  const total = menuTotal + serviceTotal;
  return { menuTotal, serviceTotal, total, paid, discount, balance: Math.max(0, total - paid - discount) };
}

function menuTitleById(db, id) {
  const item = (db.universal?.menuItems || []).find((menuItem) => menuItem.id === id);
  return item ? item.english || item.title || id : id;
}

function menuDisplayById(db, id) {
  const item = (db.universal?.menuItems || []).find((menuItem) => menuItem.id === id);
  if (!item) return id;
  return item.kannada ? `${item.kannada} / ${item.english}` : item.english || item.title || id;
}

function firstExistingPath(paths) {
  return paths.find((candidate) => candidate && fs.existsSync(candidate));
}

function configurePdfFonts(doc) {
  const regular = firstExistingPath([
    path.join(__dirname, 'node_modules', '@fontsource', 'noto-sans-kannada', 'files', 'noto-sans-kannada-kannada-400-normal.woff'),
    'C:\\Windows\\Fonts\\Nirmala.ttf',
    'C:\\Windows\\Fonts\\arial.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  ]);
  const bold = firstExistingPath([
    path.join(__dirname, 'node_modules', '@fontsource', 'noto-sans-kannada', 'files', 'noto-sans-kannada-kannada-700-normal.woff'),
    'C:\\Windows\\Fonts\\NirmalaB.ttf',
    'C:\\Windows\\Fonts\\arialbd.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
  ]);
  if (regular) doc.registerFont('DocRegular', regular);
  if (bold) doc.registerFont('DocBold', bold);
  return { regular: regular ? 'DocRegular' : 'Helvetica', bold: bold ? 'DocBold' : 'Helvetica-Bold' };
}

function writeDocumentHeader(doc, title, event, number, fonts) {
  doc.rect(0, 0, doc.page.width, 96).fill('#06445d');
  doc.fillColor('white').fontSize(22).font(fonts.bold).text('CaterPro', 42, 28);
  doc.fontSize(10).font(fonts.regular).text('Catering event management', 42, 56);
  doc.fontSize(20).font(fonts.bold).text(title, 360, 28, { align: 'right', width: 190 });
  doc.fontSize(9).font(fonts.regular).text(number, 360, 56, { align: 'right', width: 190 });
  doc.fillColor('#202124').fontSize(12).font(fonts.bold).text(event.name || 'Untitled Event', 42, 126);
  doc.font(fonts.regular).fontSize(10).fillColor('#5f6368')
    .text(`Client: ${event.primaryClient || event.mobile || '-'}`, 42, 146)
    .text(`Mobile: ${event.mobile || '-'}`, 42, 162)
    .text(`Venue: ${event.venue || '-'}`, 42, 178)
    .text(`Date(s): ${event.dates.map((date) => date.date).join(', ') || '-'}`, 42, 194);
}

function tableHeader(doc, y, fonts) {
  doc.roundedRect(42, y, 511, 24, 4).fill('#e8eef2');
  doc.fillColor('#06445d').font(fonts.bold).fontSize(9)
    .text('Description', 52, y + 7, { width: 250 })
    .text('Qty', 312, y + 7, { width: 45, align: 'right' })
    .text('Rate', 370, y + 7, { width: 70, align: 'right' })
    .text('Amount', 456, y + 7, { width: 86, align: 'right' });
}

function ensurePageSpace(doc, y, needed = 44) {
  if (y + needed < 760) return y;
  doc.addPage();
  return 48;
}

function generateEventPdf({ res, db, event, type }) {
  const isInvoice = type === 'invoice';
  const title = isInvoice ? 'INVOICE' : 'QUOTATION';
  const prefix = isInvoice ? 'INV' : 'QUOTE';
  const number = `${prefix}_${event.id}_${new Date().toISOString().slice(0, 10).replaceAll('-', '')}`;
  const totals = eventTotals(event);
  const doc = new PDFDocument({ size: 'A4', margin: 42, info: { Title: `${title} - ${event.name}` } });
  const fonts = configurePdfFonts(doc);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="${number}.pdf"`);
  doc.pipe(res);
  writeDocumentHeader(doc, title, event, number, fonts);
  let y = 232;
  tableHeader(doc, y, fonts);
  y += 32;

  for (const date of event.dates) {
    y = ensurePageSpace(doc, y, 34);
    doc.fillColor('#06445d').font(fonts.bold).fontSize(11).text(`${date.date}${date.label ? ` - ${date.label}` : ''}`, 42, y);
    y += 18;
    for (const slot of date.menuSlots) {
      y = ensurePageSpace(doc, y, 62);
      const items = slot.menuItemIds.map((id) => menuTitleById(db, id)).join(', ') || 'Menu items not selected';
      const amount = Number(slot.pax || 0) * Number(slot.pricePerPax || 0);
      doc.fillColor('#202124').font(fonts.bold).fontSize(10).text(`${slot.type}${slot.time ? ` (${slot.time})` : ''}`, 52, y, { width: 250 });
      doc.fillColor('#5f6368').font(fonts.regular).fontSize(8).text(items, 52, y + 14, { width: 250, height: 28 });
      doc.fillColor('#202124').fontSize(9)
        .text(`${slot.pax || 0}`, 312, y, { width: 45, align: 'right' })
        .text(money(slot.pricePerPax), 370, y, { width: 70, align: 'right' })
        .text(money(amount), 456, y, { width: 86, align: 'right' });
      y += 48;
    }
    for (const service of date.additionalServices) {
      y = ensurePageSpace(doc, y, 30);
      doc.fillColor('#202124').font(fonts.regular).fontSize(9)
        .text(`Additional Service: ${service.name}`, 52, y, { width: 250 })
        .text(`${service.quantity || 0} ${service.unit || ''}`, 312, y, { width: 45, align: 'right' })
        .text('-', 370, y, { width: 70, align: 'right' })
        .text(money(service.price), 456, y, { width: 86, align: 'right' });
      y += 24;
    }
  }

  y = ensurePageSpace(doc, y, isInvoice ? 160 : 116);
  doc.moveTo(42, y).lineTo(553, y).strokeColor('#c5ccd3').stroke();
  y += 18;
  doc.fillColor('#202124').font(fonts.regular).fontSize(10)
    .text('Menu Total', 356, y, { width: 90 })
    .text(money(totals.menuTotal), 456, y, { width: 86, align: 'right' });
  y += 18;
  doc.text('Services Total', 356, y, { width: 90 }).text(money(totals.serviceTotal), 456, y, { width: 86, align: 'right' });
  y += 22;
  doc.font(fonts.bold).fontSize(12).fillColor('#06445d').text('Grand Total', 356, y, { width: 90 }).text(money(totals.total), 456, y, { width: 86, align: 'right' });
  y += 26;

  if (isInvoice) {
    doc.font(fonts.regular).fontSize(10).fillColor('#202124')
      .text('Paid', 356, y, { width: 90 })
      .text(money(totals.paid), 456, y, { width: 86, align: 'right' });
    y += 18;
    if (totals.discount > 0) {
      doc.text('Settlement Discount', 356, y, { width: 90 }).text(money(totals.discount), 456, y, { width: 86, align: 'right' });
      y += 18;
    }
    doc.font(fonts.bold).fillColor(totals.balance > 0 ? '#ba1a1a' : '#0b6b3a').text('Balance Due', 356, y, { width: 90 }).text(money(totals.balance), 456, y, { width: 86, align: 'right' });
    y += 30;
  }

  doc.fillColor('#5f6368').font(fonts.regular).fontSize(9)
    .text(isInvoice ? 'Thank you for your payment. This invoice is generated from CaterPro event records.' : 'This quotation is based on the selected menu, pax, and service configuration. Final billing may vary after confirmation.', 42, y, { width: 330 });
  doc.fillColor('#06445d').font(fonts.bold).fontSize(10).text('Authorized Signature', 410, y + 48, { align: 'center', width: 130 });
  doc.end();
}

function mealAccent(type) {
  const key = String(type || '').toLowerCase();
  if (key.includes('breakfast')) return '#f2a51a';
  if (key.includes('lunch')) return '#0b6b3a';
  if (key.includes('dinner')) return '#7b1b44';
  if (key.includes('juice')) return '#1c7c8a';
  if (key.includes('snack')) return '#b25a00';
  return '#06445d';
}

function menuDocumentTitle(event, date) {
  const client = event.primaryClient || event.name || 'Event';
  return `${client}${date ? ` - ${date.date}` : ''}`;
}

function drawMenuPage({ doc, db, event, date, fonts, pageLabel }) {
  doc.rect(0, 0, doc.page.width, doc.page.height).fill('#fbf7ef');
  doc.roundedRect(26, 24, 543, 88, 14).fill('#06445d');
  doc.fillColor('white').font(fonts.bold).fontSize(28).text('MENU', 44, 42, { width: 160 });
  doc.font(fonts.regular).fontSize(10).text('CaterPro event menu', 46, 76);
  doc.font(fonts.bold).fontSize(12).text(menuDocumentTitle(event, date), 250, 42, { width: 285, align: 'right' });
  doc.font(fonts.regular).fontSize(9).text(pageLabel, 250, 64, { width: 285, align: 'right' });
  doc.text(event.venue || '', 250, 82, { width: 285, align: 'right' });

  const label = date.label || date.date;
  doc.roundedRect(42, 132, 511, 48, 12).fill('#fff4db').strokeColor('#f2a51a').stroke();
  doc.fillColor('#06445d').font(fonts.bold).fontSize(17).text(label, 60, 144, { width: 270 });
  doc.fillColor('#5f6368').font(fonts.regular).fontSize(10).text(date.date, 60, 166);
  const pax = date.menuSlots.reduce((sum, slot) => sum + Number(slot.pax || 0), 0);
  doc.fillColor('#06445d').font(fonts.bold).fontSize(12).text(`${pax} total pax`, 400, 151, { width: 120, align: 'right' });

  let y = 205;
  if (date.menuSlots.length === 0) {
    doc.fillColor('#5f6368').font(fonts.regular).fontSize(12).text('No menu configured for this date.', 60, y);
    return;
  }
  for (const slot of date.menuSlots) {
    y = ensurePageSpace(doc, y, 112);
    const color = mealAccent(slot.type);
    const items = slot.menuItemIds.map((id) => menuDisplayById(db, id));
    const rowHeight = Math.max(96, 66 + Math.ceil(Math.max(items.length, 1) / 2) * 24);
    doc.roundedRect(42, y, 511, rowHeight, 14).fill('white').strokeColor('#eadfcf').stroke();
    doc.roundedRect(42, y, 10, rowHeight, 4).fill(color);
    doc.fillColor(color).font(fonts.bold).fontSize(18).text(slot.type || 'Menu', 66, y + 18, { width: 220 });
    doc.fillColor('#5f6368').font(fonts.regular).fontSize(10).text(`${slot.time || ''}${slot.time ? ' • ' : ''}${slot.pax || 0} pax`, 66, y + 42);
    doc.fillColor('#202124').font(fonts.regular).fontSize(10);
    const leftItems = items.filter((_, index) => index % 2 === 0);
    const rightItems = items.filter((_, index) => index % 2 === 1);
    leftItems.forEach((item, index) => doc.text(`• ${item}`, 66, y + 66 + index * 22, { width: 210 }));
    rightItems.forEach((item, index) => doc.text(`• ${item}`, 302, y + 66 + index * 22, { width: 210 }));
    y += rowHeight + 16;
  }

  if (date.additionalServices.length > 0) {
    y = ensurePageSpace(doc, y, 90);
    doc.fillColor('#06445d').font(fonts.bold).fontSize(14).text('Additional Services', 42, y);
    y += 22;
    doc.fillColor('#202124').font(fonts.regular).fontSize(10);
    date.additionalServices.forEach((service) => {
      doc.text(`• ${service.name} - ${service.quantity || 0} ${service.unit || ''}`, 60, y, { width: 430 });
      y += 18;
    });
  }

  doc.fillColor('#9a6a00').font(fonts.bold).fontSize(10).text('Prepared by CaterPro', 42, 786, { width: 511, align: 'center' });
}

function generateMenuPdf({ res, db, event, dateId, allDates = false }) {
  const dates = allDates ? event.dates : event.dates.filter((date) => date.id === dateId || date.date === dateId);
  if (!dates.length) {
    res.status(404).json({ message: 'Event date not found' });
    return;
  }
  const doc = new PDFDocument({ size: 'A4', margin: 42, info: { Title: `Menu - ${event.name}` }, autoFirstPage: false });
  const fonts = configurePdfFonts(doc);
  const suffix = allDates ? 'ALL_DAYS' : (dates[0].date || dates[0].id);
  const number = `MENU_${event.id}_${suffix}`.replace(/[^A-Za-z0-9_-]/g, '_');
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="${number}.pdf"`);
  doc.pipe(res);
  dates.forEach((date, index) => {
    doc.addPage();
    drawMenuPage({ doc, db, event, date, fonts, pageLabel: allDates ? `Day ${index + 1} of ${dates.length}` : 'Single day menu' });
  });
  doc.end();
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
    '/api/events/{eventId}/documents/{type}': { get: { tags: ['Events'], summary: 'Download event PDF document', parameters: [{ name: 'eventId', in: 'path', required: true, schema: { type: 'string' } }, { name: 'type', in: 'path', required: true, schema: { type: 'string', enum: ['quotation', 'invoice', 'menu', 'all-menus'] } }, { name: 'dateId', in: 'query', required: false, schema: { type: 'string' } }, { name: 'token', in: 'query', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'PDF file' }, 404: { description: 'Event not found' } } } },
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

app.get('/api/events/:eventId/documents/:type', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  if (req.params.type === 'menu') {
    return generateMenuPdf({ res, db, event, dateId: req.query.dateId || event.dates[0]?.id || event.dates[0]?.date });
  }
  if (req.params.type === 'all-menus') {
    return generateMenuPdf({ res, db, event, allDates: true });
  }
  if (!['quotation', 'invoice'].includes(req.params.type)) return res.status(400).json({ message: 'Document type must be quotation, invoice, menu, or all-menus' });
  return generateEventPdf({ res, db, event, type: req.params.type });
});

app.use((req, res) => res.status(404).json({ message: 'Not found' }));

app.listen(port, '0.0.0.0', () => {
  console.log(`CaterPro API running on port ${port}`);
});
