const express = require('express');
const swaggerUi = require('swagger-ui-express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const PDFDocument = require('pdfkit');

const app = express();
const dbPath = path.join(__dirname, 'db.json');
const port = Number(process.env.PORT || 8787);

app.use(express.json({ limit: '10mb' }));
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
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
  db.userData[user.id] = ensureUserDataShape(db.userData[user.id] || emptyUserData());
  return user;
}

function emptyUserData() {
  return { events: [], clients: [], employees: [], additionalServices: [], customMenus: [], payments: [], manualInvoices: [], businessProfile: emptyBusinessProfile() };
}

function emptyBusinessProfile() {
  return { businessName: '', serviceType: '', gstin: '', pan: '', address: '', phone: '', email: '', bankName: '', accountNumber: '', terms: '', logoBase64: '', signatureBase64: '', qrBase64: '', documentTemplate: 'modern' };
}

function ensureUserDataShape(userData) {
  userData.events = userData.events || [];
  userData.clients = userData.clients || [];
  userData.employees = userData.employees || [];
  userData.additionalServices = userData.additionalServices || [];
  userData.customMenus = userData.customMenus || [];
  userData.payments = userData.payments || [];
  userData.manualInvoices = userData.manualInvoices || [];
  userData.businessProfile = { ...emptyBusinessProfile(), ...(userData.businessProfile || {}) };
  return userData;
}

const defaultRawMaterialNames = [
  'ಅರಿಶಿಣ ಪುಡಿ',
  'ಕುಂಕುಮ',
  'ಬಾಸುಮತಿ ಅಕ್ಕಿ',
  'ವಾಸನೆ ಅಕ್ಕಿ',
  'ಗರಂ ಮಸಾಲ',
  'ತೊಗರಿಬೇಳೆ',
  'ಕಡಲೆ ಬೇಳೆ',
  'ಉದ್ದಿನ ಬೇಳೆ',
  'ಹೆಸರು ಬೇಳೆ',
  'ಹೆಸರು ಕಾಳು',
  'ಕಡಲೆ ಕಾಳು',
  'ಕಾಬುಲ್ ಕಡಲೆ ಕಾಳು',
  'ಬಟಾಣಿ',
  'ಹುರಿಗಡಲೆ',
  'ಶೇಂಗಾ ಬೀಜ',
  'ಕೊತ್ತಂಬರಿ ಬೀಜ',
  'ಬ್ಯಾಡಗಿ ಮೆಣಸಿನಕಾಯಿ',
  'ಗಿಡ್ಡ ಮೆಣಸಿನಕಾಯಿ',
  'ಜೀರಿಗೆ',
  'ಮೆಂತ್ಯ ಕಾಳು',
  'ಸಾಸಿವೆ',
  'SSP ಇಂಗು',
  'ಲವಂಗ',
  'ಯಾಲಕ್ಕಿ',
  'ಚಕ್ಕೆಮೊಗ್ಗು',
  'ಜಾಯಿಕಾಯಿ',
  'ಜಾವತ್ರಿ',
  'ಗಸಗಸೆ',
  'ಪಲಾವ್ ಎಲೆ',
  'ಸೋಂಪು ಕಾಳು',
  'ಬೇಬಿ ಗೋಡಂಬಿ',
  'ಮಗಜ್ ಬೀಜ',
  'ಕಲ್ಲಂಗಡಿ ಬೀಜ',
  'ಬಾದಾಮಿ',
  'ಗೋಡಂಬಿ',
  'ದ್ರಾಕ್ಷಿ',
  'ಖರ್ಜೂರ ಸೀಡ್ಲೆಸ್',
  'ಉತ್ತತ್ತಿ',
  'ಚೆರ್ರಿ ಫ್ರೂಟ್',
  'ಚಾರು ಪಪ್ಪು',
  'ಪಿಸ್ತಾ',
  'MTR ಬಾದಾಮ್ ಪೌಡರ್',
  'ಮಿಲ್ಕ್ ಮೇಡ್',
  'ಬೆಲ್ಲ',
  'ಸಕ್ಕರೆ',
  'ಡೈಮಂಡ್ ಸಕ್ಕರೆ',
  'ಹುಣಸೆಹಣ್ಣು',
  'ಪುಡಿ ಉಪ್ಪು',
  'ಕಲ್ಲು ಉಪ್ಪು',
  'ಜಲ್-ಜಿರ',
  'ಓಮಿನ ಕಾಳು',
  'ಧನಿಯಾ ಪುಡಿ',
  'ಅಡುಗೆ ಸೋಡಾ',
  'ಅಚ್ಚು ಖಾರದಪುಡಿ',
  'ಉದ್ದಿನ ಹಪ್ಪಳ',
  'ಚಿಪ್ಸ್',
  'ಹಪ್ಪಳ',
  'ಸಂಡಿಗೆ',
  'ಕಾರ್ನ್ ಫ್ಲೇಕ್ಸ್',
  'ಕಾರ್ನ್ ಫ್ಲೋರ್',
  'ಕೊಬ್ಬರಿ',
  'ಕೊಬ್ಬರಿ ಪೌಡರ್',
  'ಕೇಸರಿ',
  'ಪಚ್ಚಕರ್ಪೂರ',
  'ಎಲ್ಲೋ ಕಲರ್',
  'ರೆಡ್ ಕಲರ್',
  'ರೋಸ್ ವಾಟರ್',
  'ಸ್ವೀಟ್',
  'ಜಾಮೂನ್ ಮಿಕ್ಸ್(ಸಾತ್ವಿಕ್)',
  'ನಂದಿನಿ ತುಪ್ಪ',
  'ರಿಫೈನ್ಡ್ ಆಯಿಲ್',
  'ಶೇಂಗಾ ಎಣ್ಣೆ',
  'ಕೊಬ್ಬರಿ ಎಣ್ಣೆ',
  'ಡಾಲ್ಡಾ',
  'ಲಿಲ್ಲಿ ಮಾಸ್ಟರ್ ಲೈನ್ಸ್',
  'ನಂದಿನಿ ಬೆಣ್ಣೆ',
  'ಕಾಶಿ ಪುಡಿ',
  'ಟೀ ಪುಡಿ',
  'ಬೂಸ್ಟ್',
  'ಬೋರ್ನ್-ವಿಟ',
  'ಹಾರ್ಲಿಕ್ಸ್',
  'ಹಾಲಿನ ಪುಡಿ',
  'ಗೋಧಿ ಕಡಿ',
  'ಪಾಯಸದ ಶಾವಿಗೆ',
  'ಡ್ರ್ಯಾಗನ್ ಶಾವಿಗೆ',
  'ಅನಿಲ್ ಶಾವಿಗೆ',
  'ಸೀಮೆಅಕ್ಕಿ',
  'ನೈಲಾನ್ ಸೀಮೆಅಕ್ಕಿ',
  'ಬಿಳಿ ಎಳ್ಳು',
  'ಕರಿ ಎಳ್ಳು',
  'ಚಿರೋಟಿ ರವೆ',
  'ಬೆಂಗಳೂರು ರವೆ',
  'ಬನ್ಸಿ ರವೆ',
  'ಇಡ್ಲಿ ರವೆ',
  'ಅಕ್ಕಿತರಿ',
  'ಗೋಧಿ ಹಿಟ್ಟು',
  'ಅಕ್ಕಿ ಹಿಟ್ಟು',
  'ಮೈದಾ ಹಿಟ್ಟು',
  'ಕಡಲೆ ಹಿಟ್ಟು',
  'ಬೆಂಕಿ-ಪೆಟ್ಟಿಗೆ',
  'ಸಬಿನ',
  'ಸೋಪಿನ ಪುಡಿ',
  'ದಪ್ಪ ಅವಲಕ್ಕಿ',
  'ಮಿಡಿಯಂ ಅವಲಕ್ಕಿ',
  'ಪೇಪರ್ ಅವಲಕ್ಕಿ',
  'ಕುರಿ ಸಾಣಿ',
  'ಸೋಯಾ ಸಾಸ್',
  'ಟೊಮೆಟೊ ಕೆಚಪ್',
  'ಟೊಮೆಟೊ ಸಾಸ್',
  'ಚಿಲ್ಲಿ ಸಾಸ್',
  'ವಿನಿಗರ್',
  'ಕಸ್ಟರ್ಡ್ ಪೌಡರ್',
  'ಟೇಸ್ಟಿಂಗ್ ಪೌಡರ್',
  'ಬೇಕಿಂಗ್ ಪೌಡರ್',
  'ಕೋಕೋ ಪೌಡರ್',
  'ಚಾಟ್ ಮಸಾಲ',
  'ಚನ-ಮಸಾಲ',
  'ಬಿರಿಯಾನಿ ಮಸಾಲೆ',
  'ವೆಜ್ ಕಬಾಬ್ ಮಸಾಲೆ',
  'ಪನೀರ',
  'ಬೇಬಿ ಕಾರ್ನ್',
  'ಸ್ವೀಟ್ ಕಾರ್ನ್',
  'ಪುನಪುಳಿ ಜ್ಯೂಸ್',
  'ಪೇಪರ್ ರೋಲ್',
  'ನೀರಿನ ಲೋಟ',
  'ಲೋಟ',
  'ಜ್ಯೂಸ್ ಲೋಟ',
  'ಕಾಫಿ ಲೋಟ',
  'ಪ್ಲಾಸ್ಟಿಕ್ ರೋಲ್',
  'ಪೇಣಿ ಚಿರೋಟಿ ಪ್ಲೇಟ್',
  'ಸೂಪ್ ಬೌಲ್',
  'ಸೂಪ್ ಸ್ಪೂನ್',
  'ಫ್ರೂಟ್ ಬೌಲ್',
  'ಫ್ರೂಟ್ ಸ್ಟಿಕ್',
  'ಸ್ಪೂನ್',
  'ವೇಟ್ ಟಿಶ್ಯೂ',
  'ನ್ಯಾಪ್ಕಿನ್ಸ್ (ಟಿಶ್ಯೂ)',
  'ಹೆಡ್ ಕ್ಯಾಪ್ಸ್',
  'ಹ್ಯಾಂಡ್ ಗ್ಲೌಸ್',
  'ತಾಂಬೂಲ ಕವರ್(ಬಟ್ಟೆಯದ್ದು)',
  'ತಾಂಬೂಲ ಕವರ್(ಹಣ್ಣಿನದ್ದು)',
  'ಇಡ್ಲಿ ಕವರ್',
  'ಹೋಳಿಗೆ ಹೆಡ್',
  'ಜಿಪ್ ಲಾಕ್ ಕವರ್ 4/5',
  'ಜಿಪ್ ಲಾಕ್ ಕವರ್ 5/6',
  'ಕಾಟನ್ ಸೋಳೆ ಪರದೆ',
  'ಕೋರಾ ಬಟ್ಟೆ',
  'ಪಾಣಿ ಪಂಚೆ',
  'ಅನ್ನದ ಬುಟ್ಟಿ',
  'ಚಿರೋಟಿ ಬುಟ್ಟಿ',
  'ಕಡ್ಡಿ ಪೊರಕೆ',
  'ಖಾಲಿ ಈರುಳ್ಳಿ ಚೀಲ',
  'ಗೋಣಿ ಚೀಲ',
  'ಉಪ್ಪಿನ ಕಾಯಿ',
];

function defaultRawMaterials() {
  return defaultRawMaterialNames.map((name, index) => ({
    id: `RAW-${String(index + 1).padStart(3, '0')}`,
    name,
    category: index >= 126 ? 'ಸಾಮಗ್ರಿ' : 'ಕಿರಾಣಿ',
    unit: 'ಪ್ರಮಾಣ',
  }));
}

const defaultProduceItems = [
  ['ಆಲೂಗಡ್ಡೆ', 'ತರಕಾರಿ'], ['ಈರುಳ್ಳಿ', 'ತರಕಾರಿ'], ['ಟೊಮೆಟೊ', 'ತರಕಾರಿ'], ['ಹಸಿಮೆಣಸಿನಕಾಯಿ', 'ತರಕಾರಿ'], ['ಕೊತ್ತಂಬರಿ ಸೊಪ್ಪು', 'ತರಕಾರಿ'],
  ['ಕರಿಬೇವು', 'ತರಕಾರಿ'], ['ಶುಂಠಿ', 'ತರಕಾರಿ'], ['ಬೆಳ್ಳುಳ್ಳಿ', 'ತರಕಾರಿ'], ['ಕ್ಯಾರೆಟ್', 'ತರಕಾರಿ'], ['ಬೀನ್ಸ್', 'ತರಕಾರಿ'],
  ['ಬಟಾಣಿ', 'ತರಕಾರಿ'], ['ಎಲೆಕೋಸು', 'ತರಕಾರಿ'], ['ಹೂಕೋಸು', 'ತರಕಾರಿ'], ['ಬದನೆಕಾಯಿ', 'ತರಕಾರಿ'], ['ಬೆಂಡೆಕಾಯಿ', 'ತರಕಾರಿ'],
  ['ಸೌತೆಕಾಯಿ', 'ತರಕಾರಿ'], ['ಮೂಲಂಗಿ', 'ತರಕಾರಿ'], ['ಬೀಟ್ರೂಟ್', 'ತರಕಾರಿ'], ['ಕ್ಯಾಪ್ಸಿಕಂ', 'ತರಕಾರಿ'], ['ನುಗ್ಗೆಕಾಯಿ', 'ತರಕಾರಿ'],
  ['ಸೀಮೆ ಬದನೆಕಾಯಿ', 'ತರಕಾರಿ'], ['ಹೀರೆಕಾಯಿ', 'ತರಕಾರಿ'], ['ಸೋರೆಕಾಯಿ', 'ತರಕಾರಿ'], ['ಪಡುವಲಕಾಯಿ', 'ತರಕಾರಿ'], ['ಹಾಗಲಕಾಯಿ', 'ತರಕಾರಿ'],
  ['ಕುಂಭಳಕಾಯಿ', 'ತರಕಾರಿ'], ['ಸಿಹಿ ಕುಂಬಳಕಾಯಿ', 'ತರಕಾರಿ'], ['ಅವರೆಕಾಯಿ', 'ತರಕಾರಿ'], ['ಹುರಳಿಕಾಯಿ', 'ತರಕಾರಿ'], ['ಮೆಂತ್ಯ ಸೊಪ್ಪು', 'ತರಕಾರಿ'],
  ['ಪಾಲಕ್ ಸೊಪ್ಪು', 'ತರಕಾರಿ'], ['ಸಬ್ಬಸಿಗೆ ಸೊಪ್ಪು', 'ತರಕಾರಿ'], ['ಪುದೀನಾ', 'ತರಕಾರಿ'], ['ನಿಂಬೆಹಣ್ಣು', 'ತರಕಾರಿ'], ['ತೆಂಗಿನಕಾಯಿ', 'ತರಕಾರಿ'],
  ['ಬಾಳೆ ಎಲೆ', 'ತರಕಾರಿ'], ['ಬಾಳೆಹಣ್ಣು', 'ಹಣ್ಣು'], ['ಸೇಬು', 'ಹಣ್ಣು'], ['ಕಿತ್ತಳೆ', 'ಹಣ್ಣು'], ['ಮೂಸಂಬಿ', 'ಹಣ್ಣು'],
  ['ದ್ರಾಕ್ಷಿ', 'ಹಣ್ಣು'], ['ದಾಳಿಂಬೆ', 'ಹಣ್ಣು'], ['ಕಲ್ಲಂಗಡಿ', 'ಹಣ್ಣು'], ['ಕರಬೂಜ', 'ಹಣ್ಣು'], ['ಅನಾನಸ್', 'ಹಣ್ಣು'],
  ['ಮಾವು', 'ಹಣ್ಣು'], ['ಪೇರಲೆ', 'ಹಣ್ಣು'], ['ಪಪ್ಪಾಯಿ', 'ಹಣ್ಣು'], ['ಚಿಕ್ಕು', 'ಹಣ್ಣು'], ['ಸ್ಟ್ರಾಬೆರಿ', 'ಹಣ್ಣು'],
  ['ಖರ್ಜೂರ', 'ಹಣ್ಣು'], ['ಅಂಜೂರ', 'ಹಣ್ಣು'], ['ಸೀತಾಫಲ', 'ಹಣ್ಣು'], ['ಕಿವಿ', 'ಹಣ್ಣು'], ['ನೇರಳೆಹಣ್ಣು', 'ಹಣ್ಣು'],
  ['ಹಲಸಿನಹಣ್ಣು', 'ಹಣ್ಣು'],
];

function defaultProduceCatalog() {
  return defaultProduceItems.map(([name, category], index) => ({
    id: `PRD-${String(index + 1).padStart(3, '0')}`,
    name,
    category,
    unit: 'ಕೆಜಿ',
  }));
}

function ensureUniversal(db) {
  db.universal = db.universal || {};
  db.universal.menuItems = db.universal.menuItems || [];
  db.universal.rawMaterials = db.universal.rawMaterials || [];
  db.universal.produceItems = db.universal.produceItems || [];
  const legacyNames = new Set(['Basmati Rice', 'Toor Dal', 'Cooking Oil', 'Tomato', 'Onion']);
  const hasOnlyLegacyRawMaterials = db.universal.rawMaterials.length > 0 && db.universal.rawMaterials.every((item) => legacyNames.has(item.name));
  if (db.universal.rawMaterials.length === 0 || hasOnlyLegacyRawMaterials) {
    db.universal.rawMaterials = defaultRawMaterials();
  }
  if (db.universal.produceItems.length === 0) {
    db.universal.produceItems = defaultProduceCatalog();
  }
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
    name: body.name ?? existing.name ?? '',
    primaryClient: body.primaryClient ?? existing.primaryClient ?? null,
    mobile: body.mobile ?? existing.mobile ?? '',
    venue: body.venue ?? existing.venue ?? '',
    notes: body.notes ?? existing.notes ?? '',
    status: body.status ?? existing.status ?? 'draft',
    addOns: Array.isArray(body.addOns) ? body.addOns.map(addOnFromBody) : existing.addOns || [],
    dates: Array.isArray(body.dates) ? body.dates : existing.dates || [],
    payments: Array.isArray(body.payments) ? body.payments : existing.payments || [],
    materialDocuments: Array.isArray(body.materialDocuments) ? body.materialDocuments.map(materialDocumentFromBody) : existing.materialDocuments || [],
    createdAt: existing.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
}

function materialDocumentFromBody(body, existing = {}) {
  return {
    ...existing,
    id: existing.id || body.id || makeId('matdoc'),
    type: ['raw', 'produce'].includes(body.type) ? body.type : existing.type || 'raw',
    title: body.title || existing.title || 'Material List',
    createdAt: existing.createdAt || body.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    items: Array.isArray(body.items) ? body.items.map((item) => ({
      itemId: item.itemId || '',
      name: item.name || '',
      category: item.category || '',
      quantity: item.quantity == null ? '' : String(item.quantity),
      unit: item.unit || '',
    })).filter((item) => item.name || item.itemId) : existing.items || [],
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

function addOnFromBody(body, existing = {}) {
  return {
    ...existing,
    id: existing.id || body.id || makeId('addon'),
    title: body.title || existing.title || '',
    cost: Number(body.cost ?? existing.cost ?? 0),
  };
}

function normalizeMobile(value) {
  return String(value || '').replace(/^\+91\s*/, '').replace(/\D/g, '').slice(-10);
}

function manualInvoiceFromBody(body, existing = {}) {
  const items = Array.isArray(body.items) ? body.items.map((item) => ({
    id: item.id || makeId('minvitem'),
    title: item.title || item.description || '',
    quantity: Number(item.quantity || 0),
    rate: Number(item.rate || 0),
    amount: Number(item.amount ?? (Number(item.quantity || 0) * Number(item.rate || 0))),
  })).filter((item) => item.title || item.amount > 0) : existing.items || [];
  const subtotal = items.reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const advance = Number(body.advance ?? existing.advance ?? 0);
  const settlement = Number(body.settlement ?? existing.settlement ?? 0);
  const total = Number(body.total ?? subtotal);
  return {
    ...existing,
    id: existing.id || body.id || makeId('minv'),
    clientName: body.clientName || existing.clientName || '',
    mobile: normalizeMobile(body.mobile || existing.mobile || ''),
    clientAddress: body.clientAddress || existing.clientAddress || '',
    clientGst: body.clientGst || body.clientGST || existing.clientGst || '',
    eventName: body.eventName || existing.eventName || '',
    venue: body.venue || existing.venue || '',
    eventDate: body.eventDate || existing.eventDate || '',
    invoiceDate: body.invoiceDate || existing.invoiceDate || new Date().toISOString().slice(0, 10),
    invoiceNumber: body.invoiceNumber || existing.invoiceNumber || '',
    notes: body.notes || existing.notes || '',
    items,
    subtotal,
    total,
    advance,
    settlement,
    pending: Math.max(0, total - advance - settlement),
    createdAt: existing.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
}

function clientFromBody(body, existing = {}) {
  return {
    ...existing,
    id: existing.id || body.id || makeId('client'),
    name: body.name || existing.name || '',
    mobile: normalizeMobile(body.mobile || existing.mobile || ''),
    city: body.city || existing.city || '',
    notes: body.notes || existing.notes || '',
    address: body.address || existing.address || '',
    gst: body.gst || body.gstin || existing.gst || '',
    createdAt: existing.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
}

function money(value) {
  return `\u20B9${Number(value || 0).toLocaleString('en-IN')}`;
}

function serviceQuantityText(service) {
  const quantity = Number(service.quantity || 0);
  return quantity > 0 ? `${quantity} ${service.unit || ''}`.trim() : '';
}

function eventTotals(event) {
  const menuTotal = event.dates.reduce((dateSum, date) => dateSum + date.menuSlots.reduce((slotSum, slot) => slotSum + Number(slot.pax || 0) * Number(slot.pricePerPax || 0), 0), 0);
  const addOnTotal = (event.addOns || []).reduce((sum, addOn) => sum + Number(addOn.cost || 0), 0);
  const paid = event.payments.reduce((sum, payment) => sum + Number(payment.amount || 0), 0);
  const discount = event.payments.reduce((sum, payment) => sum + Number(payment.settledDiscount || 0), 0);
  const total = menuTotal + addOnTotal;
  return { menuTotal, addOnTotal, total, paid, discount, balance: Math.max(0, total - paid - discount) };
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

function menuPartsById(db, id) {
  const item = (db.universal?.menuItems || []).find((menuItem) => menuItem.id === id);
  if (!item) return { kannada: '', english: id };
  return { kannada: item.kannada || '', english: item.english || item.title || id };
}

function hasKannadaText(value) {
  return /[\u0C80-\u0CFF]/.test(String(value || ''));
}

function drawSingleLineText(doc, text, x, y, width, fonts, options = {}) {
  const fontSize = options.fontSize || 7;
  const color = options.color || '#202124';
  const source = String(text || '');
  const textOptions = { width, height: options.height || 12, ellipsis: true, lineBreak: false };
  if (!source) return;
  const parts = source.split(/\s*\/\s*/);
  if (parts.length > 1 && hasKannadaText(parts[0])) {
    const kannada = parts[0].trim();
    const english = parts.slice(1).join(' / ').trim();
    doc.fillColor(color).font(fonts.kannada).fontSize(fontSize).text(kannada, x, y, textOptions);
    const used = Math.min(width * 0.58, doc.widthOfString(kannada) + 4);
    if (english) doc.fillColor(color).font(fonts.regular).fontSize(fontSize - 0.2).text(`/ ${english}`, x + used, y + 0.5, { ...textOptions, width: Math.max(8, width - used) });
    return;
  }
  const font = hasKannadaText(source) ? fonts.kannada : fonts.regular;
  doc.fillColor(color).font(font).fontSize(fontSize).text(source, x, y, textOptions);
}

function prettyDate(value) {
  if (!value) return '-';
  const parsed = new Date(`${value}T00:00:00`);
  if (Number.isNaN(parsed.getTime())) return value;
  return parsed.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function documentNumber(prefix, event) {
  const stamp = new Date().toISOString().slice(0, 10).replaceAll('-', '');
  return `${prefix}-${event.id.replace(/^evt_?/, '').toUpperCase()}-${stamp}`;
}

function amountInWords(value) {
  const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
  const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
  function belowThousand(num) {
    let text = '';
    if (num >= 100) {
      text += `${ones[Math.floor(num / 100)]} Hundred`;
      num %= 100;
      if (num) text += ' ';
    }
    if (num >= 20) {
      text += tens[Math.floor(num / 10)];
      if (num % 10) text += ` ${ones[num % 10]}`;
    } else if (num > 0) {
      text += ones[num];
    }
    return text;
  }
  let num = Math.round(Number(value || 0));
  if (num === 0) return 'Rupees Zero Only';
  const parts = [];
  const crore = Math.floor(num / 10000000);
  if (crore) parts.push(`${belowThousand(crore)} Crore`);
  num %= 10000000;
  const lakh = Math.floor(num / 100000);
  if (lakh) parts.push(`${belowThousand(lakh)} Lakh`);
  num %= 100000;
  const thousand = Math.floor(num / 1000);
  if (thousand) parts.push(`${belowThousand(thousand)} Thousand`);
  num %= 1000;
  if (num) parts.push(belowThousand(num));
  return `Rupees ${parts.join(' ')} Only`;
}

function firstExistingPath(paths) {
  return paths.find((candidate) => candidate && fs.existsSync(candidate));
}

function configurePdfFonts(doc) {
  const nirmala = firstExistingPath(['C:\\Windows\\Fonts\\Nirmala.ttc']);
  if (nirmala) {
    doc.registerFont('NirmalaRegular', nirmala, 'NirmalaUI');
    doc.registerFont('NirmalaBold', nirmala, 'NirmalaUI-Bold');
    return {
      regular: 'NirmalaRegular',
      bold: 'NirmalaBold',
      kannada: 'NirmalaRegular',
      kannadaBold: 'NirmalaBold',
    };
  }
  const latinRegular = firstExistingPath([
    path.join(__dirname, 'node_modules', '@fontsource', 'noto-sans', 'files', 'noto-sans-latin-400-normal.woff'),
    'C:\\Windows\\Fonts\\segoeui.ttf',
    'C:\\Windows\\Fonts\\arial.ttf',
  ]);
  const latinBold = firstExistingPath([
    path.join(__dirname, 'node_modules', '@fontsource', 'noto-sans', 'files', 'noto-sans-latin-700-normal.woff'),
    'C:\\Windows\\Fonts\\segoeuib.ttf',
    'C:\\Windows\\Fonts\\arialbd.ttf',
  ]);
  const kannadaRegular = firstExistingPath([
    path.join(__dirname, 'node_modules', '@fontsource', 'noto-sans-kannada', 'files', 'noto-sans-kannada-kannada-400-normal.woff'),
  ]);
  const kannadaBold = firstExistingPath([
    path.join(__dirname, 'node_modules', '@fontsource', 'noto-sans-kannada', 'files', 'noto-sans-kannada-kannada-700-normal.woff'),
  ]);
  if (latinRegular) doc.registerFont('LatinRegular', latinRegular);
  if (latinBold) doc.registerFont('LatinBold', latinBold);
  if (kannadaRegular) doc.registerFont('KannadaRegular', kannadaRegular);
  if (kannadaBold) doc.registerFont('KannadaBold', kannadaBold);
  return {
    regular: latinRegular ? 'LatinRegular' : 'Helvetica',
    bold: latinBold ? 'LatinBold' : 'Helvetica-Bold',
    kannada: kannadaRegular ? 'KannadaRegular' : 'Helvetica',
    kannadaBold: kannadaBold ? 'KannadaBold' : 'Helvetica-Bold',
  };
}

function imageBufferFromDataUrl(value) {
  if (!value || typeof value !== 'string' || !value.includes(',')) return null;
  try {
    return Buffer.from(value.split(',').pop(), 'base64');
  } catch {
    return null;
  }
}

function drawProfileImage(doc, value, x, y, options) {
  const buffer = imageBufferFromDataUrl(value);
  if (!buffer) return false;
  try {
    doc.image(buffer, x, y, options);
    return true;
  } catch {
    return false;
  }
}

function documentTheme(businessProfile = emptyBusinessProfile()) {
  const template = businessProfile.documentTemplate || 'modern';
  const themes = {
    modern: { name: 'modern', primary: '#06445d', secondary: '#f2a51a', accent: '#1c7c8a', soft: '#fff4db', page: '#fbf8f1', ink: '#202124', muted: '#59656b' },
    premium: { name: 'premium', primary: '#1b4d3e', secondary: '#c9a84c', accent: '#7b1b44', soft: '#f8efd3', page: '#fbfaf6', ink: '#202124', muted: '#5f6368' },
    minimal: { name: 'minimal', primary: '#111827', secondary: '#6b7280', accent: '#0f766e', soft: '#eef2f7', page: '#ffffff', ink: '#111827', muted: '#4b5563' },
  };
  return themes[template] || themes.modern;
}

function writeDocumentHeader(doc, title, event, number, fonts, businessProfile = emptyBusinessProfile()) {
  const theme = documentTheme(businessProfile);
  const businessName = businessProfile.businessName || 'CaterPro';
  const contactLine = [businessProfile.phone, businessProfile.email].filter(Boolean).join(' | ');
  const taxLine = [businessProfile.gstin ? `GSTIN: ${businessProfile.gstin}` : '', businessProfile.pan ? `PAN: ${businessProfile.pan}` : ''].filter(Boolean).join(' | ');
  doc.rect(0, 0, doc.page.width, doc.page.height).fill('#ffffff');
  doc.roundedRect(36, 32, 523, 92, theme.name === 'minimal' ? 3 : 14).fill(theme.primary);
  doc.roundedRect(36, 32, 8, 92, 3).fill(theme.secondary);
  if (!drawProfileImage(doc, businessProfile.logoBase64, 58, 54, { fit: [48, 48] })) {
    doc.circle(86, 78, 28).lineWidth(2).strokeColor(theme.secondary).stroke();
    doc.fillColor('white').font(fonts.bold).fontSize(16).text(businessName.slice(0, 2).toUpperCase(), 62, 69, { width: 48, align: 'center' });
  }
  doc.fillColor('white').font(fonts.bold).fontSize(18).text(businessName, 126, 48, { width: 248 });
  doc.font(fonts.regular).fontSize(8).text(businessProfile.address || 'Catering event management', 126, 72, { width: 248, height: 22 });
  if (contactLine) doc.text(contactLine, 126, 98, { width: 248 });
  doc.font(fonts.bold).fontSize(22).text(title, 390, 48, { width: 140, align: 'right' });
  doc.fillColor('#f6f2df').font(fonts.regular).fontSize(8).text(number, 390, 78, { width: 140, align: 'right' });
  if (taxLine) doc.text(taxLine, 330, 98, { width: 200, align: 'right' });
  doc.moveTo(36, 140).lineTo(559, 140).strokeColor(theme.secondary).lineWidth(1.5).stroke();
}

function documentInfoSection(doc, title, event, number, fonts, businessProfile, isInvoice) {
  const theme = documentTheme(businessProfile);
  doc.roundedRect(36, 156, 523, 122, theme.name === 'minimal' ? 3 : 10).fill(theme.soft).strokeColor(theme.secondary).lineWidth(0.9).stroke();
  doc.fillColor(theme.primary).font(fonts.bold).fontSize(12).text('Bill To', 52, 174);
  doc.fillColor(theme.ink).font(fonts.bold).fontSize(12).text(event.primaryClient || 'Customer', 52, 194, { width: 220 });
  const addressLine = event.clientAddress ? `Address: ${event.clientAddress}` : event.venue ? `Venue: ${event.venue}` : 'Venue: -';
  doc.fillColor(theme.muted).font(fonts.regular).fontSize(9)
    .text(event.mobile ? `Mobile: ${event.mobile}` : 'Mobile: -', 52, 214)
    .text(addressLine, 52, 230, { width: 220, height: 14 })
    .text(`Event: ${event.name || 'Untitled Event'}`, 52, 246, { width: 220 });
  if (event.clientGst) doc.text(`GST: ${event.clientGst}`, 52, 262, { width: 220 });

  const eventDates = event.dates.map((date) => prettyDate(date.date)).join(', ') || '-';
  doc.fillColor(theme.primary).font(fonts.bold).fontSize(12).text(`${title} Details`, 325, 174, { width: 210, align: 'right' });
  doc.fillColor(theme.ink).font(fonts.regular).fontSize(9)
    .text(`${title} No: ${number}`, 315, 196, { width: 220, align: 'right' })
    .text(`${title} Date: ${prettyDate(new Date().toISOString().slice(0, 10))}`, 315, 214, { width: 220, align: 'right' })
    .text(`Event Date: ${eventDates}`, 315, 232, { width: 220, align: 'right' });
  if (!isInvoice) doc.text('Valid Till: 15 days from quotation date', 315, 250, { width: 220, align: 'right' });
  if (businessProfile.bankName || businessProfile.accountNumber || businessProfile.upiId) {
    doc.fillColor('#5f6368').fontSize(8).text([businessProfile.bankName, businessProfile.accountNumber, businessProfile.upiId].filter(Boolean).join(' | '), 52, 286, { width: 480 });
  }
}

function tableHeader(doc, y, fonts, theme = documentTheme()) {
  doc.roundedRect(36, y, 523, 24, 4).fill(theme.primary);
  doc.fillColor('white').font(fonts.bold).fontSize(8)
    .text('Description', 48, y + 7, { width: 250 })
    .text('Pax/Qty', 310, y + 7, { width: 52, align: 'right' })
    .text('Rate', 372, y + 7, { width: 70, align: 'right' })
    .text('Amount', 460, y + 7, { width: 82, align: 'right' });
}

function ensurePageSpace(doc, y, needed = 44, onNewPage = null) {
  if (y + needed < 780) return y;
  doc.addPage();
  if (onNewPage) onNewPage();
  return 44;
}

function drawInvoiceRow(doc, y, fonts, columns, shaded = false, theme = documentTheme()) {
  if (shaded) doc.rect(36, y - 5, 523, 31).fill(theme.soft);
  doc.fillColor(theme.ink).font(fonts.regular).fontSize(8.5)
    .text(columns.description, 48, y, { width: 250, height: 22 })
    .text(columns.qty, 310, y, { width: 52, align: 'right' })
    .text(columns.rate, 372, y, { width: 70, align: 'right' })
    .text(columns.amount, 460, y, { width: 82, align: 'right' });
  doc.moveTo(36, y + 28).lineTo(559, y + 28).strokeColor('#e1e6e3').lineWidth(0.5).stroke();
}

function generateEventPdf({ res, db, event, type, businessProfile = emptyBusinessProfile() }) {
  const isInvoice = type === 'invoice';
  const title = isInvoice ? 'INVOICE' : 'QUOTATION';
  const number = documentNumber(isInvoice ? 'INV' : 'QUOTE', event);
  const totals = eventTotals(event);
  const doc = new PDFDocument({ size: 'A4', margin: 36, info: { Title: `${title} - ${event.name}` } });
  const fonts = configurePdfFonts(doc);
  const theme = documentTheme(businessProfile);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="${number}.pdf"`);
  doc.pipe(res);

  writeDocumentHeader(doc, title, event, number, fonts, businessProfile);
  documentInfoSection(doc, title, event, number, fonts, businessProfile, isInvoice);
  let y = 316;
  tableHeader(doc, y, fonts, theme);
  y += 32;

  let shaded = false;
  for (const date of event.dates) {
    y = ensurePageSpace(doc, y, 26, () => tableHeader(doc, 36, fonts, theme));
    doc.fillColor(theme.primary).font(fonts.bold).fontSize(10).text(`${prettyDate(date.date)}${date.label ? ` - ${date.label}` : ''}`, 42, y);
    y += 18;
    for (const slot of date.menuSlots) {
      y = ensurePageSpace(doc, y, 36, () => tableHeader(doc, 36, fonts, theme));
      const itemText = slot.menuItemIds.map((id) => menuDisplayById(db, id)).join(', ') || 'Menu items not selected';
      const amount = Number(slot.pax || 0) * Number(slot.pricePerPax || 0);
      drawInvoiceRow(doc, y, fonts, {
        description: `${slot.type}${slot.time ? ` (${slot.time})` : ''}\n${itemText}`,
        qty: `${slot.pax || ''}`,
        rate: money(slot.pricePerPax),
        amount: money(amount),
      }, shaded, theme);
      shaded = !shaded;
      y += 34;
    }
  }
  if ((event.addOns || []).length > 0) {
    y = ensurePageSpace(doc, y, 26, () => tableHeader(doc, 36, fonts, theme));
    doc.fillColor(theme.primary).font(fonts.bold).fontSize(10).text('Event Add-ons', 42, y);
    y += 18;
    for (const addOn of event.addOns || []) {
      y = ensurePageSpace(doc, y, 34, () => tableHeader(doc, 36, fonts, theme));
      drawInvoiceRow(doc, y, fonts, {
        description: addOn.title || 'Add-on',
        qty: '',
        rate: '',
        amount: money(addOn.cost),
      }, shaded, theme);
      shaded = !shaded;
      y += 34;
    }
  }

  y = ensurePageSpace(doc, y, 184);
  const totalsY = y + 6;
  const totalRows = [
    ['Menu Total', money(totals.menuTotal), '#202124', fonts.regular],
  ];
  if (totals.addOnTotal > 0) totalRows.push(['Add-ons Total', money(totals.addOnTotal), '#202124', fonts.regular]);
  totalRows.push(['Grand Total', money(totals.total), theme.primary, fonts.bold]);
  if (isInvoice) {
    totalRows.push(['Paid Till Now', money(totals.paid), '#0b6b3a', fonts.regular]);
    if (totals.discount > 0) totalRows.push(['Settled Discount', money(totals.discount), '#0b6b3a', fonts.regular]);
    totalRows.push(['Balance Due', money(totals.balance), totals.balance > 0 ? '#ba1a1a' : '#0b6b3a', fonts.bold]);
  }
  doc.roundedRect(332, totalsY, 227, Math.max(76, 28 + totalRows.length * 17), 7).fill(theme.soft).strokeColor('#eadfcf').stroke();
  totalRows.forEach((row, index) => {
    const rowY = totalsY + 12 + index * 17;
    doc.fillColor(row[2]).font(row[3]).fontSize(9).text(row[0], 348, rowY, { width: 92 });
    doc.text(row[1], 448, rowY, { width: 92, align: 'right' });
  });

  doc.fillColor(theme.primary).font(fonts.bold).fontSize(9).text('Amount in words', 36, y + 10);
  doc.fillColor(theme.ink).font(fonts.regular).fontSize(8.5).text(amountInWords(isInvoice ? totals.balance || totals.total : totals.total), 36, y + 26, { width: 270 });
  const terms = businessProfile.terms || (isInvoice ? 'Thank you for your payment. Balance, if any, is payable as per event agreement.' : 'Quotation is based on selected menu, pax and services. Final invoice may vary after confirmation.');
  doc.fillColor('#5f6368').font(fonts.regular).fontSize(8).text(terms, 36, y + 52, { width: 270, height: 48 });

  if (businessProfile.qrBase64) {
    drawProfileImage(doc, businessProfile.qrBase64, 36, y + 108, { fit: [58, 58] });
    doc.fillColor('#5f6368').font(fonts.regular).fontSize(7).text('Payment QR', 36, y + 168, { width: 58, align: 'center' });
  }
  const signatureY = Math.min(y + 130, 738);
  if (businessProfile.signatureBase64) drawProfileImage(doc, businessProfile.signatureBase64, 410, signatureY, { fit: [128, 38] });
  doc.moveTo(402, signatureY + 44).lineTo(546, signatureY + 44).strokeColor('#9aa3aa').lineWidth(0.5).stroke();
  doc.fillColor(theme.primary).font(fonts.bold).fontSize(9).text('Authorized Signature', 402, signatureY + 50, { width: 144, align: 'center', lineBreak: false });
  doc.fillColor(theme.muted).font(fonts.regular).fontSize(7).text(`Generated by CaterPro on ${prettyDate(new Date().toISOString().slice(0, 10))}`, 36, 780, { width: 523, align: 'center', lineBreak: false });
  doc.end();
}

function generateManualInvoicePdf({ res, invoice, businessProfile = emptyBusinessProfile() }) {
  const number = invoice.invoiceNumber || documentNumber('INV', { id: invoice.id });
  const event = {
    id: invoice.id,
    name: invoice.eventName || 'Manual Invoice',
    primaryClient: invoice.clientName || 'Customer',
    mobile: invoice.mobile || '',
    clientAddress: invoice.clientAddress || '',
    clientGst: invoice.clientGst || '',
    venue: invoice.venue || '',
    dates: invoice.eventDate ? [{ date: invoice.eventDate }] : [],
  };
  const doc = new PDFDocument({ size: 'A4', margin: 36, info: { Title: `INVOICE - ${event.name}` } });
  const fonts = configurePdfFonts(doc);
  const theme = documentTheme(businessProfile);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="${number}.pdf"`);
  doc.pipe(res);

  writeDocumentHeader(doc, 'INVOICE', event, number, fonts, businessProfile);
  documentInfoSection(doc, 'Invoice', event, number, fonts, businessProfile, true);
  let y = 316;
  tableHeader(doc, y, fonts, theme);
  y += 32;
  let shaded = false;
  for (const finalItem of invoice.items || []) {
    y = ensurePageSpace(doc, y, 34, () => tableHeader(doc, 36, fonts, theme));
    drawInvoiceRow(doc, y, fonts, {
      description: finalItem.title || 'Invoice item',
      qty: finalItem.quantity ? String(finalItem.quantity) : '',
      rate: finalItem.rate ? money(finalItem.rate) : '',
      amount: money(finalItem.amount),
    }, shaded, theme);
    shaded = !shaded;
    y += 34;
  }

  y = ensurePageSpace(doc, y, 184);
  const totalRows = [
    ['Subtotal', money(invoice.subtotal), '#202124', fonts.regular],
    ['Grand Total', money(invoice.total), theme.primary, fonts.bold],
    ['Advance / Paid', money(invoice.advance), '#0b6b3a', fonts.regular],
  ];
  if (invoice.settlement > 0) totalRows.push(['Settlement', money(invoice.settlement), '#0b6b3a', fonts.regular]);
  totalRows.push(['Pending', money(invoice.pending), invoice.pending > 0 ? '#ba1a1a' : '#0b6b3a', fonts.bold]);
  const totalsY = y + 6;
  doc.roundedRect(332, totalsY, 227, Math.max(76, 28 + totalRows.length * 17), 7).fill(theme.soft).strokeColor('#eadfcf').stroke();
  totalRows.forEach((row, index) => {
    const rowY = totalsY + 12 + index * 17;
    doc.fillColor(row[2]).font(row[3]).fontSize(9).text(row[0], 348, rowY, { width: 92 });
    doc.text(row[1], 448, rowY, { width: 92, align: 'right' });
  });
  doc.fillColor(theme.primary).font(fonts.bold).fontSize(9).text('Amount in words', 36, y + 10);
  doc.fillColor(theme.ink).font(fonts.regular).fontSize(8.5).text(amountInWords(invoice.pending || invoice.total), 36, y + 26, { width: 270 });
  if (invoice.notes) doc.fillColor('#5f6368').font(fonts.regular).fontSize(8).text(invoice.notes, 36, y + 52, { width: 270, height: 48 });
  if (businessProfile.qrBase64) {
    drawProfileImage(doc, businessProfile.qrBase64, 36, y + 108, { fit: [58, 58] });
    doc.fillColor('#5f6368').font(fonts.regular).fontSize(7).text('Payment QR', 36, y + 168, { width: 58, align: 'center' });
  }
  const signatureY = Math.min(y + 130, 738);
  if (businessProfile.signatureBase64) drawProfileImage(doc, businessProfile.signatureBase64, 410, signatureY, { fit: [128, 38] });
  doc.moveTo(402, signatureY + 44).lineTo(546, signatureY + 44).strokeColor('#9aa3aa').lineWidth(0.5).stroke();
  doc.fillColor(theme.primary).font(fonts.bold).fontSize(9).text('Authorized Signature', 402, signatureY + 50, { width: 144, align: 'center', lineBreak: false });
  doc.fillColor(theme.muted).font(fonts.regular).fontSize(7).text(`Generated by CaterPro on ${prettyDate(new Date().toISOString().slice(0, 10))}`, 36, 780, { width: 523, align: 'center', lineBreak: false });
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
  return `${client}${date ? ` - ${prettyDate(date.date)}` : ''}`;
}

function menuHeader(doc, event, date, fonts, businessProfile, pageLabel, pageNo) {
  const theme = documentTheme(businessProfile);
  doc.rect(0, 0, doc.page.width, doc.page.height).fill(theme.page);
  doc.roundedRect(28, 24, 539, 78, theme.name === 'minimal' ? 3 : 10).fill(theme.primary);
  doc.roundedRect(28, 24, 8, 78, 3).fill(theme.secondary);
  doc.circle(74, 63, 23).lineWidth(1.6).strokeColor(theme.secondary).stroke();
  if (!drawProfileImage(doc, businessProfile.logoBase64, 52, 50, { fit: [44, 44] })) {
    doc.fillColor('white').font(fonts.bold).fontSize(12).text((businessProfile.businessName || 'CP').slice(0, 2).toUpperCase(), 52, 57, { width: 44, align: 'center' });
  }
  doc.fillColor('white').font(fonts.bold).fontSize(15).text(businessProfile.businessName || 'CaterPro', 108, 40, { width: 260 });
  doc.fillColor('#f6f2df').font(fonts.regular).fontSize(7.5).text(businessProfile.address || 'Event menu', 108, 62, { width: 260, height: 18 });
  doc.font(fonts.regular).fontSize(7).text([businessProfile.phone, businessProfile.email].filter(Boolean).join(' | '), 108, 84, { width: 260 });
  doc.fillColor('white').font(fonts.bold).fontSize(16).text('EVENT MENU', 386, 40, { width: 140, align: 'right' });
  doc.font(fonts.regular).fontSize(7.6).text(pageLabel, 386, 64, { width: 140, align: 'right' });
  doc.text(`Page ${pageNo}`, 386, 84, { width: 140, align: 'right' });

  doc.roundedRect(42, 118, 511, 48, 8).fill(theme.soft);
  doc.roundedRect(42, 118, 6, 48, 3).fill(theme.secondary);
  doc.fillColor(theme.primary).font(fonts.bold).fontSize(11).text(event.primaryClient || event.name || 'Customer', 58, 130, { width: 230 });
  doc.fillColor(theme.ink).font(fonts.regular).fontSize(8).text(`Event: ${event.name || '-'}`, 58, 146, { width: 230 });
  doc.fillColor(theme.primary).font(fonts.bold).fontSize(10).text(date.label || 'Event Date', 320, 129, { width: 200, align: 'right' });
  doc.fillColor(theme.ink).font(fonts.regular).fontSize(8)
    .text(prettyDate(date.date), 320, 145, { width: 200, align: 'right' });
}

function drawChefMenuItem(doc, item, x, y, width, fonts, shaded = false) {
  if (shaded) doc.roundedRect(x - 4, y - 2, width, 12, 2).fill('#f2f7f5');
  doc.rect(x, y + 1, 5, 5).strokeColor('#68747b').lineWidth(0.5).stroke();
  const textX = x + 12;
  const text = item.kannada && item.english ? `${item.kannada} / ${item.english}` : item.kannada || item.english;
  drawSingleLineText(doc, text, textX, y - 1, width - 16, fonts, { fontSize: 6.5, height: 11 });
}

function menuFooter(doc, fonts, businessProfile, pageNo) {
  doc.moveTo(42, 780).lineTo(553, 780).strokeColor('#e1d8c8').lineWidth(0.6).stroke();
  doc.fillColor('#9a7c25').font(fonts.regular).fontSize(7).text(businessProfile.businessName || 'CaterPro', 42, 788, { width: 220, lineBreak: false });
  doc.text(`Page ${pageNo}`, 470, 788, { width: 82, align: 'right', lineBreak: false });
}

function drawServiceSection(doc, date, y, fonts) {
  if (!date.additionalServices.length) return y;
  doc.fillColor('#1b4d3e').font(fonts.bold).fontSize(10).text('Service Requirements', 42, y);
  y += 16;
  date.additionalServices.forEach((service, index) => {
    const x = index % 2 === 0 ? 42 : 304;
    if (index > 0 && index % 2 === 0) y += 18;
    const quantity = serviceQuantityText(service);
    doc.rect(x, y + 2, 7, 7).strokeColor('#68747b').lineWidth(0.5).stroke();
    doc.fillColor('#202124').font(fonts.regular).fontSize(8).text(`${service.name}${quantity ? ` - ${quantity}` : ''}`, x + 14, y, { width: 220 });
  });
  return y + 28;
}

function drawMenuPage({ doc, db, event, date, fonts, pageLabel, businessProfile, pageNo }) {
  menuHeader(doc, event, date, fonts, businessProfile, pageLabel, pageNo);
  const theme = documentTheme(businessProfile);
  let y = drawServiceSection(doc, date, 182, fonts);
  if (date.menuSlots.length === 0) {
    doc.fillColor('#5f6368').font(fonts.regular).fontSize(11).text('No menu configured for this date.', 42, y + 12);
    menuFooter(doc, fonts, businessProfile, pageNo);
    return pageNo;
  }

  for (const slot of date.menuSlots) {
    const items = slot.menuItemIds.map((id) => menuPartsById(db, id));
    const rowHeight = Math.max(50, 36 + Math.ceil(Math.max(items.length, 1) / 3) * 14);
    if (y + rowHeight > 786) {
      menuFooter(doc, fonts, businessProfile, pageNo);
      doc.addPage();
      pageNo += 1;
      menuHeader(doc, event, date, fonts, businessProfile, pageLabel, pageNo);
      y = 182;
    }
    const color = mealAccent(slot.type);
    doc.roundedRect(42, y, 511, rowHeight, 8).fill('white').strokeColor('#eadfcf').lineWidth(0.7).stroke();
    doc.roundedRect(42, y, 7, rowHeight, 3).fill(color || theme.accent);
    doc.fillColor(color || theme.accent).font(fonts.bold).fontSize(11).text(slot.type || 'Menu', 58, y + 8, { width: 150 });
    const line = [slot.time, slot.pax ? `${slot.pax} pax` : ''].filter(Boolean).join(' - ');
    doc.fillColor('#4b565c').font(fonts.regular).fontSize(7.4).text(line, 58, y + 23, { width: 150 });
    items.forEach((item, index) => {
      const col = index % 3;
      const row = Math.floor(index / 3);
      drawChefMenuItem(doc, item, col === 0 ? 58 : col === 1 ? 224 : 390, y + 40 + row * 14, 148, fonts, row % 2 === 1);
    });
    y += rowHeight + 10;
  }
  menuFooter(doc, fonts, businessProfile, pageNo);
  return pageNo;
}

function generateMenuPdf({ res, db, event, dateId, allDates = false, businessProfile = emptyBusinessProfile() }) {
  const hasMenuContent = (date) => date.menuSlots.length > 0 || date.additionalServices.length > 0;
  const dates = allDates ? event.dates.filter(hasMenuContent) : event.dates.filter((date) => date.id === dateId || date.date === dateId);
  if (!dates.length) {
    res.status(404).json({ message: 'Event date not found' });
    return;
  }
  const doc = new PDFDocument({ size: 'A4', margin: 28, info: { Title: `Menu - ${event.name}` }, autoFirstPage: false });
  const fonts = configurePdfFonts(doc);
  const suffix = allDates ? 'ALL_DAYS' : (dates[0].date || dates[0].id);
  const number = `MENU_${event.id}_${suffix}`.replace(/[^A-Za-z0-9_-]/g, '_');
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="${number}.pdf"`);
  doc.pipe(res);
  let pageNo = 1;
  dates.forEach((date, index) => {
    doc.addPage();
    pageNo = drawMenuPage({ doc, db, event, date, fonts, pageLabel: allDates ? `Day ${index + 1} of ${dates.length}` : 'Single day menu', businessProfile, pageNo });
    pageNo += 1;
  });
  doc.end();
}

function generateMaterialDocumentPdf({ res, event, materialDocument, businessProfile = emptyBusinessProfile() }) {
  const title = materialDocument.type === 'produce' ? 'VEGETABLES & FRUITS' : 'RAW MATERIALS';
  const filePrefix = materialDocument.type === 'produce' ? 'PRODUCE' : 'RAW';
  const number = `${filePrefix}_${event.id}_${materialDocument.id}`.replace(/[^A-Za-z0-9_-]/g, '_');
  const doc = new PDFDocument({ size: 'A4', margin: 28, info: { Title: `${title} - ${event.name}` } });
  const fonts = configurePdfFonts(doc);
  const theme = documentTheme(businessProfile);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="${number}.pdf"`);
  doc.pipe(res);

  function drawHeader(pageNo = 1) {
    doc.rect(0, 0, doc.page.width, doc.page.height).fill('#fbf8f1');
    doc.roundedRect(28, 24, 539, 70, 8).fill(theme.primary);
    doc.roundedRect(28, 24, 8, 70, 3).fill(theme.secondary);
    doc.fillColor('white').font(fonts.bold).fontSize(17).text(title, 46, 42, { width: 230 });
    doc.fillColor('#f6f2df').font(fonts.regular).fontSize(8).text(materialDocument.title || title, 46, 66, { width: 260 });
    doc.fillColor('white').font(fonts.bold).fontSize(10).text(event.primaryClient || event.name || 'Event', 320, 40, { width: 210, align: 'right' });
    doc.fillColor('#f6f2df').font(fonts.regular).fontSize(7.5)
      .text(event.name || 'Untitled Event', 320, 58, { width: 210, align: 'right' })
      .text(`${prettyDate(new Date().toISOString().slice(0, 10))} | Page ${pageNo}`, 320, 76, { width: 210, align: 'right' });
  }

  function drawTableHeader(y) {
    doc.rect(36, y, 522, 18).fill(theme.secondary).strokeColor('#8a6b18').lineWidth(0.5).stroke();
    const groups = [36, 210, 384];
    groups.forEach((x) => {
      doc.rect(x, y, 174, 18).strokeColor('#8a6b18').lineWidth(0.5).stroke();
      doc.fillColor('#3b2a00').font(fonts.bold).fontSize(7)
        .text('#', x + 5, y + 5, { width: 18 })
        .text('Item', x + 25, y + 5, { width: 98 })
        .text('Qty', x + 125, y + 5, { width: 42, align: 'right' });
    });
  }

  drawHeader();
  doc.roundedRect(36, 110, 523, 38, 6).fill(theme.soft);
  doc.fillColor(theme.primary).font(fonts.bold).fontSize(10).text(event.venue || 'Event requirements', 50, 120, { width: 290 });
  doc.fillColor(theme.ink).font(fonts.regular).fontSize(8).text([event.mobile, businessProfile.businessName].filter(Boolean).join(' | '), 50, 134, { width: 290 });
  doc.fillColor(theme.primary).font(fonts.bold).fontSize(10).text(`${materialDocument.items.length} items`, 430, 124, { width: 90, align: 'right' });

  let pageNo = 1;
  let y = 166;
  drawTableHeader(y);
  y += 18;
  const groupWidth = 174;
  const rowHeight = 22;
  const rows = Math.ceil(materialDocument.items.length / 3);
  for (let rowIndex = 0; rowIndex < rows; rowIndex += 1) {
    if (y + rowHeight > 792) {
      doc.fillColor('#9a7c25').font(fonts.regular).fontSize(7).text(businessProfile.businessName || 'CaterPro', 36, 788, { width: 220, lineBreak: false });
      doc.addPage();
      pageNo += 1;
      drawHeader(pageNo);
      y = 116;
      drawTableHeader(y);
      y += 18;
    }
    const shaded = rowIndex % 2 === 0;
    for (let col = 0; col < 3; col += 1) {
      const index = rowIndex * 3 + col;
      const item = materialDocument.items[index];
      const x = 36 + col * groupWidth;
      doc.rect(x, y, groupWidth, rowHeight).fill(shaded ? '#ffffff' : '#f6f0e4').strokeColor('#8f9aa3').lineWidth(0.45).stroke();
      if (!item) continue;
      doc.fillColor(theme.muted).font(fonts.regular).fontSize(6.8).text(String(index + 1), x + 5, y + 7, { width: 16 });
      drawSingleLineText(doc, item.name || item.itemId, x + 25, y + 5, 96, fonts, { fontSize: 7.1, height: 12, color: theme.ink });
      doc.fillColor(theme.primary).font(fonts.bold).fontSize(7.2).text([item.quantity, item.unit].filter(Boolean).join(' '), x + 125, y + 6, { width: 42, align: 'right' });
    }
    y += rowHeight;
  }
  doc.fillColor('#9a7c25').font(fonts.regular).fontSize(7).text(businessProfile.businessName || 'CaterPro', 36, 788, { width: 220, lineBreak: false });
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
      CustomMenu: { type: 'object', properties: { id: { type: 'string' }, name: { type: 'string' }, type: { type: 'string' }, itemIds: { type: 'array', items: { type: 'string' } } } },
      RawMaterial: { type: 'object', properties: { id: { type: 'string' }, name: { type: 'string' }, category: { type: 'string' }, unit: { type: 'string' } } },
      ProduceItem: { type: 'object', properties: { id: { type: 'string' }, name: { type: 'string' }, category: { type: 'string' }, unit: { type: 'string' } } },
      MaterialDocument: { type: 'object', properties: { id: { type: 'string' }, type: { type: 'string', enum: ['raw', 'produce'] }, title: { type: 'string' }, items: { type: 'array' } } },
      Event: { type: 'object', properties: { id: { type: 'string' }, name: { type: 'string' }, mobile: { type: 'string' }, venue: { type: 'string' }, dates: { type: 'array' }, materialDocuments: { type: 'array' } } },
    },
  },
  paths: {
    '/health': { get: { summary: 'Health check', responses: { 200: { description: 'OK' } } } },
    '/api/auth/login': { post: { tags: ['Auth'], summary: 'Login', requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/LoginRequest' } } } }, responses: { 200: { description: 'Token and user' }, 401: { description: 'Invalid credentials' } } } },
    '/api/bootstrap': { get: { tags: ['User Data'], security: [{ bearerAuth: [] }], summary: 'Load universal and user-owned data', responses: { 200: { description: 'Bootstrap data' }, 401: { description: 'Unauthorized' } } } },
    '/api/business-profile': { put: { tags: ['User Data'], security: [{ bearerAuth: [] }], summary: 'Save logged-in user business profile, including base64 logo/signature/QR', responses: { 200: { description: 'Saved business profile' }, 401: { description: 'Unauthorized' } } } },
    '/api/clients': { get: { tags: ['User Data'], security: [{ bearerAuth: [] }], summary: 'List clients' }, post: { tags: ['User Data'], security: [{ bearerAuth: [] }], summary: 'Create client' } },
    '/api/clients/{id}': { put: { tags: ['User Data'], security: [{ bearerAuth: [] }], summary: 'Update client' }, delete: { tags: ['User Data'], security: [{ bearerAuth: [] }], summary: 'Delete client' } },
    '/api/menu-items': { get: { tags: ['Universal Catalogs'], summary: 'List universal menu items', responses: { 200: { description: 'Menu items' } } }, post: { tags: ['Universal Catalogs'], summary: 'Create universal menu item', requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/MenuItem' } } } }, responses: { 201: { description: 'Created' } } } },
    '/api/menu-items/{id}': { put: { tags: ['Universal Catalogs'], summary: 'Update universal menu item', parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'Updated' }, 404: { description: 'Not found' } } } },
    '/api/custom-menus': { get: { tags: ['User Data'], security: [{ bearerAuth: [] }], summary: 'List ready made custom menus for the logged-in user', responses: { 200: { description: 'Custom menus' } } }, post: { tags: ['User Data'], security: [{ bearerAuth: [] }], summary: 'Create ready made custom menu', requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/CustomMenu' } } } }, responses: { 201: { description: 'Created' } } } },
    '/api/custom-menus/{id}': { put: { tags: ['User Data'], security: [{ bearerAuth: [] }], summary: 'Update ready made custom menu', parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'Updated' }, 404: { description: 'Not found' } } } },
    '/api/raw-materials': { get: { tags: ['Universal Catalogs'], summary: 'List universal raw materials', responses: { 200: { description: 'Raw materials' } } }, post: { tags: ['Universal Catalogs'], summary: 'Create universal raw material', responses: { 201: { description: 'Created' } } } },
    '/api/raw-materials/{id}': { put: { tags: ['Universal Catalogs'], summary: 'Update universal raw material', parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'Updated' }, 404: { description: 'Not found' } } } },
    '/api/produce-items': { get: { tags: ['Universal Catalogs'], summary: 'List universal vegetables and fruits', responses: { 200: { description: 'Vegetables and fruits' } } }, post: { tags: ['Universal Catalogs'], summary: 'Create universal vegetable/fruit item', responses: { 201: { description: 'Created' } } } },
    '/api/produce-items/{id}': { put: { tags: ['Universal Catalogs'], summary: 'Update universal vegetable/fruit item', parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'Updated' }, 404: { description: 'Not found' } } } },
    '/api/events': { get: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'List user events', responses: { 200: { description: 'Events' } } }, post: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Create full event shell', requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/Event' } } } }, responses: { 201: { description: 'Created' } } } },
    '/api/events/{eventId}': { get: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Get event' }, put: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Update event' } },
    '/api/events/{eventId}/dates': { post: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Add event date' } },
    '/api/events/{eventId}/dates/{dateId}/menu-slots': { post: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Add menu type/slot for date' } },
    '/api/events/{eventId}/dates/{dateId}/additional-services': { post: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Add additional service for date' } },
    '/api/events/{eventId}/payments': { post: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Record event payment' } },
    '/api/events/{eventId}/material-documents': { post: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Create raw material or vegetable/fruit document for event' } },
    '/api/events/{eventId}/material-documents/{documentId}': { put: { tags: ['Events'], security: [{ bearerAuth: [] }], summary: 'Update event material document' } },
    '/api/events/{eventId}/material-documents/{documentId}/pdf': { get: { tags: ['Events'], summary: 'Download raw material or vegetable/fruit PDF', parameters: [{ name: 'eventId', in: 'path', required: true, schema: { type: 'string' } }, { name: 'documentId', in: 'path', required: true, schema: { type: 'string' } }, { name: 'token', in: 'query', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'PDF file' } } } },
    '/api/events/{eventId}/documents/{type}': { get: { tags: ['Events'], summary: 'Download event PDF document', parameters: [{ name: 'eventId', in: 'path', required: true, schema: { type: 'string' } }, { name: 'type', in: 'path', required: true, schema: { type: 'string', enum: ['quotation', 'invoice', 'menu', 'all-menus'] } }, { name: 'dateId', in: 'query', required: false, schema: { type: 'string' } }, { name: 'token', in: 'query', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'PDF file' }, 404: { description: 'Event not found' } } } },
    '/api/manual-invoices': { get: { tags: ['User Data'], security: [{ bearerAuth: [] }], summary: 'List manual invoices' }, post: { tags: ['User Data'], security: [{ bearerAuth: [] }], summary: 'Create manual invoice and upsert client' } },
    '/api/manual-invoices/{invoiceId}/pdf': { get: { tags: ['User Data'], summary: 'Download manual invoice PDF' } },
  },
};

const apiDocs = {
  name: 'CaterPro API',
  version: '0.2.0',
  swagger: '/api/docs',
  openapi: '/api/openapi.json',
  demoUser: { email: 'admin@caterpro.in', password: 'password' },
  ownership: {
    universal: ['menuItems', 'rawMaterials', 'produceItems'],
    userOwned: ['events', 'clients', 'employees', 'additionalServices', 'customMenus', 'businessProfile', 'payments', 'manualInvoices'],
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
  db.userData[user.id] = ensureUserDataShape(db.userData[user.id] || emptyUserData());
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
  db.userData[user.id] = ensureUserDataShape(emptyUserData());
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

app.put('/api/business-profile', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const profile = { ...emptyBusinessProfile(), ...req.body };
  db.userData[user.id].businessProfile = profile;
  writeDb(db);
  res.json(profile);
});

app.get('/api/clients', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  res.json(db.userData[user.id].clients);
});

app.post('/api/clients', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const client = clientFromBody(req.body);
  if (!client.name || !client.mobile) return res.status(400).json({ message: 'Client name and mobile number are required' });
  if (client.mobile.length !== 10) return res.status(400).json({ message: 'Mobile number must be 10 digits' });
  const existing = db.userData[user.id].clients.find((item) => normalizeMobile(item.mobile) === client.mobile);
  const saved = clientFromBody(client, existing || {});
  upsertById(db.userData[user.id].clients, saved);
  writeDb(db);
  res.status(existing ? 200 : 201).json(saved);
});

app.put('/api/clients/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const existing = db.userData[user.id].clients.find((item) => item.id === req.params.id);
  if (!existing) return res.status(404).json({ message: 'Client not found' });
  const client = clientFromBody({ ...req.body, id: req.params.id }, existing);
  if (!client.name || !client.mobile) return res.status(400).json({ message: 'Client name and mobile number are required' });
  if (client.mobile.length !== 10) return res.status(400).json({ message: 'Mobile number must be 10 digits' });
  upsertById(db.userData[user.id].clients, client);
  writeDb(db);
  res.json(client);
});

app.delete('/api/clients/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const before = db.userData[user.id].clients.length;
  db.userData[user.id].clients = db.userData[user.id].clients.filter((item) => item.id !== req.params.id);
  if (db.userData[user.id].clients.length === before) return res.status(404).json({ message: 'Client not found' });
  writeDb(db);
  res.json({ message: 'Client deleted' });
});

app.get('/api/manual-invoices', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  res.json(db.userData[user.id].manualInvoices);
});

app.post('/api/manual-invoices', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const invoice = manualInvoiceFromBody(req.body);
  if (!invoice.clientName || !invoice.mobile) return res.status(400).json({ message: 'Client name and mobile number are required' });
  if (invoice.mobile.length !== 10) return res.status(400).json({ message: 'Mobile number must be 10 digits' });
  if (!invoice.eventName || !invoice.invoiceDate) return res.status(400).json({ message: 'Event name and invoice date are required' });
  if (!invoice.items.length) return res.status(400).json({ message: 'Add at least one invoice item' });
  invoice.invoiceNumber = invoice.invoiceNumber || documentNumber('INV', { id: invoice.id });
  const existingClient = db.userData[user.id].clients.find((client) => normalizeMobile(client.mobile) === invoice.mobile);
  const client = {
    ...(existingClient || {}),
    id: existingClient?.id || makeId('client'),
    name: invoice.clientName,
    mobile: invoice.mobile,
    address: invoice.clientAddress || existingClient?.address || '',
    gst: invoice.clientGst || existingClient?.gst || '',
    updatedAt: new Date().toISOString(),
    createdAt: existingClient?.createdAt || new Date().toISOString(),
  };
  upsertById(db.userData[user.id].clients, client);
  db.userData[user.id].manualInvoices.push(invoice);
  writeDb(db);
  res.status(201).json(invoice);
});

app.get('/api/manual-invoices/:invoiceId/pdf', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const invoice = db.userData[user.id].manualInvoices.find((item) => item.id === req.params.invoiceId);
  if (!invoice) return res.status(404).json({ message: 'Manual invoice not found' });
  return generateManualInvoicePdf({ res, invoice, businessProfile: db.userData[user.id].businessProfile });
});

app.get('/api/custom-menus', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  res.json(db.userData[user.id].customMenus);
});

app.post('/api/custom-menus', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const menu = {
    id: req.body.id || makeId('cmenu'),
    name: req.body.name || '',
    type: req.body.type || '',
    itemIds: Array.isArray(req.body.itemIds) ? req.body.itemIds : [],
    updatedAt: new Date().toISOString(),
  };
  upsertById(db.userData[user.id].customMenus, menu);
  writeDb(db);
  res.status(201).json(menu);
});

app.put('/api/custom-menus/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const existing = db.userData[user.id].customMenus.find((menu) => menu.id === req.params.id);
  if (!existing) return res.status(404).json({ message: 'Custom menu not found' });
  const menu = {
    ...existing,
    ...req.body,
    id: req.params.id,
    itemIds: Array.isArray(req.body.itemIds) ? req.body.itemIds : existing.itemIds,
    updatedAt: new Date().toISOString(),
  };
  upsertById(db.userData[user.id].customMenus, menu);
  writeDb(db);
  res.json(menu);
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
  writeDb(db);
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

app.get('/api/produce-items', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  writeDb(db);
  res.json(db.universal.produceItems);
});

app.post('/api/produce-items', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  const item = { id: req.body.id || makeId('prd'), name: req.body.name || '', category: req.body.category || '', unit: req.body.unit || '' };
  upsertById(db.universal.produceItems, item);
  writeDb(db);
  res.status(201).json(item);
});

app.put('/api/produce-items/:id', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  const existing = db.universal.produceItems.find((item) => item.id === req.params.id);
  if (!existing) return res.status(404).json({ message: 'Vegetable/fruit item not found' });
  const item = { ...existing, ...req.body, id: req.params.id };
  upsertById(db.universal.produceItems, item);
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

app.post('/api/events/:eventId/material-documents', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  event.materialDocuments = event.materialDocuments || [];
  const materialDocument = materialDocumentFromBody(req.body);
  event.materialDocuments.push(materialDocument);
  event.updatedAt = new Date().toISOString();
  writeDb(db);
  res.status(201).json(materialDocument);
});

app.put('/api/events/:eventId/material-documents/:documentId', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  event.materialDocuments = event.materialDocuments || [];
  const existing = event.materialDocuments.find((item) => item.id === req.params.documentId);
  if (!existing) return res.status(404).json({ message: 'Material document not found' });
  Object.assign(existing, materialDocumentFromBody({ ...req.body, id: req.params.documentId }, existing));
  event.updatedAt = new Date().toISOString();
  writeDb(db);
  res.json(existing);
});

app.get('/api/events/:eventId/material-documents/:documentId/pdf', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  const materialDocument = (event.materialDocuments || []).find((item) => item.id === req.params.documentId);
  if (!materialDocument) return res.status(404).json({ message: 'Material document not found' });
  return generateMaterialDocumentPdf({ res, event, materialDocument, businessProfile: db.userData[user.id].businessProfile });
});

app.get('/api/events/:eventId/documents/:type', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  if (req.params.type === 'menu') {
    return generateMenuPdf({ res, db, event, dateId: req.query.dateId || event.dates[0]?.id || event.dates[0]?.date, businessProfile: db.userData[user.id].businessProfile });
  }
  if (req.params.type === 'all-menus') {
    return generateMenuPdf({ res, db, event, allDates: true, businessProfile: db.userData[user.id].businessProfile });
  }
  if (!['quotation', 'invoice'].includes(req.params.type)) return res.status(400).json({ message: 'Document type must be quotation, invoice, menu, or all-menus' });
  return generateEventPdf({ res, db, event, type: req.params.type, businessProfile: db.userData[user.id].businessProfile });
});

app.use((req, res) => res.status(404).json({ message: 'Not found' }));

app.listen(port, '0.0.0.0', () => {
  console.log(`CaterPro API running on port ${port}`);
});
