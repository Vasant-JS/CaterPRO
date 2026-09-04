const express = require('express');
const swaggerUi = require('swagger-ui-express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const PDFDocument = require('pdfkit');
const { createClient } = require('@supabase/supabase-js');

function loadLocalEnvFile() {
  const envPath = path.join(__dirname, '.env');
  if (!fs.existsSync(envPath)) return;
  const lines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#') || !trimmed.includes('=')) continue;
    const index = trimmed.indexOf('=');
    const key = trimmed.slice(0, index).trim();
    let value = trimmed.slice(index + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (key && process.env[key] === undefined) process.env[key] = value;
  }
}

loadLocalEnvFile();

const app = express();
const port = Number(process.env.PORT || 8787);
const caterProBrandUrl = 'https://caterpro.in';
const caterProPdfFooter = 'Generated with CaterPro | Catering events, menus, invoices & payments made simple';
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const supabaseStateId = process.env.SUPABASE_STATE_ID || 'default';
const supabase = supabaseUrl && supabaseServiceRoleKey ? createClient(supabaseUrl, supabaseServiceRoleKey, { auth: { persistSession: false } }) : null;
const consolidatedMenuExports = new Map();
let runtimeDb = null;
let pendingSupabaseWrite = Promise.resolve();

app.use(express.json({ limit: '50mb' }));
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

function readDb() {
  if (!runtimeDb) {
    throw new Error('Online database state is not loaded. Check Supabase table data.');
  }
  ensureUniversal(runtimeDb);
  return runtimeDb;
}

function writeDb(db, options = {}) {
  ensureUniversal(db);
  runtimeDb = db;
  scheduleSupabaseSave(db, options);
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function requireSupabaseConfigured() {
  if (!supabase) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required. Supabase storage is mandatory.');
  }
}

async function supabaseRequest(builder) {
  const { data, error, count } = await builder;
  if (error) throw error;
  return { data, count };
}

async function loadSupabaseDb() {
  if (!supabase) return null;
  return loadSupabaseTableState();
}

async function saveSupabaseDb(db, { syncMirrorTables = false, userId = null, includeUniversal = false } = {}) {
  if (!supabase) return { status: 'disabled', tables: {} };
  try {
    if (syncMirrorTables) return await syncSupabaseTables(db);
    if (userId) return await replaceSupabaseUserTableState(db, userId, { includeUniversal });
    return await upsertSupabaseTableState(db);
  } catch (error) {
    console.warn('Supabase table sync skipped:', error.message);
    return { status: 'failed', error: error.message, tables: {} };
  }
}

function hasBusinessProfileDetails(profile = {}) {
  return [
    'businessName',
    'serviceType',
    'gstin',
    'pan',
    'address',
    'phone',
    'email',
    'accountHolderName',
    'bankName',
    'branchName',
    'accountNumber',
    'ifsc',
    'terms',
    'logoBase64',
    'signatureBase64',
    'qrBase64',
  ].some((key) => String(profile?.[key] || '').trim());
}

function hasBusinessProfileImages(profile = {}) {
  return ['logoBase64', 'signatureBase64', 'qrBase64']
    .every((key) => String(profile?.[key] || '').trim());
}

function mergeBusinessProfile(existing = {}, incoming = {}) {
  const merged = { ...emptyBusinessProfile(), ...existing, ...incoming };
  for (const [key, value] of Object.entries(existing || {})) {
    if (typeof value === 'string' && value.trim() && typeof incoming?.[key] === 'string' && !incoming[key].trim()) {
      merged[key] = value;
    }
  }
  return merged;
}

function businessProfileFromSupabaseRow(row = {}) {
  const raw = row.raw && typeof row.raw === 'object' && !Array.isArray(row.raw) ? row.raw : {};
  return mergeBusinessProfile(raw, {
    businessName: row.business_name || raw.businessName || '',
    serviceType: row.service_type || raw.serviceType || '',
    gstin: row.gstin || raw.gstin || '',
    gstType: row.gst_type || raw.gstType || 'cgst_sgst',
    gstRate: Number(row.gst_rate ?? raw.gstRate ?? 5) || 5,
    ifsc: row.ifsc || raw.ifsc || '',
    phone: row.phone || raw.phone || '',
    email: row.email || raw.email || '',
  });
}

async function loadSupabaseBusinessProfile(userId) {
  if (!supabase) return null;
  const exact = await supabaseRequest(
    supabase
      .from('cp_business_profiles')
      .select('business_name,service_type,gstin,gst_type,gst_rate,ifsc,phone,email,raw')
      .eq('state_id', supabaseStateId)
      .eq('user_id', userId)
      .maybeSingle(),
  );
  const exactProfile = businessProfileFromSupabaseRow(exact.data || {});
  if (hasBusinessProfileDetails(exactProfile)) return exactProfile;

  const { data: stateProfiles } = await supabaseRequest(
    supabase
      .from('cp_business_profiles')
      .select('business_name,service_type,gstin,gst_type,gst_rate,ifsc,phone,email,raw')
      .eq('state_id', supabaseStateId)
      .limit(2),
  );
  const usefulProfiles = asArray(stateProfiles)
    .map(businessProfileFromSupabaseRow)
    .filter(hasBusinessProfileDetails);
  return usefulProfiles.length === 1 ? usefulProfiles[0] : null;
}

async function hydrateBusinessProfileFromSupabase(db, userId) {
  db.userData[userId] = ensureUserDataShape(db.userData[userId] || emptyUserData());
  const current = db.userData[userId].businessProfile || emptyBusinessProfile();
  if (hasBusinessProfileDetails(current) && hasBusinessProfileImages(current)) return false;
  try {
    const profile = await loadSupabaseBusinessProfile(userId);
    if (!profile || (!hasBusinessProfileDetails(profile) && !hasBusinessProfileImages(profile))) return false;
    const merged = mergeBusinessProfile(current, profile);
    const changed = JSON.stringify(current) !== JSON.stringify(merged);
    db.userData[userId].businessProfile = merged;
    return changed;
  } catch (error) {
    console.warn('Supabase business profile recovery skipped:', error.message);
    return false;
  }
}

function userMenuItemFromSupabaseRow(row = {}) {
  const raw = row.raw && typeof row.raw === 'object' && !Array.isArray(row.raw) ? row.raw : {};
  return {
    ...raw,
    id: row.id || raw.id || makeId('mnu'),
    english: row.english ?? raw.english ?? '',
    kannada: row.kannada ?? raw.kannada ?? '',
    title: row.title ?? raw.title ?? `${row.kannada || raw.kannada || ''}/${row.english || raw.english || ''}`,
    category: row.category ?? raw.category ?? '',
    meals: asArray(row.meals ?? raw.meals),
    veg: row.veg === null || row.veg === undefined ? Boolean(raw.veg) : Boolean(row.veg),
  };
}

function rawFromSupabaseRow(row = {}) {
  return row.raw && typeof row.raw === 'object' && !Array.isArray(row.raw) ? row.raw : {};
}

function userFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return {
    ...raw,
    id: row.id || raw.id || makeId('usr'),
    name: row.name ?? raw.name ?? '',
    email: row.email ?? raw.email ?? '',
    role: row.role ?? raw.role ?? '',
  };
}

function inventoryItemFromSupabaseRow(row = {}, prefix = 'itm') {
  const raw = rawFromSupabaseRow(row);
  return {
    ...raw,
    id: row.id || raw.id || makeId(prefix),
    name: row.name ?? raw.name ?? '',
    category: row.category ?? raw.category ?? '',
    unit: row.unit ?? raw.unit ?? '',
  };
}

function additionalServiceFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return {
    ...raw,
    id: row.id || raw.id || makeId('svc'),
    name: row.name ?? raw.name ?? '',
    unit: row.unit ?? raw.unit ?? '',
    price: Number(row.price ?? raw.price ?? 0) || 0,
  };
}

function clientFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return {
    ...raw,
    id: row.id || raw.id || makeId('cli'),
    name: row.name ?? raw.name ?? '',
    mobile: row.mobile ?? raw.mobile ?? '',
    city: row.city ?? raw.city ?? '',
  };
}

function employeeFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return {
    ...raw,
    id: row.id || raw.id || makeId('emp'),
    name: row.name ?? raw.name ?? '',
    mobile: row.mobile ?? raw.mobile ?? '',
    designation: row.designation ?? raw.designation ?? '',
    payPerDay: Number(row.pay_per_day ?? raw.payPerDay ?? 0) || 0,
    payPerHour: Number(row.pay_per_hour ?? raw.payPerHour ?? 0) || 0,
  };
}

function customMenuFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return {
    ...raw,
    id: row.id || raw.id || makeId('cmu'),
    name: row.name ?? raw.name ?? '',
    type: row.type ?? raw.type ?? '',
    itemIds: asArray(row.item_ids ?? raw.itemIds),
  };
}

function requirementListFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return materialDocumentFromBody({
    ...raw,
    id: row.id || raw.id || makeId('req'),
    type: row.type ?? raw.type ?? '',
    title: row.title ?? raw.title ?? '',
  });
}

function eventFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return normalizeEventShape({
    ...raw,
    id: row.id || raw.id || makeId('evt'),
    name: row.name ?? raw.name ?? '',
    primaryClient: row.primary_client ?? raw.primaryClient ?? '',
    mobile: row.mobile ?? raw.mobile ?? '',
    venue: row.venue ?? raw.venue ?? '',
    status: row.status ?? raw.status ?? '',
    notes: row.notes ?? raw.notes ?? '',
    addOns: asArray(row.add_ons ?? raw.addOns),
    dates: [],
    payments: [],
    employeeAssignments: [],
  });
}

function eventDateFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return normalizeEventDate({
    ...raw,
    id: row.id || raw.id || row.event_date || makeId('date'),
    date: row.event_date ?? raw.date ?? '',
    label: row.label ?? raw.label ?? '',
    additionalServices: asArray(row.additional_services ?? raw.additionalServices),
    menuSlots: [],
  });
}

function menuSlotFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return {
    ...raw,
    id: row.id || raw.id || makeId('slot'),
    type: row.type ?? raw.type ?? '',
    time: row.delivery_time ?? raw.time ?? '',
    pax: Number(row.pax ?? raw.pax ?? 0) || 0,
    pricePerPax: Number(row.price_per_pax ?? raw.pricePerPax ?? 0) || 0,
    enabled: row.enabled === null || row.enabled === undefined ? raw.enabled !== false : Boolean(row.enabled),
    menuItemIds: asArray(row.menu_item_ids ?? raw.menuItemIds),
    additionalServices: asArray(row.additional_services ?? raw.additionalServices),
  };
}

function paymentFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return {
    ...raw,
    id: row.id || raw.id || makeId('pay'),
    amount: Number(row.amount ?? raw.amount ?? 0) || 0,
    date: row.payment_date ?? raw.date ?? '',
    mode: row.mode ?? raw.mode ?? '',
    reference: row.reference ?? raw.reference ?? '',
    settled: row.settled === null || row.settled === undefined ? raw.settled === true : Boolean(row.settled),
  };
}

function assignmentFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return {
    ...raw,
    employeeId: row.employee_id || raw.employeeId || raw.id || '',
    name: row.name ?? raw.name ?? raw.employeeName ?? '',
    designation: row.designation ?? raw.designation ?? '',
    payPerDay: Number(row.pay_per_day ?? raw.payPerDay ?? 0) || 0,
    payPerHour: Number(row.pay_per_hour ?? raw.payPerHour ?? 0) || 0,
  };
}

function attendanceFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return {
    ...raw,
    eventId: row.event_id || raw.eventId || '',
    employeeId: row.employee_id || raw.employeeId || '',
    date: row.attendance_date ?? raw.date ?? '',
    status: row.status ?? raw.status ?? '',
    hours: Number(row.hours ?? raw.hours ?? 0) || 0,
    payPerDay: Number(row.pay_per_day ?? raw.payPerDay ?? 0) || 0,
    payPerHour: Number(row.pay_per_hour ?? raw.payPerHour ?? 0) || 0,
  };
}

function manualInvoiceFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return {
    ...raw,
    id: row.id || raw.id || makeId('inv'),
    invoiceNumber: row.invoice_number ?? raw.invoiceNumber ?? '',
    clientName: row.client_name ?? raw.clientName ?? '',
    mobile: row.mobile ?? raw.mobile ?? '',
    eventName: row.event_name ?? raw.eventName ?? '',
    eventDate: row.event_date ?? raw.eventDate ?? '',
    invoiceDate: row.invoice_date ?? raw.invoiceDate ?? '',
    total: Number(row.total ?? raw.total ?? 0) || 0,
    pending: Number(row.pending ?? raw.pending ?? 0) || 0,
    items: [],
  };
}

function manualInvoiceItemFromSupabaseRow(row = {}) {
  const raw = rawFromSupabaseRow(row);
  return {
    ...raw,
    id: row.id || raw.id || row.title || makeId('itm'),
    title: row.title ?? raw.title ?? '',
    quantity: Number(row.quantity ?? raw.quantity ?? 0) || 0,
    rate: Number(row.rate ?? raw.rate ?? 0) || 0,
    amount: Number(row.amount ?? raw.amount ?? 0) || 0,
  };
}

async function hydrateUserMenuItemsFromSupabase(db, userId) {
  db.userData[userId] = ensureUserDataShape(db.userData[userId] || emptyUserData());
  if (asArray(db.userData[userId].menuItems).length > 0 || !supabase) return false;
  try {
    const { data: rows } = await supabaseRequest(
      supabase
        .from('cp_user_menu_items')
        .select('id, english, kannada, title, category, meals, veg, raw')
        .eq('state_id', supabaseStateId)
        .eq('user_id', userId)
        .order('id'),
    );
    if (!rows || rows.length === 0) return false;
    db.userData[userId].menuItems = rows.map(userMenuItemFromSupabaseRow);
    return true;
  } catch (error) {
    console.warn('Supabase user menu recovery skipped:', error.message);
    return false;
  }
}

const supabaseTables = [
  'cp_manual_invoice_items',
  'cp_manual_invoices',
  'cp_requirement_lists',
  'cp_event_assignments',
  'cp_event_payments',
  'cp_menu_slots',
  'cp_event_dates',
  'cp_attendance',
  'cp_events',
  'cp_custom_menus',
  'cp_additional_services',
  'cp_user_menu_items',
  'cp_user_raw_materials',
  'cp_user_produce_items',
  'cp_user_vessel_items',
  'cp_employees',
  'cp_clients',
  'cp_business_profiles',
  'cp_users',
  'cp_menu_items',
  'cp_raw_materials',
  'cp_produce_items',
  'cp_vessel_items',
];

const supabaseTableConflicts = {
  cp_users: 'state_id,id',
  cp_business_profiles: 'state_id,user_id',
  cp_clients: 'state_id,user_id,id',
  cp_employees: 'state_id,user_id,id',
  cp_events: 'state_id,user_id,id',
  cp_event_dates: 'state_id,user_id,event_id,id',
  cp_menu_slots: 'state_id,user_id,event_id,date_id,id',
  cp_event_payments: 'state_id,user_id,event_id,id',
  cp_event_assignments: 'state_id,user_id,event_id,employee_id',
  cp_attendance: 'state_id,user_id,event_id,employee_id,attendance_date',
  cp_additional_services: 'state_id,user_id,id',
  cp_user_menu_items: 'state_id,user_id,id',
  cp_user_raw_materials: 'state_id,user_id,id',
  cp_user_produce_items: 'state_id,user_id,id',
  cp_user_vessel_items: 'state_id,user_id,id',
  cp_custom_menus: 'state_id,user_id,id',
  cp_requirement_lists: 'state_id,user_id,id',
  cp_manual_invoices: 'state_id,user_id,id',
  cp_manual_invoice_items: 'state_id,user_id,invoice_id,id',
  cp_menu_items: 'state_id,id',
  cp_raw_materials: 'state_id,id',
  cp_produce_items: 'state_id,id',
  cp_vessel_items: 'state_id,id',
};

const supabaseUniversalTables = new Set(['cp_menu_items', 'cp_raw_materials', 'cp_produce_items', 'cp_vessel_items']);

function emptySupabaseRows() {
  return Object.fromEntries(supabaseTables.map((table) => [table, []]));
}

async function loadSupabaseRows(table) {
  const pageSize = 1000;
  const rows = [];
  for (let from = 0; ; from += pageSize) {
    const { data } = await supabaseRequest(
      supabase
        .from(table)
        .select('*')
        .eq('state_id', supabaseStateId)
        .range(from, from + pageSize - 1),
    );
    rows.push(...asArray(data));
    if (!data || data.length < pageSize) break;
  }
  return rows;
}

async function loadSupabaseTableState() {
  const rows = emptySupabaseRows();
  for (const table of [...supabaseTables].reverse()) {
    try {
      rows[table] = await loadSupabaseRows(table);
    } catch (error) {
      throw new Error(`Unable to load ${table}: ${error.message}`);
    }
  }
  if (!rows.cp_users.length) return null;

  const db = { users: rows.cp_users.map(userFromSupabaseRow), userData: {}, universal: {} };
  const ensureLoadedUserData = (userId) => {
    db.userData[userId] = ensureUserDataShape(db.userData[userId] || emptyUserData());
    return db.userData[userId];
  };

  for (const user of db.users) ensureLoadedUserData(user.id);

  db.universal.menuItems = rows.cp_menu_items.map(userMenuItemFromSupabaseRow);
  db.universal.rawMaterials = rows.cp_raw_materials.map((row) => inventoryItemFromSupabaseRow(row, 'raw'));
  db.universal.produceItems = rows.cp_produce_items.map((row) => inventoryItemFromSupabaseRow(row, 'prd'));
  db.universal.vesselItems = rows.cp_vessel_items.map((row) => inventoryItemFromSupabaseRow(row, 'vsl'));

  for (const row of rows.cp_business_profiles) ensureLoadedUserData(row.user_id).businessProfile = businessProfileFromSupabaseRow(row);
  for (const row of rows.cp_clients) ensureLoadedUserData(row.user_id).clients.push(clientFromSupabaseRow(row));
  for (const row of rows.cp_employees) ensureLoadedUserData(row.user_id).employees.push(employeeFromSupabaseRow(row));
  for (const row of rows.cp_additional_services) ensureLoadedUserData(row.user_id).additionalServices.push(additionalServiceFromSupabaseRow(row));
  for (const row of rows.cp_user_menu_items) ensureLoadedUserData(row.user_id).menuItems.push(userMenuItemFromSupabaseRow(row));
  for (const row of rows.cp_user_raw_materials) ensureLoadedUserData(row.user_id).rawMaterials.push(inventoryItemFromSupabaseRow(row, 'raw'));
  for (const row of rows.cp_user_produce_items) ensureLoadedUserData(row.user_id).produceItems.push(inventoryItemFromSupabaseRow(row, 'prd'));
  for (const row of rows.cp_user_vessel_items) ensureLoadedUserData(row.user_id).vesselItems.push(inventoryItemFromSupabaseRow(row, 'vsl'));
  for (const row of rows.cp_custom_menus) ensureLoadedUserData(row.user_id).customMenus.push(customMenuFromSupabaseRow(row));
  for (const row of rows.cp_requirement_lists) ensureLoadedUserData(row.user_id).requirementLists.push(requirementListFromSupabaseRow(row));
  for (const row of rows.cp_attendance) ensureLoadedUserData(row.user_id).attendance.push(attendanceFromSupabaseRow(row));

  const eventMap = new Map();
  const dateMap = new Map();
  const eventKey = (userId, eventId) => `${userId}\n${eventId}`;
  const dateKey = (userId, eventId, dateId) => `${userId}\n${eventId}\n${dateId}`;

  for (const row of rows.cp_events) {
    const event = eventFromSupabaseRow(row);
    ensureLoadedUserData(row.user_id).events.push(event);
    eventMap.set(eventKey(row.user_id, row.id), event);
  }
  for (const row of rows.cp_event_dates) {
    const event = eventMap.get(eventKey(row.user_id, row.event_id));
    if (!event) continue;
    const date = eventDateFromSupabaseRow(row);
    event.dates.push(date);
    dateMap.set(dateKey(row.user_id, row.event_id, row.id), date);
  }
  for (const row of rows.cp_menu_slots) {
    const date = dateMap.get(dateKey(row.user_id, row.event_id, row.date_id));
    if (!date) continue;
    date.menuSlots.push(menuSlotFromSupabaseRow(row));
  }
  for (const row of rows.cp_event_payments) {
    const event = eventMap.get(eventKey(row.user_id, row.event_id));
    if (event) event.payments.push(paymentFromSupabaseRow(row));
  }
  for (const row of rows.cp_event_assignments) {
    const event = eventMap.get(eventKey(row.user_id, row.event_id));
    if (event) event.employeeAssignments.push(assignmentFromSupabaseRow(row));
  }

  const invoiceMap = new Map();
  const invoiceKey = (userId, invoiceId) => `${userId}\n${invoiceId}`;
  for (const row of rows.cp_manual_invoices) {
    const invoice = manualInvoiceFromSupabaseRow(row);
    ensureLoadedUserData(row.user_id).manualInvoices.push(invoice);
    invoiceMap.set(invoiceKey(row.user_id, row.id), invoice);
  }
  for (const row of rows.cp_manual_invoice_items) {
    const invoice = invoiceMap.get(invoiceKey(row.user_id, row.invoice_id));
    if (invoice) invoice.items.push(manualInvoiceItemFromSupabaseRow(row));
  }

  ensureUniversal(db);
  for (const user of db.users) {
    db.userData[user.id] = ensureUserDataShape(db.userData[user.id] || emptyUserData());
  }
  return db;
}

function buildSupabaseRows(db) {
  const rows = emptySupabaseRows();
  for (const user of asArray(db.users)) {
    const userId = user.id || '';
    rows.cp_users.push({ state_id: supabaseStateId, id: userId, name: user.name || '', email: user.email || '', role: user.role || '', raw: user });
    const userData = ensureUserDataShape(db.userData?.[userId] || emptyUserData());
    const profile = userData.businessProfile || emptyBusinessProfile();
    rows.cp_business_profiles.push({
      state_id: supabaseStateId,
      user_id: userId,
      business_name: profile.businessName || '',
      service_type: profile.serviceType || '',
      gstin: profile.gstin || '',
      gst_type: profile.gstType || '',
      gst_rate: Number(profile.gstRate || 0),
      ifsc: profile.ifsc || '',
      phone: profile.phone || '',
      email: profile.email || '',
      raw: profile,
    });
    for (const item of asArray(userData.clients)) {
      rows.cp_clients.push({ state_id: supabaseStateId, user_id: userId, id: item.id || '', name: item.name || '', mobile: item.mobile || '', city: item.city || item.address || '', raw: item });
    }
    for (const item of asArray(userData.employees)) {
      rows.cp_employees.push({ state_id: supabaseStateId, user_id: userId, id: item.id || '', name: item.name || '', mobile: item.mobile || '', designation: item.designation || '', pay_per_day: Number(item.payPerDay || 0), pay_per_hour: Number(item.payPerHour || 0), raw: item });
    }
    for (const item of asArray(userData.additionalServices)) {
      rows.cp_additional_services.push({ state_id: supabaseStateId, user_id: userId, id: item.id || '', name: item.name || '', unit: item.unit || '', price: Number(item.price || 0), raw: item });
    }
    for (const item of asArray(userData.menuItems)) {
      rows.cp_user_menu_items.push({ state_id: supabaseStateId, user_id: userId, id: item.id || '', english: item.english || '', kannada: item.kannada || '', title: item.title || '', category: item.category || '', meals: asArray(item.meals), veg: item.veg === true, raw: item });
    }
    for (const item of asArray(userData.rawMaterials)) {
      rows.cp_user_raw_materials.push({ state_id: supabaseStateId, user_id: userId, id: item.id || '', name: item.name || '', category: item.category || '', unit: item.unit || '', raw: item });
    }
    for (const item of asArray(userData.produceItems)) {
      rows.cp_user_produce_items.push({ state_id: supabaseStateId, user_id: userId, id: item.id || '', name: item.name || '', category: item.category || '', unit: item.unit || '', raw: item });
    }
    for (const item of asArray(userData.vesselItems)) {
      rows.cp_user_vessel_items.push({ state_id: supabaseStateId, user_id: userId, id: item.id || '', name: item.name || '', category: item.category || '', unit: item.unit || '', raw: item });
    }
    for (const item of asArray(userData.customMenus)) {
      rows.cp_custom_menus.push({ state_id: supabaseStateId, user_id: userId, id: item.id || '', name: item.name || '', type: item.type || '', item_ids: asArray(item.itemIds), raw: item });
    }
    for (const item of asArray(userData.requirementLists)) {
      rows.cp_requirement_lists.push({ state_id: supabaseStateId, user_id: userId, id: item.id || '', type: item.type || '', title: item.title || '', item_count: asArray(item.items).length, raw: item });
    }
    for (const event of asArray(userData.events)) {
      const eventId = event.id || '';
      rows.cp_events.push({ state_id: supabaseStateId, user_id: userId, id: eventId, name: event.name || '', primary_client: event.primaryClient || '', mobile: event.mobile || '', venue: event.venue || '', status: event.status || '', notes: event.notes || '', add_ons: asArray(event.addOns), raw: event });
      for (const date of asArray(event.dates)) {
        const dateId = date.id || date.date || '';
        rows.cp_event_dates.push({ state_id: supabaseStateId, user_id: userId, event_id: eventId, id: dateId, event_date: date.date || '', label: date.label || '', additional_services: asArray(date.additionalServices), raw: date });
        for (const slot of asArray(date.menuSlots)) {
          rows.cp_menu_slots.push({ state_id: supabaseStateId, user_id: userId, event_id: eventId, date_id: dateId, id: slot.id || `${slot.type || 'slot'}-${dateId}`, type: slot.type || '', delivery_time: slot.time || '', pax: Number(slot.pax || 0), price_per_pax: Number(slot.pricePerPax || 0), enabled: slot.enabled !== false, menu_item_ids: asArray(slot.menuItemIds), additional_services: asArray(slot.additionalServices), raw: slot });
        }
      }
      for (const payment of asArray(event.payments)) {
        rows.cp_event_payments.push({ state_id: supabaseStateId, user_id: userId, event_id: eventId, id: payment.id || '', amount: Number(payment.amount || 0), payment_date: payment.date || '', mode: payment.mode || '', reference: payment.reference || '', settled: payment.settled === true, raw: payment });
      }
      for (const assignment of asArray(event.employeeAssignments)) {
        rows.cp_event_assignments.push({ state_id: supabaseStateId, user_id: userId, event_id: eventId, employee_id: assignment.employeeId || assignment.id || '', name: assignment.name || assignment.employeeName || '', designation: assignment.designation || '', pay_per_day: Number(assignment.payPerDay || 0), pay_per_hour: Number(assignment.payPerHour || 0), raw: assignment });
      }
    }
    for (const item of asArray(userData.attendance)) {
      rows.cp_attendance.push({ state_id: supabaseStateId, user_id: userId, event_id: item.eventId || '', employee_id: item.employeeId || '', attendance_date: item.date || '', status: item.status || '', hours: Number(item.hours || 0), pay_per_day: Number(item.payPerDay || 0), pay_per_hour: Number(item.payPerHour || 0), raw: item });
    }
    for (const invoice of asArray(userData.manualInvoices)) {
      const invoiceId = invoice.id || '';
      rows.cp_manual_invoices.push({ state_id: supabaseStateId, user_id: userId, id: invoiceId, invoice_number: invoice.invoiceNumber || '', client_name: invoice.clientName || '', mobile: invoice.mobile || '', event_name: invoice.eventName || '', event_date: invoice.eventDate || '', invoice_date: invoice.invoiceDate || '', total: Number(invoice.total || 0), pending: Number(invoice.pending || 0), raw: invoice });
      for (const item of asArray(invoice.items)) {
        rows.cp_manual_invoice_items.push({ state_id: supabaseStateId, user_id: userId, invoice_id: invoiceId, id: item.id || item.title || '', title: item.title || '', quantity: Number(item.quantity || 0), rate: Number(item.rate || 0), amount: Number(item.amount || 0), raw: item });
      }
    }
  }
  for (const item of asArray(db.universal?.menuItems)) {
    rows.cp_menu_items.push({ state_id: supabaseStateId, id: item.id || '', english: item.english || '', kannada: item.kannada || '', title: item.title || '', category: item.category || '', meals: asArray(item.meals), veg: item.veg === true, raw: item });
  }
  for (const item of asArray(db.universal?.rawMaterials)) {
    rows.cp_raw_materials.push({ state_id: supabaseStateId, id: item.id || '', name: item.name || '', category: item.category || '', unit: item.unit || '', raw: item });
  }
  for (const item of asArray(db.universal?.produceItems)) {
    rows.cp_produce_items.push({ state_id: supabaseStateId, id: item.id || '', name: item.name || '', category: item.category || '', unit: item.unit || '', raw: item });
  }
  for (const item of asArray(db.universal?.vesselItems)) {
    rows.cp_vessel_items.push({ state_id: supabaseStateId, id: item.id || '', name: item.name || '', category: item.category || '', unit: item.unit || '', raw: item });
  }
  return rows;
}

async function upsertSupabaseRows(table, rows) {
  if (rows.length === 0) return;
  for (let index = 0; index < rows.length; index += 500) {
    await supabaseRequest(
      supabase.from(table).upsert(rows.slice(index, index + 500), { onConflict: supabaseTableConflicts[table] }),
    );
  }
}

function isMissingSupabaseTableError(error) {
  const message = String(error?.message || '');
  return error?.code === 'PGRST205' || message.includes('Could not find the table');
}

async function syncSupabaseTables(db) {
  if (!supabase) return { status: 'disabled', tables: {} };
  const rowsByTable = buildSupabaseRows(db);
  const skippedTables = [];
  const failedTables = [];
  const tableStatus = {};
  for (const table of supabaseTables) {
    try {
      await supabaseRequest(supabase.from(table).delete().eq('state_id', supabaseStateId));
    } catch (error) {
      if (isMissingSupabaseTableError(error)) {
        skippedTables.push(table);
        tableStatus[table] = { status: 'skipped', rows: rowsByTable[table].length, error: error.message };
        continue;
      }
      failedTables.push(table);
      tableStatus[table] = { status: 'failed', rows: rowsByTable[table].length, error: error.message };
    }
  }
  for (const table of [...supabaseTables].reverse()) {
    if (skippedTables.includes(table) || failedTables.includes(table)) continue;
    try {
      await upsertSupabaseRows(table, rowsByTable[table]);
      tableStatus[table] = { status: 'synced', rows: rowsByTable[table].length };
    } catch (error) {
      failedTables.push(table);
      tableStatus[table] = { status: 'failed', rows: rowsByTable[table].length, error: error.message };
    }
  }
  if (skippedTables.length) {
    console.warn(`Supabase reporting tables not found and skipped: ${skippedTables.join(', ')}`);
  }
  if (failedTables.length) {
    console.warn(`Supabase reporting tables failed: ${failedTables.join(', ')}`);
  }
  const totalRows = Object.values(rowsByTable).reduce((sum, rows) => sum + rows.length, 0);
  return {
    status: failedTables.length ? 'partial' : skippedTables.length ? 'partial' : 'synced',
    stateId: supabaseStateId,
    totalRows,
    skippedTables,
    failedTables,
    tables: tableStatus,
  };
}

async function upsertSupabaseTableState(db) {
  if (!supabase) return { status: 'disabled', tables: {} };
  const rowsByTable = buildSupabaseRows(db);
  const skippedTables = [];
  const failedTables = [];
  const tableStatus = {};
  for (const table of [...supabaseTables].reverse()) {
    try {
      await upsertSupabaseRows(table, rowsByTable[table]);
      tableStatus[table] = { status: 'upserted', rows: rowsByTable[table].length };
    } catch (error) {
      if (isMissingSupabaseTableError(error)) {
        skippedTables.push(table);
        tableStatus[table] = { status: 'skipped', rows: rowsByTable[table].length, error: error.message };
        continue;
      }
      failedTables.push(table);
      tableStatus[table] = { status: 'failed', rows: rowsByTable[table].length, error: error.message };
    }
  }
  if (skippedTables.length) {
    console.warn(`Supabase state tables not found and skipped: ${skippedTables.join(', ')}`);
  }
  if (failedTables.length) {
    console.warn(`Supabase state tables failed: ${failedTables.join(', ')}`);
  }
  const totalRows = Object.values(rowsByTable).reduce((sum, rows) => sum + rows.length, 0);
  return {
    status: failedTables.length || skippedTables.length ? 'partial' : 'synced',
    mode: 'table-upsert',
    stateId: supabaseStateId,
    totalRows,
    skippedTables,
    failedTables,
    tables: tableStatus,
  };
}

async function replaceSupabaseUserTableState(db, userId, { includeUniversal = false } = {}) {
  if (!supabase) return { status: 'disabled', tables: {} };
  const rowsByTable = buildSupabaseRows(db);
  const tableStatus = {};
  const skippedTables = [];
  const failedTables = [];
  const userTables = supabaseTables.filter((table) => (
    table !== 'cp_users' && !supabaseUniversalTables.has(table)
  ));

  for (const table of userTables) {
    try {
      await supabaseRequest(
        supabase
          .from(table)
          .delete()
          .eq('state_id', supabaseStateId)
          .eq('user_id', userId),
      );
    } catch (error) {
      if (isMissingSupabaseTableError(error)) {
        skippedTables.push(table);
        tableStatus[table] = { status: 'skipped', rows: 0, error: error.message };
        continue;
      }
      failedTables.push(table);
      tableStatus[table] = { status: 'failed', rows: 0, error: error.message };
    }
  }

  const tablesToUpsert = [...supabaseTables].reverse().filter((table) => {
    if (table === 'cp_users') return true;
    if (supabaseUniversalTables.has(table)) return includeUniversal;
    return userTables.includes(table);
  });

  for (const table of tablesToUpsert) {
    if (skippedTables.includes(table) || failedTables.includes(table)) continue;
    const rows = rowsByTable[table].filter((row) => {
      if (table === 'cp_users') return row.id === userId;
      if (supabaseUniversalTables.has(table)) return includeUniversal;
      return row.user_id === userId;
    });
    try {
      await upsertSupabaseRows(table, rows);
      tableStatus[table] = { status: tableStatus[table]?.status || 'synced', rows: rows.length };
    } catch (error) {
      if (isMissingSupabaseTableError(error)) {
        skippedTables.push(table);
        tableStatus[table] = { status: 'skipped', rows: rows.length, error: error.message };
        continue;
      }
      failedTables.push(table);
      tableStatus[table] = { status: 'failed', rows: rows.length, error: error.message };
    }
  }

  const totalRows = Object.values(tableStatus).reduce((sum, status) => sum + Number(status.rows || 0), 0);
  return {
    status: failedTables.length || skippedTables.length ? 'partial' : 'synced',
    mode: 'user-table-replace',
    stateId: supabaseStateId,
    userId,
    includeUniversal,
    totalRows,
    skippedTables,
    failedTables,
    tables: tableStatus,
  };
}

function scheduleSupabaseSave(db, options = {}) {
  if (!supabase) return;
  const snapshot = JSON.parse(JSON.stringify(db));
  const saveOptions = { ...options, syncMirrorTables: false };
  pendingSupabaseWrite = pendingSupabaseWrite
    .catch(() => {})
    .then(() => saveSupabaseDb(snapshot, saveOptions))
    .catch((error) => console.error('Supabase sync failed:', error.message));
}

async function flushSupabaseWrites() {
  await pendingSupabaseWrite.catch(() => {});
}

async function initializeStorage() {
  requireSupabaseConfigured();
  const supabaseDb = await loadSupabaseDb();
  if (supabaseDb) {
    runtimeDb = ensureAdminUser(supabaseDb);
    console.log(`CaterPro storage: loaded Supabase tables for state "${supabaseStateId}"`);
    return;
  }
  throw new Error(`No Supabase table data found for "${supabaseStateId}". Create cp_users and related table rows before starting the API.`);
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
  ensureUniversal(db);
  db.userData[user.id] = ensureUserDataShape(db.userData[user.id] || emptyUserData());
  ensureUserCatalogs(db, user.id);
  return user;
}

function requireAdminUser(req, res, db) {
  const user = requireUser(req, res, db);
  if (!user) return null;
  if (String(user.email || '').toLowerCase() !== 'admin@caterpro.in') {
    res.status(403).json({ message: 'Admin access required' });
    return null;
  }
  return user;
}

function ensureAdminUser(db) {
  const adminEmail = String(process.env.ADMIN_EMAIL || 'admin@caterpro.in').trim().toLowerCase();
  const adminPassword = String(process.env.ADMIN_PASSWORD || 'password');
  if (!adminEmail.includes('@')) return db;
  db.users = asArray(db.users);
  db.userData = db.userData || {};
  const existing = asArray(db.users).find((user) => String(user.email || '').toLowerCase() === adminEmail);
  if (existing) {
    existing.role = existing.role || 'admin';
    db.userData[existing.id] = db.userData[existing.id] || emptyUserData();
    return db;
  }
  const admin = {
    id: 'admin',
    name: 'CaterPro Admin',
    email: adminEmail,
    password: adminPassword,
    role: 'admin',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  db.users.push(admin);
  db.userData[admin.id] = emptyUserData();
  return db;
}

function emptyUserData() {
  return { events: [], clients: [], employees: [], attendance: [], additionalServices: [], menuItems: [], rawMaterials: [], produceItems: [], vesselItems: [], customMenus: [], requirementLists: [], payments: [], manualInvoices: [], auditLogs: [], businessProfile: emptyBusinessProfile() };
}

function emptyBusinessProfile() {
  return { businessName: '', serviceType: '', gstin: '', gstType: 'cgst_sgst', gstRate: 5, pan: '', address: '', city: '', phone: '', email: '', accountHolderName: '', bankName: '', branchName: '', accountNumber: '', ifsc: '', terms: '', logoBase64: '', signatureBase64: '', qrBase64: '', documentTemplate: 'boxed', invoiceTextScale: 1, pdfMenuFontSize: 12 };
}

const invoiceDocumentTemplates = [
  { id: 'boxed', label: 'Boxed Blue', default: true },
  { id: 'classic', label: 'Classic' },
  { id: 'elegant', label: 'Elegant' },
  { id: 'modern', label: 'Modern' },
];

function isOnlyDefaultEmployeeSeed(employees = [], userData = {}) {
  const defaultIds = new Set(['emp_default_001', 'emp_default_002', 'emp_default_003', 'emp_default_004']);
  const list = asArray(employees);
  if (list.length !== defaultIds.size) return false;
  const hasOnlyDefaults = list.every((employee) => defaultIds.has(String(employee.id || '')));
  if (!hasOnlyDefaults) return false;
  return asArray(userData.events).length === 0 && asArray(userData.attendance).length === 0;
}

function ensureUserDataShape(userData) {
  userData.events = userData.events || [];
  userData.clients = userData.clients || [];
  userData.employees = userData.employees || [];
  if (isOnlyDefaultEmployeeSeed(userData.employees, userData)) userData.employees = [];
  userData.employees = userData.employees.map((employee) => ({ ...employee, payPerHour: Number(employee.payPerHour ?? (employee.payPerDay ? Math.round(Number(employee.payPerDay) / 8) : 0)) }));
  userData.events = userData.events.map((event) => normalizeEventShape({ employeeAssignments: [], ...event }));
  userData.attendance = userData.attendance || [];
  userData.attendance = userData.attendance.map((record) => ({ ...record, payPerHour: Number(record.payPerHour ?? (record.payPerDay ? Math.round(Number(record.payPerDay) / 8) : 0)) }));
  userData.attendance = dedupeBy(userData.attendance, (record) => [record.eventId, record.employeeId, record.date].join('|'));
  userData.additionalServices = userData.additionalServices || [];
  userData.menuItems = Array.isArray(userData.menuItems) ? userData.menuItems : [];
  userData.rawMaterials = Array.isArray(userData.rawMaterials) ? normalizeRawMaterialUnits(userData.rawMaterials) : [];
  userData.produceItems = Array.isArray(userData.produceItems) ? userData.produceItems : [];
  userData.vesselItems = Array.isArray(userData.vesselItems) ? userData.vesselItems : [];
  userData.customMenus = userData.customMenus || [];
  userData.requirementLists = asArray(userData.requirementLists).map((item) => materialDocumentFromBody(item));
  userData.payments = userData.payments || [];
  userData.manualInvoices = userData.manualInvoices || [];
  userData.auditLogs = asArray(userData.auditLogs);
  userData.businessProfile = { ...emptyBusinessProfile(), ...(userData.businessProfile || {}) };
  return userData;
}

function cloneCatalog(items = []) {
  return asArray(items).map((item) => ({ ...item }));
}

function ensureUserCatalogs(db, userId) {
  ensureUniversal(db);
  db.userData[userId] = ensureUserDataShape(db.userData[userId] || emptyUserData());
  const userData = db.userData[userId];
  if (!Array.isArray(userData.menuItems) || userData.menuItems.length === 0) {
    userData.menuItems = cloneCatalog(db.universal.menuItems);
  }
  if (!Array.isArray(userData.rawMaterials) || userData.rawMaterials.length === 0) {
    userData.rawMaterials = cloneCatalog(db.universal.rawMaterials);
  }
  if (!Array.isArray(userData.produceItems) || userData.produceItems.length === 0) {
    userData.produceItems = cloneCatalog(db.universal.produceItems);
  }
  if (!Array.isArray(userData.vesselItems) || userData.vesselItems.length === 0) {
    userData.vesselItems = cloneCatalog(db.universal.vesselItems);
  }
  userData.rawMaterials = normalizeRawMaterialUnits(userData.rawMaterials);
  return userData;
}

function dedupeBy(items = [], keyForItem) {
  const byKey = new Map();
  for (const item of asArray(items)) {
    byKey.set(keyForItem(item), item);
  }
  return [...byKey.values()];
}

function normalizeEventShape(event = {}) {
  const normalized = {
    ...event,
    dates: asArray(event.dates),
    payments: asArray(event.payments),
    materialDocuments: asArray(event.materialDocuments),
    employeeAssignments: asArray(event.employeeAssignments).map((assignment) => ({
      ...assignment,
      payPerHour: Number(assignment.payPerHour ?? (assignment.payPerDay ? Math.round(Number(assignment.payPerDay) / 8) : 0)),
    })),
  };
  normalized.dates = mergeEventDates(normalized.dates);
  normalized.attendance = dedupeBy(asArray(normalized.attendance), (record) => [record.eventId, record.employeeId, record.date].join('|'));
  return normalized;
}

function normalizeEventDate(date = {}) {
  return {
    ...date,
    id: date.date || date.id || makeId('date'),
    menuSlots: dedupeBy(asArray(date.menuSlots), (slot) => slot.id || slot.type || `${date.date || date.id}-slot`),
    additionalServices: dedupeBy(asArray(date.additionalServices), (service) => [service.serviceId || service.id || service.name, service.count || service.quantity || ''].join('|')),
  };
}

function mergeEventDates(dates = []) {
  const byDate = new Map();
  for (const rawDate of asArray(dates)) {
    const date = normalizeEventDate(rawDate);
    const key = date.date || date.id;
    const existing = byDate.get(key);
    if (!existing) {
      byDate.set(key, date);
      continue;
    }
    byDate.set(key, {
      ...existing,
      ...date,
      id: existing.date || existing.id || date.id,
      menuSlots: dedupeBy([...asArray(existing.menuSlots), ...asArray(date.menuSlots)], (slot) => slot.id || slot.type || `${key}-slot`),
      additionalServices: dedupeBy([...asArray(existing.additionalServices), ...asArray(date.additionalServices)], (service) => [service.serviceId || service.id || service.name, service.count || service.quantity || ''].join('|')),
    });
  }
  return [...byDate.values()];
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

const defaultVesselItems = [
  ['ದೊಡ್ಡ ಚಟ್ಟಿ', 'ಪಾತ್ರೆಗಳು'],
  ['ನೀರು ಚಟ್ಟಿ', 'ಪಾತ್ರೆಗಳು'],
  ['ಕೊಳಿಗೆ', 'ಪಾತ್ರೆಗಳು'],
  ['ಎಂ.ಟಿ. ಪಾತ್ರೆ 40 ಕೆ.ಜಿ.', 'ಪಾತ್ರೆಗಳು'],
  ['ಎಂ.ಟಿ. ಪಾತ್ರೆ 25 ಕೆ.ಜಿ.', 'ಪಾತ್ರೆಗಳು'],
  ['ಪಾತ್ರೆ 15 ಕೆ.ಜಿ.', 'ಪಾತ್ರೆಗಳು'],
  ['ಸಣ್ಣ ಪಾತ್ರೆ ಸೆಟ್', 'ಪಾತ್ರೆಗಳು'],
  ['ಕಾಶಿ ಫಿಲ್ಟರ್', 'ಪಾನೀಯ'],
  ['ಕಾಶಿ ಜಗ್', 'ಪಾನೀಯ'],
  ['ಎಲ್.ಪಿ. ಟೆಕ್ಕೆ', 'ಸೇವೆ'],
  ['ನಂ. 2 ಟೆಕ್ಕೆ', 'ಸೇವೆ'],
  ['ನಂ. 1 ಟೆಕ್ಕೆ', 'ಸೇವೆ'],
  ['ಇಡ್ಲಿ ಪಾತ್ರೆ ಟೆಕ್ಕೆ', 'ಪಾತ್ರೆಗಳು'],
  ['ಡಬ್ಬಿ', 'ಸಂಗ್ರಹ'],
  ['ಮೈಸೂರು ಪಾಕ್ ಟ್ರೇ', 'ಟ್ರೇ'],
  ['ಮೈಸೂರು ಪಾಕ್ ರೂಲ್', 'ಟ್ರೇ'],
  ['ಪರಾಂತ', 'ಪಾತ್ರೆಗಳು'],
  ['ಕಟ್ಲರ್', 'ಸೇವೆ'],
  ['ಕೈ ತಟ್ಟೆ', 'ಸೇವೆ'],
  ['ಸ್ಟೀಲ್ ಚಟರ್', 'ಸೇವೆ'],
  ['ಸ್ಟೀಲ್ ಸೋಸರ್', 'ಸೇವೆ'],
  ['ಅನ್ನದ ಕೈ', 'ಸೇವೆ'],
  ['ಸ್ಟೀಲ್ ಬಂಡಕೆ', 'ಪಾತ್ರೆಗಳು'],
  ['ಸ್ಟೀಲ್ ಸೌಟು', 'ಸೇವೆ'],
  ['ಚಾಕು ಸೌಟು', 'ಸೇವೆ'],
  ['ಲೋಟ', 'ಪಾನೀಯ'],
  ['ಸ್ಟೀಲ್ ಜಗ್', 'ಪಾನೀಯ'],
  ['ಸ್ಟೀಲ್ ಬೇಸನ್', 'ಪಾತ್ರೆಗಳು'],
  ['ತಟ್ಟೆ ಮಗ್', 'ಸೇವೆ'],
  ['ಗೋಧಿ ಮೇಳೆ', 'ಪಾತ್ರೆಗಳು'],
  ['ಚಟ್ಟಿ ಕೊಳ್ಳಿಗೆ ಮಣೆ', 'ಮಣೆ'],
  ['ತೆಂಗಿನ ಮಣೆ', 'ಮಣೆ'],
  ['ಚಪಾತಿ ಮಣೆ', 'ಮಣೆ'],
  ['ಲಗ್ನಿಗೆ', 'ಪಾತ್ರೆಗಳು'],
  ['ಎಣ್ಣೆ ಬಾಂದಿ ದೊಡ್ಡದು', 'ಪಾತ್ರೆಗಳು'],
  ['ಎಣ್ಣೆ ಬಾಂದಿ ಚಿಕ್ಕದು', 'ಪಾತ್ರೆಗಳು'],
  ['ಜಲ್ಲಿ ಬಾಂದಿ', 'ಪಾತ್ರೆಗಳು'],
  ['ಹೊಳಿಗೆ ಚಟ್ಟಿ ಕಂಬಿ', 'ಪಾತ್ರೆಗಳು'],
  ['ಸಕ್ಕರೆ ಕರಂಡಿ', 'ಸೇವೆ'],
  ['ಮಿಕ್ಸಿ', 'ಉಪಕರಣ'],
  ['ಪೀಠದ ಜಾರ್', 'ಉಪಕರಣ'],
  ['ಎಣ್ಣೆ ಜಾರ್', 'ಸಂಗ್ರಹ'],
  ['ಲಾಡು ಜಾರ್', 'ಸಂಗ್ರಹ'],
  ['ಸಾರ ಸೇವೆ ಮಣೆ', 'ಮಣೆ'],
  ['ಕೈ ಬಂಡಿ', 'ಸಾಗಣೆ'],
  ['ಮೂಲ ಬಡಿಗೆ', 'ಸೇವೆ'],
  ['ಹಿಡಿದು ಸಾಗಿಸುವುದು', 'ಸಾಗಣೆ'],
  ['ಫ್ಲಾಸ್ಕ್ ನೀರಿನ ಡ್ರಂ', 'ಪಾನೀಯ'],
  ['ಸ್ಟೀಲ್ ನೀರಿನ ಡ್ರಂ', 'ಪಾನೀಯ'],
  ['ಫೈಬರ್ ಡ್ರಂ', 'ಸಂಗ್ರಹ'],
  ['ಸ್ಟೀಲ್ ಡಬ್ಬ', 'ಸಂಗ್ರಹ'],
  ['ಗ್ರೈಂಡರ್', 'ಉಪಕರಣ'],
  ['ಮಿಕ್ಸಿ ಮತ್ತು ಜಾರ್', 'ಉಪಕರಣ'],
  ['ಗ್ಯಾಸ್ ಸಿಲಿಂಡರ್', 'ಉಪಕರಣ'],
  ['ಬಟ್ಟಿ', 'ಉಪಕರಣ'],
  ['ಸೊಳ್ಳೆ ಪರದೆ', 'ಇತರೆ'],
  ['ಎಲೆ ತೆಗೆಯುವ ಟೇಬಲ್', 'ಸೇವೆ'],
  ['ಜನರೇಟರ್ ಬ್ಯಾಟರಿ', 'ಉಪಕರಣ'],
  ['ಅಡ್ಡೆ ಸೆಟ್', 'ಸೇವೆ'],
  ['ಸ್ಟೀಲ್ ದೊಡ್ಡಾಳು', 'ಪಾತ್ರೆಗಳು'],
];

const correctedDefaultVesselItems = [
  ['ಡಬ್ಬಲ್ ಒಲೆ', 'ಒಲೆ'],
  ['ಸಿಂಗಲ್ ಒಲೆ', 'ಒಲೆ'],
  ['ಕೊಳಿಗೆ', 'ಪಾತ್ರೆಗಳು'],
  ['ಎಂ.ಟಿ. ಪಾತ್ರೆ 40 kg', 'ಪಾತ್ರೆಗಳು'],
  ['ಎಂ.ಟಿ. ಪಾತ್ರೆ 25 kg', 'ಪಾತ್ರೆಗಳು'],
  ['ಪಾತ್ರೆ 15 kg', 'ಪಾತ್ರೆಗಳು'],
  ['ಸಣ್ಣ ಪಾತ್ರೆ ಸೆಟ್', 'ಪಾತ್ರೆಗಳು'],
  ['ಕಾಫಿ ಫಿಲ್ಟರ್', 'ಪಾನೀಯ'],
  ['ಕಾಫಿ ಫ್ಲಾಸ್ಕ್', 'ಪಾನೀಯ'],
  ['ಎಸ್. ಪಿ. ತಟ್ಟೆ', 'ತಟ್ಟೆ'],
  ['ನಂ. 2 ತಟ್ಟೆ', 'ತಟ್ಟೆ'],
  ['ನಂ. 1 ತಟ್ಟೆ', 'ತಟ್ಟೆ'],
  ['ಇಡ್ಲಿ ಪಾತ್ರೆ ತಟ್ಟೆ', 'ತಟ್ಟೆ'],
  ['ಟಬ್ಬು', 'ಸಂಗ್ರಹ'],
  ['ಮೈಸೂರ್ ಪಾಕ್ ಟ್ರೇ', 'ಟ್ರೇ'],
  ['ಮೈಸೂರು ಪಾಕ್ ಕುರ್ಪಿ', 'ಟ್ರೇ'],
  ['ಪರಾತ', 'ಪಾತ್ರೆಗಳು'],
  ['ಕೆಟಲ್', 'ಪಾನೀಯ'],
  ['ಕೈ ಪಾತ್ರೆ', 'ಪಾತ್ರೆಗಳು'],
  ['ಸ್ಟೀಲ್ ಬಕೆಟ್', 'ಸಂಗ್ರಹ'],
  ['ಸ್ಟೀಲ್ ಸೌಟ್', 'ಸೇವೆ'],
  ['ಅನ್ನದ ಕೈ', 'ಸೇವೆ'],
  ['ಸ್ಟೀಲ್ ಚುಂಚಕ', 'ಸೇವೆ'],
  ['ಸ್ಟೀಲ್ ಸ್ಪೂನ್', 'ಸೇವೆ'],
  ['ಬಾತ್ ಸ್ಪೂನ್', 'ಸೇವೆ'],
  ['ಲೋಟ', 'ಪಾನೀಯ'],
  ['ಸ್ಟೀಲ್ ಜಗ್', 'ಪಾನೀಯ'],
  ['ಸ್ಟೀಲ್ ಬೇಸನ್', 'ಪಾತ್ರೆಗಳು'],
  ['ತುಪ್ಪದ ಮಗ್ಗು', 'ಸೇವೆ'],
  ['ಈಳಿಗೆಮಣಿ', 'ಮಣೆ'],
  ['ಒಣ ಕೊಬ್ಬರಿ ಮಣಿ', 'ಮಣೆ'],
  ['ತರಕಾರಿ ಮಣಿ', 'ಮಣೆ'],
  ['ಚಪಾತಿ ಮಣೆ', 'ಮಣೆ'],
  ['ಲಟ್ಟನಿಗೆ', 'ಸೇವೆ'],
  ['ಎಣ್ಣೆ ಬಾಂಡ್ಲಿ ದೊಡ್ಡದು', 'ಬಾಂಡ್ಲಿ'],
  ['ಎಣ್ಣೆ ಬಾಂಡ್ಲಿ ಚಿಕ್ಕದು', 'ಬಾಂಡ್ಲಿ'],
  ['ಜಿಲೇಬಿ ಬಾಂಡ್ಲಿ', 'ಬಾಂಡ್ಲಿ'],
  ['ಹೋಳಿಗೆ ಒಲೆ, ಹಂಚು', 'ಒಲೆ'],
  ['ಸಕ್ಕರೆ ಕಡಾಯಿ', 'ಪಾತ್ರೆಗಳು'],
  ['ಹುಟ್ಟು', 'ಸೇವೆ'],
  ['ಬೊಂದಿ ಜಾರ', 'ಜಾರ್'],
  ['ಎಣೆ ಜಾರ', 'ಜಾರ್'],
  ['ಲಾಡು ಜಾರ', 'ಜಾರ್'],
  ['ಖಾರ ಸೇವ್ ಮಣಿ', 'ಮಣೆ'],
  ['ಕೈ ಜಾರ', 'ಜಾರ್'],
  ['ಹುಳಿ ಜರಡಿ', 'ಜರಡಿ'],
  ['ಹಿಟ್ಟು ಸಾಣಿಸುವುದು', 'ಜರಡಿ'],
  ['ಪ್ಲಾಸ್ಟಿಕ್ ನೀರಿನ ಡಂ', 'ಡ್ರಂ'],
  ['ಸ್ಟೀಲ್ ನೀರಿನ ಡ್ರಂ', 'ಡ್ರಂ'],
  ['ಫೈಬರ್ ಪ್ಲೇಟ್', 'ಪ್ಲೇಟ್'],
  ['ಸ್ಟೀಲ್ ಪ್ಲೇಟ್', 'ಪ್ಲೇಟ್'],
  ['ಗ್ರೈಂಡರ್', 'ಉಪಕರಣ'],
  ['ಮಿಕ್ಸಿ ಮತ್ತು ಜಾರ', 'ಉಪಕರಣ'],
  ['ಟೀ ಸೊಸುವುದು', 'ಜರಡಿ'],
  ['ಬುಟ್ಟಿ', 'ಸಂಗ್ರಹ'],
  ['ಸೊಳ್ಳೆ ಪರದೆ', 'ಇತರೆ'],
  ['ಎಲೆ ತೆಗೆಯುವ ಬೇಸನ್', 'ಪಾತ್ರೆಗಳು'],
  ['ಜೆನ್‌ಕ್ಷನ್ ಬಾಕ್ಸ್', 'ಉಪಕರಣ'],
  ['ಅಳತೆ ಸೇರು', 'ಸೇವೆ'],
  ['ಸ್ಟೀಲ್ ಡಬ್ಬಿಗಳು', 'ಸಂಗ್ರಹ'],
];

function defaultVesselCatalog() {
  return correctedDefaultVesselItems.map(([name, category], index) => ({
    id: `VES-${String(index + 1).padStart(3, '0')}`,
    name,
    category,
    unit: '',
  }));
}

const protectedUniversalCatalogKeys = ['menuItems', 'rawMaterials', 'produceItems', 'vesselItems'];

function mergeCatalogById(existing = [], incoming = []) {
  const merged = new Map();
  for (const item of Array.isArray(existing) ? existing : []) {
    if (item && typeof item === 'object') merged.set(item.id || JSON.stringify(item), item);
  }
  for (const item of Array.isArray(incoming) ? incoming : []) {
    if (!item || typeof item !== 'object') continue;
    const key = item.id || JSON.stringify(item);
    merged.set(key, { ...(merged.get(key) || {}), ...item });
  }
  return [...merged.values()];
}

function mergeProtectedUniversalCatalog(existing = {}, incoming = {}) {
  const merged = { ...existing, ...(incoming || {}) };
  for (const key of protectedUniversalCatalogKeys) {
    const currentList = Array.isArray(existing[key]) ? existing[key] : [];
    const incomingList = Array.isArray(incoming?.[key]) ? incoming[key] : [];
    merged[key] = incomingList.length > 0 ? mergeCatalogById(currentList, incomingList) : currentList;
  }
  return merged;
}

const rawMaterialUnitById = {
  'RAW-001': 'g',
  'RAW-002': 'g',
  'RAW-003': 'kg',
  'RAW-004': 'kg',
  'RAW-005': 'g',
  'RAW-006': 'kg',
  'RAW-007': 'kg',
  'RAW-008': 'kg',
  'RAW-009': 'kg',
  'RAW-010': 'kg',
  'RAW-011': 'kg',
  'RAW-012': 'kg',
  'RAW-013': 'kg',
  'RAW-014': 'kg',
  'RAW-015': 'kg',
  'RAW-016': 'kg',
  'RAW-017': 'kg',
  'RAW-018': 'kg',
  'RAW-019': 'g',
  'RAW-020': 'g',
  'RAW-021': 'g',
  'RAW-022': 'g',
  'RAW-023': 'g',
  'RAW-024': 'g',
  'RAW-025': 'g',
  'RAW-026': 'piece',
  'RAW-027': 'g',
  'RAW-028': 'g',
  'RAW-029': 'pack',
  'RAW-030': 'g',
  'RAW-031': 'kg',
  'RAW-032': 'kg',
  'RAW-033': 'kg',
  'RAW-034': 'kg',
  'RAW-035': 'kg',
  'RAW-036': 'kg',
  'RAW-037': 'kg',
  'RAW-038': 'kg',
  'RAW-039': 'kg',
  'RAW-040': 'kg',
  'RAW-041': 'kg',
  'RAW-042': 'g',
  'RAW-043': 'tin',
  'RAW-044': 'kg',
  'RAW-045': 'kg',
  'RAW-046': 'kg',
  'RAW-047': 'kg',
  'RAW-048': 'kg',
  'RAW-049': 'kg',
  'RAW-050': 'g',
  'RAW-051': 'g',
  'RAW-052': 'g',
  'RAW-053': 'g',
  'RAW-054': 'g',
  'RAW-055': 'pack',
  'RAW-056': 'pack',
  'RAW-057': 'pack',
  'RAW-058': 'pack',
  'RAW-059': 'pack',
  'RAW-060': 'kg',
  'RAW-061': 'kg',
  'RAW-062': 'kg',
  'RAW-063': 'g',
  'RAW-064': 'g',
  'RAW-065': 'g',
  'RAW-066': 'g',
  'RAW-067': 'bottle',
  'RAW-068': 'kg',
  'RAW-069': 'pack',
  'RAW-070': 'kg',
  'RAW-071': 'litre',
  'RAW-072': 'litre',
  'RAW-073': 'litre',
  'RAW-074': 'kg',
  'RAW-075': 'pack',
  'RAW-076': 'kg',
  'RAW-077': 'g',
  'RAW-078': 'kg',
  'RAW-079': 'kg',
  'RAW-080': 'kg',
  'RAW-081': 'kg',
  'RAW-082': 'kg',
  'RAW-083': 'kg',
  'RAW-084': 'kg',
  'RAW-085': 'kg',
  'RAW-086': 'kg',
  'RAW-087': 'kg',
  'RAW-088': 'kg',
  'RAW-089': 'kg',
  'RAW-090': 'kg',
  'RAW-091': 'kg',
  'RAW-092': 'kg',
  'RAW-093': 'kg',
  'RAW-094': 'kg',
  'RAW-095': 'kg',
  'RAW-096': 'kg',
  'RAW-097': 'kg',
  'RAW-098': 'kg',
  'RAW-099': 'kg',
  'RAW-100': 'box',
  'RAW-101': 'piece',
  'RAW-102': 'kg',
  'RAW-103': 'kg',
  'RAW-104': 'kg',
  'RAW-105': 'kg',
  'RAW-106': 'pack',
  'RAW-107': 'bottle',
  'RAW-108': 'bottle',
  'RAW-109': 'bottle',
  'RAW-110': 'bottle',
  'RAW-111': 'bottle',
  'RAW-112': 'kg',
  'RAW-113': 'g',
  'RAW-114': 'g',
  'RAW-115': 'g',
  'RAW-116': 'g',
  'RAW-117': 'g',
  'RAW-118': 'g',
  'RAW-119': 'g',
  'RAW-120': 'kg',
  'RAW-121': 'kg',
  'RAW-122': 'kg',
  'RAW-123': 'litre',
  'RAW-124': 'roll',
  'RAW-125': 'pack',
  'RAW-126': 'piece',
  'RAW-127': 'pack',
  'RAW-128': 'pack',
  'RAW-129': 'roll',
  'RAW-130': 'pack',
  'RAW-131': 'pack',
  'RAW-132': 'pack',
  'RAW-133': 'pack',
  'RAW-134': 'pack',
  'RAW-135': 'pack',
  'RAW-136': 'pack',
  'RAW-137': 'pack',
  'RAW-138': 'pack',
  'RAW-139': 'pack',
  'RAW-140': 'piece',
  'RAW-141': 'piece',
  'RAW-142': 'pack',
  'RAW-143': 'piece',
  'RAW-144': 'pack',
  'RAW-145': 'pack',
  'RAW-146': 'piece',
  'RAW-147': 'piece',
  'RAW-148': 'piece',
  'RAW-149': 'piece',
  'RAW-150': 'piece',
  'RAW-151': 'piece',
  'RAW-152': 'piece',
  'RAW-153': 'piece',
  'RAW-154': 'kg',
};

function isGenericRawMaterialUnit(unit) {
  const text = (unit || '').toString().trim().toLowerCase();
  return !text || text === 'pramana' || text === '\u0caa\u0ccd\u0cb0\u0cae\u0cbe\u0ca3';
}

function normalizeRawMaterialUnits(rawMaterials = []) {
  return rawMaterials.map((item) => {
    const unit = rawMaterialUnitById[item?.id];
    if (!unit || !isGenericRawMaterialUnit(item.unit)) return item;
    return { ...item, unit };
  });
}

function ensureUniversal(db) {
  db.universal = db.universal || {};
  db.universal.menuItems = Array.isArray(db.universal.menuItems) ? db.universal.menuItems : [];
  db.universal.rawMaterials = Array.isArray(db.universal.rawMaterials) ? db.universal.rawMaterials : [];
  db.universal.produceItems = Array.isArray(db.universal.produceItems) ? db.universal.produceItems : [];
  db.universal.vesselItems = Array.isArray(db.universal.vesselItems) ? db.universal.vesselItems : [];
  const legacyNames = new Set(['Basmati Rice', 'Toor Dal', 'Cooking Oil', 'Tomato', 'Onion']);
  const hasOnlyLegacyRawMaterials = db.universal.rawMaterials.length > 0 && db.universal.rawMaterials.every((item) => legacyNames.has(item.name));
  if (db.universal.rawMaterials.length === 0 || hasOnlyLegacyRawMaterials) {
    db.universal.rawMaterials = defaultRawMaterials();
  }
  db.universal.rawMaterials = normalizeRawMaterialUnits(db.universal.rawMaterials);
  if (db.universal.produceItems.length === 0) {
    db.universal.produceItems = defaultProduceCatalog();
  }
  db.universal.vesselItems = mergeCatalogById(defaultVesselCatalog(), db.universal.vesselItems);
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

function nextCatalogId(list, prefix) {
  const pattern = new RegExp(`^${prefix}-(\\d+)$`, 'i');
  let maxNumber = 0;
  for (const item of asArray(list)) {
    const match = String(item?.id || '').trim().match(pattern);
    const value = Number.parseInt(match?.[1] || '', 10);
    if (Number.isFinite(value) && value > maxNumber) maxNumber = value;
  }
  return `${prefix}-${String(maxNumber + 1).padStart(3, '0')}`;
}

function eventFromBody(body, existing = {}) {
  return normalizeEventShape({
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
    employeeAssignments: Array.isArray(body.employeeAssignments) ? body.employeeAssignments.map(employeeAssignmentFromBody) : existing.employeeAssignments || [],
    createdAt: existing.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });
}

function employeeAssignmentFromBody(body, existing = {}) {
  return {
    ...existing,
    employeeId: body.employeeId || body.id || existing.employeeId || '',
    employeeName: body.employeeName || body.name || existing.employeeName || '',
    mobile: normalizeMobile(body.mobile || existing.mobile || ''),
    designation: body.designation || existing.designation || '',
    payPerDay: Number(body.payPerDay ?? existing.payPerDay ?? 0),
    payPerHour: Number(body.payPerHour ?? existing.payPerHour ?? 0),
  };
}

function materialDocumentFromBody(body, existing = {}) {
  return {
    ...existing,
    id: existing.id || body.id || makeId('matdoc'),
    type: ['raw', 'produce', 'vessels', 'menu'].includes(body.type) ? body.type : existing.type || 'raw',
    title: body.title || existing.title || 'Material List',
    eventId: body.eventId || existing.eventId || '',
    date: body.date || existing.date || '',
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
    menuSlots: Array.isArray(body.menuSlots)
      ? body.menuSlots.map((slot) => menuSlotFromBody(slot))
      : existing.menuSlots || [],
    additionalServices: Array.isArray(body.additionalServices)
      ? body.additionalServices.map(serviceFromBody)
      : existing.additionalServices || [],
  };
}

function sameEventDate(left, right) {
  return String(left?.date || '').trim() === String(right?.date || '').trim();
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
    additionalServices: Array.isArray(body.additionalServices)
      ? body.additionalServices.map(serviceFromBody)
      : existing.additionalServices || [],
    menuImages: Array.isArray(body.menuImages)
      ? body.menuImages.slice(0, 2).map((image) => ({
        id: image.id || makeId('menuimg'),
        name: image.name || '',
        dataUrl: image.dataUrl || '',
      })).filter((image) => image.dataUrl)
      : existing.menuImages || [],
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

function employeeFromBody(body, existing = {}) {
  const payPerDay = Number(body.payPerDay ?? existing.payPerDay ?? 0);
  return {
    ...existing,
    id: existing.id || body.id || makeId('emp'),
    name: body.name || existing.name || '',
    age: Number(body.age ?? existing.age ?? 0),
    mobile: normalizeMobile(body.mobile || existing.mobile || ''),
    designation: body.designation || existing.designation || '',
    payPerDay,
    payPerHour: Number(body.payPerHour ?? existing.payPerHour ?? (payPerDay ? Math.round(payPerDay / 8) : 0)),
    disabled: Boolean(body.disabled ?? existing.disabled ?? false),
    createdAt: existing.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
}

function attendanceFromBody(body, existing = {}) {
  const status = ['present', 'absent', 'partial'].includes(body.status) ? body.status : existing.status || 'absent';
  return {
    ...existing,
    id: existing.id || body.id || makeId('att'),
    employeeId: body.employeeId || existing.employeeId || '',
    employeeName: body.employeeName || existing.employeeName || '',
    eventId: body.eventId || existing.eventId || '',
    eventName: body.eventName || existing.eventName || '',
    date: body.date || existing.date || '',
    status,
    hours: status === 'partial' ? Number(body.hours ?? existing.hours ?? 0) : status === 'present' ? 8 : 0,
    payPerDay: Number(body.payPerDay ?? existing.payPerDay ?? 0),
    payPerHour: Number(body.payPerHour ?? existing.payPerHour ?? 0),
    updatedAt: new Date().toISOString(),
    createdAt: existing.createdAt || new Date().toISOString(),
  };
}

function money(value) {
  return `Rs. ${Number(value || 0).toLocaleString('en-IN')}`;
}

function serviceQuantityText(service) {
  const quantity = Number(service.quantity || 0);
  return quantity > 0 ? `${quantity} ${service.unit || ''}`.trim() : '';
}

function eventTotals(event) {
  const menuTotal = event.dates.reduce((dateSum, date) => dateSum + date.menuSlots
    .filter((slot) => slot.enabled !== false && Number(slot.pax || 0) > 0)
    .reduce((slotSum, slot) => slotSum + Number(slot.pax || 0) * Number(slot.pricePerPax || 0), 0), 0);
  const serviceTotal = event.dates.reduce((dateSum, date) => {
    const dateServices = (date.additionalServices || []).reduce((sum, service) => sum + Number(service.price || 0), 0);
    const slotServices = (date.menuSlots || []).reduce((slotSum, slot) => slotSum + (slot.additionalServices || []).reduce((sum, service) => sum + Number(service.price || 0), 0), 0);
    return dateSum + dateServices + slotServices;
  }, 0);
  const addOnTotal = (event.addOns || []).reduce((sum, addOn) => sum + Number(addOn.cost || 0), 0);
  const paid = event.payments.reduce((sum, payment) => sum + Number(payment.amount || 0), 0);
  const discount = event.payments.reduce((sum, payment) => sum + Number(payment.settledDiscount || 0), 0);
  const total = menuTotal + addOnTotal;
  return { menuTotal, serviceTotal, addOnTotal, total, paid, discount, balance: Math.max(0, total - paid - discount) };
}

function menuTimeSortMinutes(value) {
  const raw = String(value || '').trim();
  const match = raw.match(/^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])?$/);
  if (!match) return 24 * 60;
  let hour = Number.parseInt(match[1] || '0', 10);
  const minute = Number.parseInt(match[2] || '0', 10);
  const suffix = String(match[3] || '').toUpperCase();
  if (suffix === 'PM' && hour < 12) hour += 12;
  if (suffix === 'AM' && hour === 12) hour = 0;
  return Math.min(23, Math.max(0, hour)) * 60 + Math.min(59, Math.max(0, minute));
}

function sortedEventDates(dates = []) {
  return [...asArray(dates)].sort((a, b) => String(a.date || '').localeCompare(String(b.date || '')));
}

function sortedMenuSlots(slots = []) {
  return [...asArray(slots)].sort((a, b) => {
    const byTime = menuTimeSortMinutes(a.time) - menuTimeSortMinutes(b.time);
    if (byTime !== 0) return byTime;
    return String(a.type || '').localeCompare(String(b.type || ''));
  });
}

function sortedVisibleMenuSlots(slots = []) {
  return sortedMenuSlots(asArray(slots).filter((slot) => slot.enabled !== false && Number(slot.pax || 0) > 0));
}

function gstBreakdown(baseAmount, businessProfile = emptyBusinessProfile()) {
  const gstin = String(businessProfile.gstin || '').trim();
  const rate = Math.max(0, Number(businessProfile.gstRate ?? businessProfile.gstPercent ?? 5) || 0);
  if (!gstin || rate <= 0) {
    return { enabled: false, type: 'cgst_sgst', rate: 0, tax: 0, total: Number(baseAmount || 0), rows: [] };
  }
  const base = Number(baseAmount || 0);
  const type = String(businessProfile.gstType || '').toLowerCase() === 'igst' ? 'igst' : 'cgst_sgst';
  if (type === 'igst') {
    const tax = Math.round(base * rate / 100);
    return { enabled: true, type, rate, tax, total: base + tax, rows: [[`IGST (${formatPercent(rate)})`, tax]] };
  }
  const halfRate = rate / 2;
  const cgst = Math.round(base * halfRate / 100);
  const sgst = Math.round(base * halfRate / 100);
  return {
    enabled: true,
    type,
    rate,
    tax: cgst + sgst,
    total: base + cgst + sgst,
    rows: [[`CGST (${formatPercent(halfRate)})`, cgst], [`SGST (${formatPercent(halfRate)})`, sgst]],
  };
}

function formatPercent(value) {
  const number = Number(value || 0);
  return `${Number.isInteger(number) ? number : number.toFixed(2).replace(/0+$/, '').replace(/\.$/, '')}%`;
}

function userDataForEvent(db, event = {}) {
  const eventId = event.id || '';
  if (!eventId) return null;
  for (const userData of Object.values(db.userData || {})) {
    if (asArray(userData.events).some((item) => item.id === eventId)) {
      return ensureUserDataShape(userData);
    }
  }
  return null;
}

function menuCatalogForEvent(db, event = {}, menuItems = []) {
  const userData = userDataForEvent(db, event);
  const allItems = [
    ...asArray(menuItems),
    ...asArray(userData?.menuItems),
    ...asArray(db.universal?.menuItems),
    ...Object.values(db.userData || {}).flatMap((data) => asArray(data?.menuItems)),
  ];
  const seen = new Set();
  return allItems.filter((item) => {
    const itemId = String(item?.id || '');
    if (!itemId || seen.has(itemId)) return false;
    seen.add(itemId);
    return true;
  });
}

function menuItemByIdForEvent(db, id, event = {}, menuItems = []) {
  const itemId = String(id || '');
  return menuCatalogForEvent(db, event, menuItems).find((menuItem) => menuItem.id === itemId);
}

function menuTitleById(db, id, event = {}, menuItems = []) {
  const item = menuItemByIdForEvent(db, id, event, menuItems);
  return item ? item.english || item.title || id : id;
}

function menuDisplayById(db, id, event = {}, menuItems = []) {
  const item = menuItemByIdForEvent(db, id, event, menuItems);
  if (!item) return id;
  return item.kannada ? `${repairMojibake(item.kannada)} / ${repairMojibake(item.english)}` : repairMojibake(item.english || item.title || id);
}

function invoiceMenuDisplayById(db, id, event = {}, menuItems = []) {
  const item = menuItemByIdForEvent(db, id, event, menuItems);
  if (!item) return id;
  return repairMojibake(item.english || item.title || item.kannada || id);
}

function menuPartsById(db, id, event = {}, menuItems = []) {
  const item = menuItemByIdForEvent(db, id, event, menuItems);
  if (!item) return { kannada: '', english: id };
  return { kannada: repairMojibake(item.kannada || ''), english: repairMojibake(item.english || item.title || id) };
}

function hasKannadaText(value) {
  return /[\u0C80-\u0CFF]/.test(String(value || ''));
}

function hasDevanagariText(value) {
  return /[\u0900-\u097F]/.test(String(value || ''));
}

function fontForText(fonts, value, bold = false) {
  const source = String(value || '');
  if (hasKannadaText(source)) return bold ? fonts.kannadaBold : fonts.kannada;
  if (hasDevanagariText(source)) return bold ? fonts.devanagariBold : fonts.devanagari;
  return bold ? fonts.bold : fonts.regular;
}

function needsScriptRuns(value) {
  const source = String(value || '');
  const families = [
    hasKannadaText(source),
    hasDevanagariText(source),
    /[A-Za-z0-9]/.test(source),
  ].filter(Boolean).length;
  return families > 1;
}

function scriptTokenWidth(doc, token, fonts, fontSize, bold = false) {
  doc.font(fontForText(fonts, token, bold)).fontSize(fontSize);
  return doc.widthOfString(token);
}

function drawScriptRuns(doc, text, x, y, width, fonts, options = {}) {
  const fontSize = options.fontSize || 7;
  const color = options.color || '#202124';
  const lineGap = options.lineGap ?? Math.max(1, fontSize * 0.12);
  const lineHeight = fontSize + lineGap + 3;
  const source = repairMojibake(String(text || ''));
  const tokens = source.split(/(\s+)/).filter((token) => token.length > 0);
  let cursorX = x;
  let cursorY = y;
  let lineHasText = false;
  for (const token of tokens) {
    const isSpace = /^\s+$/.test(token);
    if (isSpace && !lineHasText) continue;
    const tokenWidth = scriptTokenWidth(doc, token, fonts, fontSize, options.bold);
    if (!isSpace && lineHasText && cursorX + tokenWidth > x + width) {
      cursorX = x;
      cursorY += lineHeight;
      lineHasText = false;
    }
    if (isSpace && cursorX + tokenWidth > x + width) {
      cursorX = x;
      cursorY += lineHeight;
      lineHasText = false;
      continue;
    }
    doc.fillColor(color).font(fontForText(fonts, token, options.bold)).fontSize(fontSize)
      .text(token, cursorX, cursorY, { lineBreak: false });
    cursorX += tokenWidth;
    if (!isSpace) lineHasText = true;
  }
  return cursorY - y + lineHeight;
}

function scriptRunsHeight(doc, text, width, fonts, options = {}) {
  const fontSize = options.fontSize || 7;
  const lineGap = options.lineGap ?? Math.max(1, fontSize * 0.12);
  const lineHeight = fontSize + lineGap + 3;
  const source = repairMojibake(String(text || ''));
  const tokens = source.split(/(\s+)/).filter((token) => token.length > 0);
  let cursor = 0;
  let lines = 1;
  let lineHasText = false;
  for (const token of tokens) {
    const isSpace = /^\s+$/.test(token);
    if (isSpace && !lineHasText) continue;
    const tokenWidth = scriptTokenWidth(doc, token, fonts, fontSize, options.bold);
    if (!isSpace && lineHasText && cursor + tokenWidth > width) {
      lines += 1;
      cursor = 0;
      lineHasText = false;
    }
    if (isSpace && cursor + tokenWidth > width) {
      lines += 1;
      cursor = 0;
      lineHasText = false;
      continue;
    }
    cursor += tokenWidth;
    if (!isSpace) lineHasText = true;
  }
  return lines * lineHeight;
}

function repairMojibake(value) {
  const text = String(value || '');
  const looksMojibake = [...text].some((char) => [0x00c3, 0x00c2, 0x00e0].includes(char.charCodeAt(0)));
  if (!looksMojibake) return text;
  try {
    const win1252 = {
      0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87,
      0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C, 0x017D: 0x8E, 0x2018: 0x91,
      0x2019: 0x92, 0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97, 0x02DC: 0x98,
      0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B, 0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F,
    };
    const bytes = [];
    for (const char of text) {
      const code = char.charCodeAt(0);
      bytes.push(win1252[code] ?? (code <= 0xFF ? code : 0x3F));
    }
    return Buffer.from(bytes).toString('utf8');
  } catch {
    return text;
  }
}

function drawTextRun(doc, text, x, y, width, fonts, options = {}) {
  const fontSize = options.fontSize || 7;
  const color = options.color || '#202124';
  const source = repairMojibake(String(text || ''));
  if (!source) return 0;
  if (needsScriptRuns(source)) {
    return drawScriptRuns(doc, source, x, y, width, fonts, options);
  }
  const textOptions = {
    width,
    align: options.align,
    lineGap: options.lineGap ?? Math.max(1, fontSize * 0.12),
  };
  if (options.height != null) textOptions.height = options.height;
  if (options.ellipsis) textOptions.ellipsis = true;
  if (options.lineBreak === false) textOptions.lineBreak = false;
  doc.fillColor(color).font(fontForText(fonts, source, options.bold)).fontSize(fontSize);
  doc.text(source, x, y, textOptions);
  return doc.heightOfString(source, textOptions);
}

function textRunHeight(doc, text, width, fonts, options = {}) {
  const fontSize = options.fontSize || 7;
  const source = repairMojibake(String(text || ''));
  if (!source) return 0;
  if (needsScriptRuns(source)) {
    return scriptRunsHeight(doc, source, width, fonts, options);
  }
  doc.font(fontForText(fonts, source, options.bold)).fontSize(fontSize);
  return doc.heightOfString(source, {
    width,
    align: options.align,
    lineGap: options.lineGap ?? Math.max(1, fontSize * 0.12),
  });
}

function drawSingleLineText(doc, text, x, y, width, fonts, options = {}) {
  const fontSize = options.fontSize || 7;
  const color = options.color || '#202124';
  const source = repairMojibake(String(text || ''));
  const textOptions = { width, height: options.height || 12, ellipsis: true, lineBreak: false, align: options.align };
  if (!source) return;
  const parts = source.split(/\s*\/\s*/);
  if (parts.length > 1 && hasKannadaText(parts[0])) {
    const kannada = parts[0].trim();
    const english = parts.slice(1).join(' / ').trim();
    doc.fillColor(color).font(fontForText(fonts, kannada)).fontSize(fontSize).text(kannada, x, y, textOptions);
    const used = Math.min(width * 0.58, doc.widthOfString(kannada) + 4);
    if (english) doc.fillColor(color).font(fonts.regular).fontSize(fontSize - 0.2).text(`/ ${english}`, x + used, y + 0.5, { ...textOptions, width: Math.max(8, width - used) });
    return;
  }
  if (hasKannadaText(source) && /[A-Za-z0-9]/.test(source)) {
    const runs = source.match(/[\u0C80-\u0CFF]+|[^\u0C80-\u0CFF]+/g) || [source];
    let cursor = x;
    for (const run of runs) {
      const font = hasKannadaText(run) ? fonts.kannada : fonts.regular;
      const remaining = x + width - cursor;
      if (remaining <= 4) break;
      doc.fillColor(color).font(font).fontSize(fontSize).text(run, cursor, y, { ...textOptions, width: remaining });
      cursor += doc.widthOfString(run);
    }
    return;
  }
  doc.fillColor(color).font(fontForText(fonts, source)).fontSize(fontSize).text(source, x, y, textOptions);
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

function safeFilenamePart(value) {
  const normalized = String(value || '')
    .trim()
    .replace(/[^A-Za-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-');
  return normalized;
}

function eventClientName(event = {}) {
  return event.primaryClient || event.clientName || event.customerName || 'Client';
}

function pdfFilename(parts) {
  const name = parts.map((part) => safeFilenamePart(part)).filter(Boolean).join('-');
  return `${name || 'caterpro-document'}.pdf`;
}

function setPdfAttachment(res, parts, disposition = 'attachment') {
  res.setHeader('Content-Disposition', `${disposition}; filename="${pdfFilename(parts)}"`);
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
  const assetFont = (name) => path.join(__dirname, 'assets', 'fonts', name);
  const nirmala = firstExistingPath(['C:\\Windows\\Fonts\\Nirmala.ttc']);
  const bundledRegular = firstExistingPath([assetFont('NotoSans-Regular.ttf')]);
  const bundledBold = firstExistingPath([assetFont('NotoSans-Bold.ttf')]);
  const bundledKannadaRegular = firstExistingPath([assetFont('NotoSansKannada-Regular.ttf')]);
  const bundledKannadaBold = firstExistingPath([assetFont('NotoSansKannada-Bold.ttf')]);
  const bundledDevanagariRegular = firstExistingPath([assetFont('NotoSansDevanagari-Regular.ttf')]);
  const bundledDevanagariBold = firstExistingPath([assetFont('NotoSansDevanagari-Bold.ttf')]);
  if (!bundledRegular && !bundledKannadaRegular && !bundledDevanagariRegular && nirmala) {
    doc.registerFont('NirmalaRegular', nirmala, 'NirmalaUI');
    doc.registerFont('NirmalaBold', nirmala, 'NirmalaUI-Bold');
    return {
      regular: 'NirmalaRegular',
      bold: 'NirmalaBold',
      kannada: 'NirmalaRegular',
      kannadaBold: 'NirmalaBold',
      devanagari: 'NirmalaRegular',
      devanagariBold: 'NirmalaBold',
    };
  }
  const latinRegular = firstExistingPath([
    bundledRegular,
    path.join(__dirname, 'node_modules', '@fontsource', 'noto-sans', 'files', 'noto-sans-latin-400-normal.woff'),
    'C:\\Windows\\Fonts\\segoeui.ttf',
    'C:\\Windows\\Fonts\\arial.ttf',
  ]);
  const latinBold = firstExistingPath([
    bundledBold,
    path.join(__dirname, 'node_modules', '@fontsource', 'noto-sans', 'files', 'noto-sans-latin-700-normal.woff'),
    'C:\\Windows\\Fonts\\segoeuib.ttf',
    'C:\\Windows\\Fonts\\arialbd.ttf',
  ]);
  const kannadaRegular = firstExistingPath([
    bundledKannadaRegular,
    path.join(__dirname, 'node_modules', '@fontsource', 'noto-sans-kannada', 'files', 'noto-sans-kannada-kannada-400-normal.woff'),
  ]);
  const kannadaBold = firstExistingPath([
    bundledKannadaBold,
    path.join(__dirname, 'node_modules', '@fontsource', 'noto-sans-kannada', 'files', 'noto-sans-kannada-kannada-700-normal.woff'),
  ]);
  const devanagariRegular = firstExistingPath([
    bundledDevanagariRegular,
    path.join(__dirname, 'node_modules', '@fontsource', 'noto-sans-devanagari', 'files', 'noto-sans-devanagari-devanagari-400-normal.woff'),
    'C:\\Windows\\Fonts\\Nirmala.ttf',
    'C:\\Windows\\Fonts\\Nirmala.ttc',
  ]);
  const devanagariBold = firstExistingPath([
    bundledDevanagariBold,
    path.join(__dirname, 'node_modules', '@fontsource', 'noto-sans-devanagari', 'files', 'noto-sans-devanagari-devanagari-700-normal.woff'),
    'C:\\Windows\\Fonts\\NirmalaB.ttf',
    'C:\\Windows\\Fonts\\Nirmala.ttc',
  ]);
  if (latinRegular) doc.registerFont('LatinRegular', latinRegular);
  if (latinBold) doc.registerFont('LatinBold', latinBold);
  if (kannadaRegular) doc.registerFont('KannadaRegular', kannadaRegular);
  if (kannadaBold) doc.registerFont('KannadaBold', kannadaBold);
  if (devanagariRegular) doc.registerFont('DevanagariRegular', devanagariRegular);
  if (devanagariBold) doc.registerFont('DevanagariBold', devanagariBold);
  return {
    regular: latinRegular ? 'LatinRegular' : 'Helvetica',
    bold: latinBold ? 'LatinBold' : 'Helvetica-Bold',
    kannada: kannadaRegular ? 'KannadaRegular' : 'Helvetica',
    kannadaBold: kannadaBold ? 'KannadaBold' : 'Helvetica-Bold',
    devanagari: devanagariRegular ? 'DevanagariRegular' : (kannadaRegular ? 'KannadaRegular' : (latinRegular ? 'LatinRegular' : 'Helvetica')),
    devanagariBold: devanagariBold ? 'DevanagariBold' : (kannadaBold ? 'KannadaBold' : (latinBold ? 'LatinBold' : 'Helvetica-Bold')),
  };
}

function imageBufferFromDataUrl(value) {
  if (!value || typeof value !== 'string') return null;
  const source = value.trim();
  const base64 = source.includes(',') ? source.split(',').pop() : source;
  if (!base64) return null;
  try {
    return Buffer.from(base64.replace(/\s/g, ''), 'base64');
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
  const template = businessProfile.documentTemplate || 'boxed';
  const normalized = template === 'premium' ? 'elegant' : template === 'minimal' ? 'classic' : template;
  const themes = {
    classic: { name: 'classic', primary: '#111827', secondary: '#6b7280', accent: '#374151', soft: '#f3f4f6', page: '#ffffff', ink: '#111827', muted: '#4b5563', scale: businessProfile.invoiceTextScale || 1 },
    elegant: { name: 'elegant', primary: '#1f3b32', secondary: '#b8943c', accent: '#7b1b44', soft: '#fbf6e8', page: '#ffffff', ink: '#202124', muted: '#5f6368', scale: businessProfile.invoiceTextScale || 1 },
    modern: { name: 'modern', primary: '#06445d', secondary: '#f2a51a', accent: '#1c7c8a', soft: '#fff4db', page: '#ffffff', ink: '#202124', muted: '#59656b', scale: businessProfile.invoiceTextScale || 1 },
    boxed: { name: 'boxed', primary: '#173f91', secondary: '#a9c7f3', accent: '#111111', soft: '#eaf3ff', page: '#ffffff', ink: '#171717', muted: '#737373', scale: businessProfile.invoiceTextScale || 1 },
  };
  return themes[normalized] || themes.boxed;
}

function documentMetrics(theme = documentTheme()) {
  if (theme.name === 'boxed') return { left: 18, right: 577, width: 559, tableY: 246 };
  if (theme.name === 'elegant') return { left: 106, right: 559, width: 453, tableY: 228 };
  return { left: 36, right: 559, width: 523, tableY: theme.name === 'classic' ? 238 : 232 };
}

function documentContentBottom(theme = documentTheme()) {
  if (theme.name === 'boxed') return 736;
  return 780;
}

function documentContinuationTableY(theme = documentTheme()) {
  if (theme.name === 'boxed') return 138;
  if (theme.name === 'elegant') return 126;
  return 116;
}

function writeDocumentHeader(doc, title, event, number, fonts, businessProfile = emptyBusinessProfile()) {
  const theme = documentTheme(businessProfile);
  const businessName = businessProfile.businessName || 'CaterPro';
  const contactLine = [businessProfile.phone, businessProfile.email].filter(Boolean).join(' | ');
  const taxLine = [businessProfile.gstin ? `GSTIN: ${businessProfile.gstin}` : '', businessProfile.pan ? `PAN: ${businessProfile.pan}` : ''].filter(Boolean).join(' | ');
  const documentDate = event.invoiceDate || event.documentDate || new Date().toISOString().slice(0, 10);
  doc.rect(0, 0, doc.page.width, doc.page.height).fill(theme.page);
  if (theme.name === 'boxed') {
    const metrics = documentMetrics(theme);
    const boxX = metrics.left;
    const boxY = 18;
    const boxW = metrics.width;
    const headerH = 104;
    const titleW = Math.floor(boxW * 0.25);
    const leftW = boxW - titleW - 18;
    doc.rect(boxX, boxY, boxW, 806).strokeColor(theme.accent).lineWidth(0.8).stroke();
    doc.moveTo(boxX, boxY + headerH).lineTo(boxX + boxW, boxY + headerH).strokeColor(theme.accent).lineWidth(0.75).stroke();

    const logoDrawn = drawProfileImage(doc, businessProfile.logoBase64, boxX + 14, boxY + 18, { fit: [58, 58] });
    const nameX = logoDrawn ? boxX + 84 : boxX + 16;
    const nameW = logoDrawn ? leftW - 84 : leftW - 16;
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(15.5).text(businessName, nameX, boxY + 19, { width: nameW, height: 20, ellipsis: true });
    const profileLines = [
      businessProfile.address || 'Catering event management',
      contactLine,
      taxLine,
    ].filter(Boolean).join('\n');
    drawTextRun(doc, profileLines, nameX, boxY + 42, nameW, fonts, {
      fontSize: PDF_BODY_FONT_SIZE,
      color: theme.muted,
      lineGap: 2,
      height: 48,
      ellipsis: true,
    });
    const titleX = boxX + boxW - titleW - 16;
    doc.fillColor(theme.primary).font(fonts.regular).fontSize(23).text(title, titleX, boxY + 18, { width: titleW, align: 'right', lineBreak: false });
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(8.2).text(number, titleX, boxY + 47, { width: titleW, align: 'right', lineBreak: false });
    doc.fillColor(theme.muted).font(fonts.regular).fontSize(8).text(prettyDate(documentDate), titleX, boxY + 62, { width: titleW, align: 'right', lineBreak: false });
    return;
  }
  if (theme.name === 'classic') {
    doc.rect(36, 28, 523, 76).strokeColor(theme.ink).lineWidth(1).stroke();
    doc.moveTo(366, 28).lineTo(366, 104).strokeColor(theme.ink).lineWidth(0.7).stroke();
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(16).text(businessName, 52, 40, { width: 290 });
    drawTextRun(doc, businessProfile.address || 'Catering event management', 52, 62, 290, fonts, {
      fontSize: PDF_BODY_FONT_SIZE,
      color: theme.muted,
      height: 16,
      ellipsis: true,
    });
    if (contactLine) doc.text(contactLine, 52, 80, { width: 290 });
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(17).text(title, 388, 40, { width: 142, align: 'right' });
    doc.fillColor(theme.muted).font(fonts.regular).fontSize(PDF_BODY_FONT_SIZE).text(number, 388, 64, { width: 142, align: 'right' });
    if (taxLine) doc.text(taxLine, 388, 80, { width: 142, align: 'right' });
    return;
  }
  if (theme.name === 'elegant') {
    doc.rect(0, 0, 86, doc.page.height).fill(theme.primary);
    doc.rect(86, 0, 5, doc.page.height).fill(theme.secondary);
    if (!drawProfileImage(doc, businessProfile.logoBase64, 24, 36, { fit: [42, 42] })) {
      doc.circle(45, 57, 22).lineWidth(1.2).strokeColor(theme.secondary).stroke();
      doc.fillColor('white').font(fonts.bold).fontSize(12).text(businessName.slice(0, 2).toUpperCase(), 24, 50, { width: 42, align: 'center' });
    }
    doc.fillColor(theme.primary).font(fonts.bold).fontSize(19).text(businessName, 106, 32, { width: 260 });
    drawTextRun(doc, businessProfile.address || 'Catering event management', 106, 58, 260, fonts, {
      fontSize: PDF_BODY_FONT_SIZE,
      color: theme.muted,
      height: 16,
      ellipsis: true,
    });
    if (contactLine) doc.text(contactLine, 106, 78, { width: 260 });
    doc.fillColor(theme.primary).font(fonts.bold).fontSize(23).text(title, 392, 34, { width: 148, align: 'right' });
    doc.fillColor(theme.secondary).font(fonts.bold).fontSize(PDF_BODY_FONT_SIZE).text(number, 392, 66, { width: 148, align: 'right' });
    if (taxLine) doc.fillColor(theme.muted).font(fonts.regular).fontSize(7).text(taxLine, 350, 84, { width: 190, align: 'right' });
    doc.moveTo(106, 108).lineTo(559, 108).strokeColor(theme.secondary).lineWidth(0.9).stroke();
    return;
  }
  doc.roundedRect(36, 28, 523, 76, 12).fill(theme.primary);
  doc.roundedRect(36, 28, 9, 76, 3).fill(theme.secondary);
  if (!drawProfileImage(doc, businessProfile.logoBase64, 58, 48, { fit: [40, 40] })) {
    doc.circle(82, 68, 23).lineWidth(1.5).strokeColor(theme.secondary).stroke();
    doc.fillColor('white').font(fonts.bold).fontSize(14).text(businessName.slice(0, 2).toUpperCase(), 59, 61, { width: 46, align: 'center' });
  }
  doc.fillColor('white').font(fonts.bold).fontSize(17).text(businessName, 116, 42, { width: 258 });
  drawTextRun(doc, businessProfile.address || 'Catering event management', 116, 64, 258, fonts, {
    fontSize: PDF_BODY_FONT_SIZE,
    color: '#ffffff',
    height: 17,
    ellipsis: true,
  });
  if (contactLine) doc.text(contactLine, 116, 84, { width: 258 });
  doc.font(fonts.bold).fontSize(20).text(title, 390, 42, { width: 140, align: 'right' });
  doc.fillColor('#f6f2df').font(fonts.regular).fontSize(PDF_BODY_FONT_SIZE).text(number, 390, 68, { width: 140, align: 'right' });
  if (taxLine) doc.text(taxLine, 330, 84, { width: 200, align: 'right' });
}

function documentInfoSection(doc, title, event, number, fonts, businessProfile, isInvoice) {
  const theme = documentTheme(businessProfile);
  const metrics = documentMetrics(theme);
  const hasBusinessGst = Boolean(String(businessProfile.gstin || '').trim());
  const documentDate = event.invoiceDate || event.documentDate || new Date().toISOString().slice(0, 10);
  const boxX = metrics.left;
  const boxW = metrics.width;
  const boxY = theme.name === 'classic' ? 116 : theme.name === 'elegant' ? 122 : 118;
  const leftX = boxX + 14;
  const leftW = 220;
  const detailX = boxX + boxW - 238;
  const detailW = 220;
  const clientName = event.primaryClient || 'Customer';
  const addressLine = event.clientAddress ? `Address: ${event.clientAddress}` : event.venue ? `Venue: ${event.venue}` : 'Venue: -';
  const eventLine = `Event: ${event.name || 'Untitled Event'}`;
  const clientGstLine = hasBusinessGst && event.clientGst ? `Client GSTIN: ${event.clientGst}` : '';
  const eventDates = event.dates.map((date) => prettyDate(date.date)).join(', ') || '-';
  const detailLines = [
    `${title} No: ${number}`,
    `${title} Date: ${prettyDate(documentDate)}`,
    `Event Date: ${eventDates}`,
    ...(!isInvoice ? ['Valid Till: 15 days from quotation date'] : []),
  ];
  if (theme.name === 'boxed') {
    const splitX = boxX + Math.floor(boxW / 2);
    const detailsY = 122;
    const detailsH = 112;
    const colPad = 14;
    const colW = boxW / 2 - colPad * 2;
    const billLines = [
      clientName,
      event.mobile ? `Mobile: ${event.mobile}` : '',
      addressLine,
      clientGstLine,
    ].filter(Boolean);
    const eventDetails = [
      event.name || 'Untitled Event',
      `Date: ${eventDates}`,
      event.venue ? `Venue: ${event.venue}` : '',
    ].filter(Boolean);

    doc.rect(boxX, detailsY, boxW, detailsH).strokeColor(theme.accent).lineWidth(0.75).stroke();
    doc.moveTo(splitX, detailsY).lineTo(splitX, detailsY + detailsH).strokeColor(theme.accent).lineWidth(0.75).stroke();
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(9.8).text('Bill To', boxX + colPad, detailsY + 11, { width: colW });
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(9.8).text('Event Details', splitX + colPad, detailsY + 11, { width: colW });
    const clientNameH = drawTextRun(doc, clientName, boxX + colPad, detailsY + 31, colW, fonts, {
      fontSize: 10.5,
      color: theme.ink,
      bold: true,
      lineGap: 1,
      height: 38,
    });
    const billDetailY = detailsY + 31 + clientNameH + 5;
    drawTextRun(doc, billLines.slice(1).join('\n'), boxX + colPad, billDetailY, colW, fonts, {
      fontSize: 8.5,
      color: theme.muted,
      lineGap: 2,
      height: Math.max(28, detailsY + detailsH - billDetailY - 10),
      ellipsis: true,
    });
    const eventNameH = drawTextRun(doc, eventDetails[0], splitX + colPad, detailsY + 31, colW, fonts, {
      fontSize: 10.5,
      color: theme.ink,
      bold: true,
      lineGap: 1,
      height: 38,
    });
    drawTextRun(doc, eventDetails.slice(1).join('\n'), splitX + colPad, detailsY + 31 + eventNameH + 5, colW, fonts, {
      fontSize: 8.5,
      color: theme.muted,
      lineGap: 2,
      height: 42,
      ellipsis: true,
    });
    return detailsY + detailsH + 12;
  }
  const leftContentH =
    18 +
    textRunHeight(doc, clientName, leftW, fonts, { fontSize: 10.5, bold: true }) +
    6 +
    textRunHeight(doc, event.mobile ? `Mobile: ${event.mobile}` : 'Mobile: -', leftW, fonts, { fontSize: PDF_BODY_FONT_SIZE }) +
    6 +
    textRunHeight(doc, addressLine, leftW, fonts, { fontSize: PDF_BODY_FONT_SIZE }) +
    6 +
    textRunHeight(doc, eventLine, leftW, fonts, { fontSize: PDF_BODY_FONT_SIZE }) +
    (clientGstLine ? 6 + textRunHeight(doc, clientGstLine, leftW, fonts, { fontSize: PDF_BODY_FONT_SIZE }) : 0);
  const rightContentH =
    18 +
    detailLines.reduce((sum, line) => sum + textRunHeight(doc, line, detailW, fonts, { fontSize: PDF_BODY_FONT_SIZE, align: 'right' }) + 6, 0);
  const boxH = Math.max(96, Math.ceil(Math.max(leftContentH, rightContentH)) + 26);
  if (theme.name === 'classic') {
    doc.rect(boxX, boxY, boxW, boxH).strokeColor(theme.ink).lineWidth(0.7).stroke();
    doc.moveTo(296, boxY).lineTo(296, boxY + boxH).strokeColor('#c8ced4').lineWidth(0.6).stroke();
  } else if (theme.name === 'elegant') {
    doc.rect(boxX, boxY, boxW, boxH).fill(theme.soft).strokeColor('#eadfcf').lineWidth(0.6).stroke();
    doc.rect(boxX, boxY, 4, boxH).fill(theme.secondary);
  } else {
    doc.roundedRect(boxX, boxY, boxW, boxH, 10).fill('#ffffff').strokeColor('#d7e9ec').lineWidth(0.9).stroke();
    doc.roundedRect(boxX, boxY, boxW, 8, 4).fill(theme.secondary);
  }
  doc.fillColor(theme.primary).font(fonts.bold).fontSize(10).text('Bill To', boxX + 14, boxY + 15);
  let leftY = boxY + 33;
  const clientH = drawTextRun(doc, clientName, leftX, leftY, leftW, fonts, {
    fontSize: 10.5,
    color: theme.ink,
    bold: true,
  });
  leftY += clientH + 6;
  const mobileH = drawTextRun(doc, event.mobile ? `Mobile: ${event.mobile}` : 'Mobile: -', leftX, leftY, leftW, fonts, {
    fontSize: PDF_BODY_FONT_SIZE,
    color: theme.muted,
  });
  leftY += mobileH + 6;
  const addressH = drawTextRun(doc, addressLine, leftX, leftY, leftW, fonts, {
    fontSize: PDF_BODY_FONT_SIZE,
    color: theme.muted,
  });
  leftY += addressH + 6;
  const eventH = drawTextRun(doc, eventLine, leftX, leftY, leftW, fonts, {
    fontSize: PDF_BODY_FONT_SIZE,
    color: theme.muted,
  });
  leftY += eventH + 6;
  if (clientGstLine) {
    drawTextRun(doc, clientGstLine, leftX, leftY, leftW, fonts, {
      fontSize: PDF_BODY_FONT_SIZE,
      color: theme.muted,
    });
  }

  doc.fillColor(theme.primary).font(fonts.bold).fontSize(10).text(`${title} Details`, detailX, boxY + 15, { width: detailW, align: 'right' });
  let detailY = boxY + 35;
  for (const line of detailLines) {
    const used = drawTextRun(doc, line, detailX, detailY, detailW, fonts, {
      fontSize: PDF_BODY_FONT_SIZE,
      color: theme.ink,
      align: 'right',
    });
    detailY += used + 6;
  }
  return boxY + boxH + 16;
}

function invoiceTableLayout(theme = documentTheme()) {
  if (theme.name === 'boxed') {
    return { x: 18, w: 559, descX: 32, descW: 318, qtyX: 365, qtyW: 54, rateX: 434, rateW: 58, amountX: 508, amountW: 55 };
  }
  if (theme.name === 'elegant') {
    return { x: 112, w: 447, descX: 126, descW: 184, qtyX: 318, qtyW: 58, rateX: 386, rateW: 60, amountX: 462, amountW: 78 };
  }
  if (theme.name === 'classic') {
    return { x: 36, w: 523, descX: 48, descW: 232, qtyX: 294, qtyW: 64, rateX: 372, rateW: 70, amountX: 460, amountW: 82 };
  }
  return { x: 36, w: 523, descX: 54, descW: 228, qtyX: 304, qtyW: 60, rateX: 374, rateW: 68, amountX: 462, amountW: 80 };
}

function tableHeader(doc, y, fonts, theme = documentTheme()) {
  const layout = invoiceTableLayout(theme);
  if (theme.name === 'boxed') {
    doc.rect(layout.x, y, layout.w, 24).fill(theme.primary).strokeColor(theme.accent).lineWidth(0.75).stroke();
    [layout.qtyX - 8, layout.rateX - 8, layout.amountX - 8].forEach((x) => doc.moveTo(x, y).lineTo(x, y + 24).strokeColor(theme.accent).lineWidth(0.6).stroke());
    doc.fillColor('white').font(fonts.bold).fontSize(PDF_BODY_FONT_SIZE)
      .text('Description', layout.descX, y + 8, { width: layout.descW })
      .text('Members', layout.qtyX, y + 8, { width: layout.qtyW, align: 'right' })
      .text('Rate', layout.rateX, y + 8, { width: layout.rateW, align: 'right' })
      .text('Amount', layout.amountX, y + 8, { width: layout.amountW, align: 'right' });
    return;
  }
  if (theme.name === 'classic') {
    doc.rect(layout.x, y, layout.w, 24).strokeColor(theme.ink).lineWidth(0.9).stroke();
    [296, 364, 450].forEach((x) => doc.moveTo(x, y).lineTo(x, y + 24).strokeColor(theme.ink).lineWidth(0.5).stroke());
    doc.fillColor(theme.ink);
  } else if (theme.name === 'elegant') {
    doc.rect(layout.x, y, layout.w, 20).fill(theme.primary);
    doc.rect(layout.x, y + 20, layout.w, 1.5).fill(theme.secondary);
    doc.fillColor('white');
  } else {
    doc.roundedRect(layout.x, y, layout.w, 30, 8).fill(theme.primary);
    doc.circle(layout.x + 16, y + 15, 4).fill(theme.secondary);
    doc.fillColor('white');
  }
  doc.font(fonts.bold).fontSize(PDF_BODY_FONT_SIZE)
    .text('Description', layout.descX, y + (theme.name === 'modern' ? 10 : 7), { width: layout.descW })
    .text('Members', layout.qtyX, y + (theme.name === 'modern' ? 10 : 7), { width: layout.qtyW, align: 'right' })
    .text('Rate', layout.rateX, y + (theme.name === 'modern' ? 10 : 7), { width: layout.rateW, align: 'right' })
    .text('Amount', layout.amountX, y + (theme.name === 'modern' ? 10 : 7), { width: layout.amountW, align: 'right' });
}

function ensurePageSpace(doc, y, needed = 44, onNewPage = null, theme = documentTheme()) {
  if (y + needed < documentContentBottom(theme)) return y;
  doc.addPage();
  if (onNewPage) {
    const nextY = onNewPage();
    if (Number.isFinite(nextY)) return nextY;
  }
  return 44;
}

function invoiceRowHeight(doc, columns, fonts, theme = documentTheme()) {
  const layout = invoiceTableLayout(theme);
  const descHeight = textRunHeight(doc, columns.description, layout.descW, fonts, { fontSize: PDF_BODY_FONT_SIZE, lineGap: 1 });
  const rowHeight = Math.max(theme.name === 'boxed' ? 30 : 25, descHeight + (theme.name === 'boxed' ? 14 : 9));
  if (theme.name !== 'boxed') return rowHeight;
  return Math.min(rowHeight, documentContentBottom(theme) - documentContinuationTableY(theme) - 12);
}

function drawInvoiceRow(doc, y, fonts, columns, shaded = false, theme = documentTheme()) {
  const layout = invoiceTableLayout(theme);
  const rowHeight = invoiceRowHeight(doc, columns, fonts, theme);
  if (theme.name === 'boxed') {
    doc.rect(layout.x, y - 3, layout.w, rowHeight).strokeColor(theme.accent).lineWidth(0.65).stroke();
    [layout.qtyX - 8, layout.rateX - 8, layout.amountX - 8].forEach((x) => doc.moveTo(x, y - 3).lineTo(x, y - 3 + rowHeight).strokeColor(theme.accent).lineWidth(0.55).stroke());
  } else if (theme.name === 'classic') {
    doc.rect(layout.x, y - 4, layout.w, rowHeight).strokeColor('#111827').lineWidth(0.35).stroke();
    [296, 364, 450].forEach((x) => doc.moveTo(x, y - 4).lineTo(x, y - 4 + rowHeight).strokeColor('#9ca3af').lineWidth(0.3).stroke());
  } else if (shaded) {
    if (theme.name === 'elegant') {
      doc.rect(layout.x, y - 3, layout.w, rowHeight).fill('#fffaf0');
    } else {
      doc.roundedRect(layout.x, y - 4, layout.w, rowHeight, 6).fill('#ffffff').strokeColor('#d9e8ea').lineWidth(0.6).stroke();
    }
  } else if (theme.name === 'modern') {
    doc.roundedRect(layout.x, y - 4, layout.w, rowHeight, 6).fill('#fbfdfd').strokeColor('#e1eef0').lineWidth(0.6).stroke();
  }
  drawTextRun(doc, columns.description, layout.descX, theme.name === 'boxed' ? y + 5 : y, layout.descW, fonts, { fontSize: theme.name === 'boxed' ? 8.5 : PDF_BODY_FONT_SIZE, color: theme.ink, lineGap: 1, height: theme.name === 'boxed' ? rowHeight - 12 : undefined, ellipsis: theme.name === 'boxed' });
  doc.fillColor(theme.ink).font(fonts.regular).fontSize(PDF_BODY_FONT_SIZE)
    .text(columns.qty, layout.qtyX, theme.name === 'boxed' ? y + 6 : y, { width: layout.qtyW, align: 'right' })
    .text(columns.rate, layout.rateX, theme.name === 'boxed' ? y + 6 : y, { width: layout.rateW, align: 'right' })
    .text(columns.amount, layout.amountX, theme.name === 'boxed' ? y + 6 : y, { width: layout.amountW, align: 'right' });
  if (theme.name === 'elegant') doc.moveTo(layout.x, y - 4 + rowHeight).lineTo(layout.x + layout.w, y - 4 + rowHeight).strokeColor('#e9dcc2').lineWidth(0.5).stroke();
  return rowHeight;
}

function drawTotalsPanel(doc, y, totalRows, fonts, theme = documentTheme()) {
  if (theme.name === 'boxed') {
    const h = Math.max(82, 18 + totalRows.length * 17);
    doc.rect(338, y, 221, h).fill(theme.secondary).strokeColor(theme.accent).lineWidth(0.9).stroke();
    totalRows.forEach((row, index) => {
      const rowY = y + 13 + index * 17;
      const isLast = index === totalRows.length - 1;
      doc.fillColor(theme.ink).font(isLast ? fonts.bold : row[3]).fontSize(isLast ? 10 : 9)
        .text(row[0], 348, rowY, { width: 92 })
        .text(row[1], 450, rowY, { width: 92, align: 'right' });
    });
    return;
  }
  if (theme.name === 'classic') {
    const h = Math.max(66, 22 + totalRows.length * 15);
    doc.rect(332, y, 227, h).strokeColor(theme.ink).lineWidth(0.9).stroke();
    doc.rect(332, y, 227, 19).strokeColor(theme.ink).lineWidth(0.6).stroke();
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(8.5).text('TOTALS', 344, y + 6, { width: 190, align: 'center' });
    totalRows.forEach((row, index) => {
      const rowY = y + 26 + index * 15;
      doc.fillColor(row[2]).font(row[3]).fontSize(PDF_BODY_FONT_SIZE).text(row[0], 348, rowY, { width: 92 });
      doc.text(row[1], 448, rowY, { width: 92, align: 'right' });
    });
    return;
  }
  if (theme.name === 'elegant') {
    const h = Math.max(66, 22 + totalRows.length * 15);
    doc.rect(312, y, 247, h).fill('#fffdf8').strokeColor(theme.secondary).lineWidth(0.8).stroke();
    doc.rect(312, y, 5, h).fill(theme.secondary);
    totalRows.forEach((row, index) => {
      const rowY = y + 10 + index * 15;
      doc.fillColor(row[2]).font(row[3]).fontSize(index === totalRows.length - 1 ? 9 : PDF_BODY_FONT_SIZE).text(row[0], 330, rowY, { width: 95 });
      doc.text(row[1], 444, rowY, { width: 92, align: 'right' });
    });
    return;
  }
  const h = Math.max(72, 24 + totalRows.length * 15);
  doc.roundedRect(316, y, 243, h, 13).fill(theme.primary);
  doc.roundedRect(316, y, 243, 8, 4).fill(theme.secondary);
  totalRows.forEach((row, index) => {
    const rowY = y + 13 + index * 15;
    const isLast = index === totalRows.length - 1;
    doc.fillColor(isLast ? '#ffffff' : '#d9edf2').font(isLast ? fonts.bold : row[3]).fontSize(isLast ? 9 : PDF_BODY_FONT_SIZE).text(row[0], 334, rowY, { width: 96 });
    doc.text(row[1], 448, rowY, { width: 88, align: 'right' });
  });
}

function bankDetailLines(businessProfile = emptyBusinessProfile()) {
  const lines = [];
  if (businessProfile.accountHolderName) lines.push(`A/C Holder: ${businessProfile.accountHolderName}`);
  if (businessProfile.accountNumber) lines.push(`A/C No.: ${businessProfile.accountNumber}`);
  if (businessProfile.bankName) lines.push(`Bank: ${businessProfile.bankName}`);
  if (businessProfile.branchName) lines.push(`Branch: ${businessProfile.branchName}`);
  if (businessProfile.ifsc) lines.push(`IFSC: ${businessProfile.ifsc}`);
  if (businessProfile.upiId) lines.push(`UPI: ${businessProfile.upiId}`);
  return lines;
}

function drawPaymentDetails(doc, x, y, fonts, theme, businessProfile = emptyBusinessProfile()) {
  const lines = bankDetailLines(businessProfile);
  const bankText = lines.join('\n');
  if (theme.name === 'boxed') {
    const bankW = 250;
    const qrSize = 58;
    let bankHeight = 0;
    if (lines.length > 0) {
      doc.fillColor(theme.primary).font(fonts.bold).fontSize(8.8).text('Bank Details', x, y, { width: bankW });
      bankHeight = 15 + drawTextRun(doc, bankText, x, y + 15, bankW, fonts, { fontSize: PDF_BODY_FONT_SIZE, color: theme.ink, lineGap: 1 });
    }
    if (businessProfile.qrBase64) {
      const qrY = lines.length > 0 ? y + bankHeight + 8 : y;
      drawProfileImage(doc, businessProfile.qrBase64, x, qrY, { fit: [qrSize, qrSize] });
      doc.fillColor(theme.muted).font(fonts.regular).fontSize(7).text('Payment QR', x, qrY + qrSize + 2, { width: qrSize, align: 'center' });
      return bankHeight + qrSize + 18;
    }
    return bankHeight;
  }
  const bankHeight = lines.length > 0
    ? 14 + Math.max(0, textRunHeight(doc, bankText, 220, fonts, { fontSize: PDF_BODY_FONT_SIZE, lineGap: 1 }))
    : 0;
  if (lines.length > 0) {
    doc.fillColor(theme.primary).font(fonts.bold).fontSize(8.5).text('Bank Details', x, y, { width: 220 });
    drawTextRun(doc, bankText, x, y + 14, 220, fonts, { fontSize: PDF_BODY_FONT_SIZE, color: theme.ink, lineGap: 1 });
  }
  if (businessProfile.qrBase64) {
    const qrY = lines.length > 0 ? y + bankHeight + 10 : y;
    const qrSize = theme.name === 'boxed' ? 48 : 58;
    drawProfileImage(doc, businessProfile.qrBase64, x, qrY, { fit: [qrSize, qrSize] });
    doc.fillColor(theme.muted).font(fonts.regular).fontSize(7).text('Payment QR', x, qrY + qrSize + 2, { width: qrSize, align: 'center' });
    return bankHeight + qrSize + 20;
  }
  return bankHeight;
}

function totalsPanelHeight(totalRows, theme = documentTheme()) {
  if (theme.name === 'boxed') return Math.max(82, 18 + totalRows.length * 17);
  if (theme.name === 'classic') return Math.max(66, 22 + totalRows.length * 15);
  if (theme.name === 'elegant') return Math.max(66, 22 + totalRows.length * 15);
  return Math.max(72, 24 + totalRows.length * 15);
}

function drawDocumentClosing(doc, y, {
  amountValue,
  notes,
  totalRows,
  fonts,
  theme,
  businessProfile,
}) {
  const metrics = documentMetrics(theme);
  const totalsY = y;
  drawTotalsPanel(doc, totalsY, totalRows, fonts, theme);
  const totalsH = totalsPanelHeight(totalRows, theme);

  if (theme.name === 'boxed') {
    const termsText = notes || businessProfile.terms || 'Thank you for the business';
    doc.fillColor(theme.muted).font(fonts.regular).fontSize(9).text('Amount in words', metrics.left + 10, y + 12, { width: 260 });
    doc.fillColor(theme.ink).font(fonts.regular).fontSize(PDF_BODY_FONT_SIZE).text(amountInWords(amountValue), metrics.left + 10, y + 28, { width: 260, height: 24 });
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(9.5).text('Terms & Conditions', metrics.left + 10, y + 62, { width: 260 });
    drawTextRun(doc, termsText, metrics.left + 10, y + 78, 260, fonts, {
      fontSize: PDF_BODY_FONT_SIZE,
      color: theme.muted,
      lineGap: 2,
      height: 46,
      ellipsis: true,
    });
  } else {
    doc.fillColor(theme.primary).font(fonts.bold).fontSize(8.5).text('Amount in words', metrics.left, y + 2);
    doc.fillColor(theme.ink).font(fonts.regular).fontSize(PDF_BODY_FONT_SIZE).text(amountInWords(amountValue), metrics.left, y + 16, { width: 260, height: 24 });
    if (notes) doc.fillColor(theme.muted).font(fonts.regular).fontSize(PDF_BODY_FONT_SIZE).text(notes, metrics.left, y + 43, { width: 260, height: 46 });
  }

  const lowerY = Math.max(y + 96, totalsY + totalsH + 18);
  const paymentHeight = drawPaymentDetails(doc, theme.name === 'boxed' ? metrics.left + 10 : metrics.left, lowerY, fonts, theme, businessProfile);

  const signatureX = metrics.right - 154;
  const signatureMaxY = theme.name === 'boxed' ? 704 : 716;
  const signatureY = Math.min(Math.max(lowerY + Math.max(28, paymentHeight + 12), totalsY + totalsH + 36), signatureMaxY);
  if (businessProfile.signatureBase64) {
    doc.save();
    doc.rect(signatureX + 4, signatureY - 4, 136, 44).fill('#ffffff');
    doc.restore();
    drawProfileImage(doc, businessProfile.signatureBase64, signatureX + 8, signatureY, { fit: [128, 38] });
  }
  doc.moveTo(signatureX, signatureY + 44).lineTo(signatureX + 144, signatureY + 44).strokeColor('#9aa3aa').lineWidth(0.5).stroke();
  doc.fillColor(theme.primary).font(fonts.bold).fontSize(8.5).text('Authorized Signature', signatureX, signatureY + 50, { width: 144, align: 'center', lineBreak: false });
}

function resetDocumentPage(doc, theme) {
  doc.rect(0, 0, doc.page.width, doc.page.height).fill(theme.page);
  if (theme.name === 'elegant') {
    doc.rect(0, 0, 86, doc.page.height).fill(theme.primary);
    doc.rect(86, 0, 5, doc.page.height).fill(theme.secondary);
  } else if (theme.name === 'boxed') {
    doc.rect(18, 18, 559, 806).strokeColor(theme.accent).lineWidth(0.8).stroke();
  }
}

function continueDocumentTablePage(doc, title, event, number, fonts, businessProfile = emptyBusinessProfile()) {
  const theme = documentTheme(businessProfile);
  if (theme.name === 'boxed') {
    writeDocumentHeader(doc, title, event, number, fonts, businessProfile);
    const y = documentContinuationTableY(theme);
    tableHeader(doc, y, fonts, theme);
    return y + 28;
  }
  resetDocumentPage(doc, theme);
  const y = documentContinuationTableY(theme);
  tableHeader(doc, y, fonts, theme);
  return y + (theme.name === 'modern' ? 32 : 26);
}

function continueDocumentContentPage(doc, title, event, number, fonts, businessProfile = emptyBusinessProfile()) {
  const theme = documentTheme(businessProfile);
  if (theme.name === 'boxed') {
    writeDocumentHeader(doc, title, event, number, fonts, businessProfile);
    return documentContinuationTableY(theme);
  }
  resetDocumentPage(doc, theme);
  return 44;
}

function drawDocumentFooter(doc, fonts, theme, businessProfile, { thankYou = false, pageNumber = 1, pageCount = 1 } = {}) {
  const metrics = documentMetrics(theme);
  const footerY = theme.name === 'boxed' ? 760 : 778;
  const thanksY = theme.name === 'boxed' ? 744 : 762;
  const brandY = theme.name === 'boxed' ? 766 : 786;
  doc.moveTo(metrics.left, footerY).lineTo(metrics.right, footerY).strokeColor(theme.name === 'classic' || theme.name === 'boxed' ? '#9ca3af' : '#d6dde0').lineWidth(0.5).stroke();
  if (thankYou) {
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(9.5)
      .text('Thank you for the business', metrics.left, thanksY, { width: metrics.width, align: 'center', lineBreak: false });
  }
  const showPageCount = pageCount > 1;
  const brandWidth = showPageCount ? metrics.width - 92 : metrics.width;
  doc.fillColor(theme.muted).font(fonts.regular).fontSize(7).text(
    `${caterProPdfFooter} | ${prettyDate(new Date().toISOString().slice(0, 10))}`,
    metrics.left,
    brandY,
    { width: brandWidth, height: 10, align: 'center', lineBreak: false, link: caterProBrandUrl, underline: false },
  );
  if (showPageCount) {
    doc.fillColor(theme.muted).font(fonts.bold).fontSize(7).text(
      `Page ${pageNumber} of ${pageCount}`,
      metrics.right - 88,
      brandY,
      { width: 88, height: 10, align: 'right', lineBreak: false },
    );
  }
}

function drawBufferedDocumentFooters(doc, fonts, theme, businessProfile, options = {}) {
  const range = doc.bufferedPageRange();
  for (let index = 0; index < range.count; index += 1) {
    doc.switchToPage(range.start + index);
    drawDocumentFooter(doc, fonts, theme, businessProfile, {
      ...options,
      pageNumber: index + 1,
      pageCount: range.count,
    });
  }
}

function boxedInvoiceBusinessProfile(profile = emptyBusinessProfile()) {
  return { ...emptyBusinessProfile(), ...(profile || {}), documentTemplate: 'boxed' };
}

function generateEventPdf({ res, db, event, type, businessProfile = emptyBusinessProfile(), clients = [], disposition = 'attachment' }) {
  const isInvoice = type === 'invoice';
  const title = isInvoice ? 'INVOICE' : 'QUOTATION';
  const number = documentNumber(isInvoice ? 'INV' : 'QUOTE', event);
  const totals = eventTotals(event);
  const documentSubtotal = Number(totals.menuTotal || 0) + Number(totals.addOnTotal || 0);
  const gst = gstBreakdown(documentSubtotal, businessProfile);
  const grandTotal = gst.total;
  const balanceDue = Math.max(0, grandTotal - totals.paid - totals.discount);
  const eventClient = clients.find((client) => normalizeMobile(client.mobile) === normalizeMobile(event.mobile));
  const documentEvent = {
    ...event,
    clientAddress: event.clientAddress || eventClient?.address || eventClient?.city || '',
    clientGst: event.clientGst || eventClient?.gst || '',
  };
  const doc = new PDFDocument({ size: 'A4', margin: 36, bufferPages: true, info: { Title: `${title} - ${event.name}` } });
  const fonts = configurePdfFonts(doc);
  const theme = documentTheme(businessProfile);
  res.setHeader('Content-Type', 'application/pdf');
  setPdfAttachment(res, [title, eventClientName(event), event.name || event.id, number], disposition);
  doc.pipe(res);

  writeDocumentHeader(doc, title, documentEvent, number, fonts, businessProfile);
  const infoBottom = documentInfoSection(doc, title, documentEvent, number, fonts, businessProfile, isInvoice);
  const metrics = documentMetrics(theme);
  let y = Math.max(metrics.tableY, infoBottom);
  tableHeader(doc, y, fonts, theme);
  y += theme.name === 'modern' ? 32 : theme.name === 'boxed' ? 28 : 26;

  let shaded = false;
  let rowNumber = 1;
  for (const date of sortedEventDates(event.dates)) {
    const visibleSlots = sortedVisibleMenuSlots(date.menuSlots);
    if (visibleSlots.length === 0) continue;
    y = ensurePageSpace(doc, y, 22, () => continueDocumentTablePage(doc, title, documentEvent, number, fonts, businessProfile), theme);
    doc.fillColor(theme.primary).font(fonts.bold).fontSize(8.8).text(`${prettyDate(date.date)}${date.label ? ` - ${date.label}` : ''}`, metrics.left, y, { width: metrics.width });
    y += 15;
    for (const slot of visibleSlots) {
      const amount = Number(slot.pax || 0) * Number(slot.pricePerPax || 0);
      const rowData = {
        index: String(rowNumber),
        description: `${slot.type || 'Meal'}${slot.time ? ` (${slot.time})` : ''}`,
        qty: `${slot.pax || ''}`,
        rate: money(slot.pricePerPax),
        amount: money(amount),
      };
      const rowHeight = invoiceRowHeight(doc, rowData, fonts, theme);
      y = ensurePageSpace(doc, y, rowHeight + 6, () => continueDocumentTablePage(doc, title, documentEvent, number, fonts, businessProfile), theme);
      drawInvoiceRow(doc, y, fonts, rowData, shaded, theme);
      rowNumber += 1;
      shaded = !shaded;
      y += rowHeight;
    }
  }
  if ((event.addOns || []).length > 0) {
    y = ensurePageSpace(doc, y, 22, () => continueDocumentTablePage(doc, title, documentEvent, number, fonts, businessProfile), theme);
    doc.fillColor(theme.primary).font(fonts.bold).fontSize(8.8).text('Event Add-ons', metrics.left, y);
    y += 15;
    for (const addOn of event.addOns || []) {
      const rowData = {
        index: String(rowNumber),
        description: addOn.title || 'Add-on',
        qty: '',
        rate: '',
        amount: money(addOn.cost),
      };
      const rowHeight = invoiceRowHeight(doc, rowData, fonts, theme);
      y = ensurePageSpace(doc, y, rowHeight + 6, () => continueDocumentTablePage(doc, title, documentEvent, number, fonts, businessProfile), theme);
      drawInvoiceRow(doc, y, fonts, rowData, shaded, theme);
      rowNumber += 1;
      shaded = !shaded;
      y += rowHeight;
    }
  }

  const totalRows = [
    ['Menu Total', money(totals.menuTotal), '#202124', fonts.regular],
  ];
  if (totals.addOnTotal > 0) totalRows.push(['Add-ons Total', money(totals.addOnTotal), '#202124', fonts.regular]);
  if (gst.enabled) gst.rows.forEach((row) => totalRows.push([row[0], money(row[1]), '#202124', fonts.regular]));
  totalRows.push(['Grand Total', money(grandTotal), theme.primary, fonts.bold]);
  if (isInvoice) {
    totalRows.push(['Paid Till Now', money(totals.paid), '#0b6b3a', fonts.regular]);
    if (totals.discount > 0) totalRows.push(['Settled Discount', money(totals.discount), '#0b6b3a', fonts.regular]);
    totalRows.push(['Balance Due', money(balanceDue), balanceDue > 0 ? '#ba1a1a' : '#0b6b3a', fonts.bold]);
  }
  y = ensurePageSpace(doc, y, Math.max(184, totalsPanelHeight(totalRows, theme) + 126), () => continueDocumentContentPage(doc, title, documentEvent, number, fonts, businessProfile), theme);
  const terms = isInvoice ? '' : 'Thank you for the business';
  drawDocumentClosing(doc, y + 4, {
    amountValue: isInvoice ? balanceDue || grandTotal : grandTotal,
    notes: terms,
    totalRows,
    fonts,
    theme,
    businessProfile,
  });
  drawBufferedDocumentFooters(doc, fonts, theme, businessProfile, { thankYou: isInvoice });
  doc.end();
}

function generateManualInvoicePdf({ res, invoice, businessProfile = emptyBusinessProfile(), disposition = 'attachment' }) {
  const number = invoice.invoiceNumber || documentNumber('INV', { id: invoice.id });
  const event = {
    id: invoice.id,
    name: invoice.eventName || 'Manual Invoice',
    primaryClient: invoice.clientName || 'Customer',
    mobile: invoice.mobile || '',
    clientAddress: invoice.clientAddress || '',
    clientGst: invoice.clientGst || '',
    venue: invoice.venue || '',
    invoiceDate: invoice.invoiceDate || '',
    dates: invoice.eventDate ? [{ date: invoice.eventDate }] : [],
  };
  const doc = new PDFDocument({ size: 'A4', margin: 36, bufferPages: true, info: { Title: `INVOICE - ${event.name}` } });
  const fonts = configurePdfFonts(doc);
  const theme = documentTheme(businessProfile);
  res.setHeader('Content-Type', 'application/pdf');
  setPdfAttachment(res, ['INVOICE', invoice.clientName || 'Client', invoice.eventName || invoice.id, number], disposition);
  doc.pipe(res);

  writeDocumentHeader(doc, 'INVOICE', event, number, fonts, businessProfile);
  const infoBottom = documentInfoSection(doc, 'Invoice', event, number, fonts, businessProfile, true);
  const metrics = documentMetrics(theme);
  let y = Math.max(metrics.tableY, infoBottom);
  tableHeader(doc, y, fonts, theme);
  y += theme.name === 'modern' ? 32 : theme.name === 'boxed' ? 28 : 26;
  let shaded = false;
  let rowNumber = 1;
  for (const finalItem of invoice.items || []) {
    const rowData = {
      index: String(rowNumber),
      description: finalItem.title || 'Invoice item',
      qty: finalItem.quantity ? String(finalItem.quantity) : '',
      rate: finalItem.rate ? money(finalItem.rate) : '',
      amount: money(finalItem.amount),
    };
    const rowHeight = invoiceRowHeight(doc, rowData, fonts, theme);
    y = ensurePageSpace(doc, y, rowHeight + 6, () => continueDocumentTablePage(doc, 'INVOICE', event, number, fonts, businessProfile), theme);
    drawInvoiceRow(doc, y, fonts, rowData, shaded, theme);
    rowNumber += 1;
    shaded = !shaded;
    y += rowHeight;
  }

  const baseSubtotal = Number(invoice.subtotal ?? invoice.total ?? 0) || (invoice.items || []).reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const gst = gstBreakdown(baseSubtotal, businessProfile);
  const grandTotal = gst.total;
  const paid = Number(invoice.advance || 0);
  const settlement = Number(invoice.settlement || 0);
  const pending = Math.max(0, grandTotal - paid - settlement);

  const totalRows = [
    ['Subtotal', money(baseSubtotal), '#202124', fonts.regular],
    ...gst.rows.map((row) => [row[0], money(row[1]), '#202124', fonts.regular]),
    ['Grand Total', money(grandTotal), theme.primary, fonts.bold],
    ['Advance / Paid', money(paid), '#0b6b3a', fonts.regular],
  ];
  if (settlement > 0) totalRows.push(['Settlement', money(settlement), '#0b6b3a', fonts.regular]);
  totalRows.push(['Pending', money(pending), pending > 0 ? '#ba1a1a' : '#0b6b3a', fonts.bold]);
  y = ensurePageSpace(doc, y, Math.max(184, totalsPanelHeight(totalRows, theme) + 126), () => continueDocumentContentPage(doc, 'INVOICE', event, number, fonts, businessProfile), theme);
  drawDocumentClosing(doc, y + 4, {
    amountValue: pending || grandTotal,
    notes: invoice.notes,
    totalRows,
    fonts,
    theme,
    businessProfile,
  });
  drawBufferedDocumentFooters(doc, fonts, theme, businessProfile, { thankYou: true });
  doc.end();
}

function generateAttendancePdfOld({ res, records, employees, month, businessProfile = emptyBusinessProfile() }) {
  const doc = new PDFDocument({ size: 'A4', margin: 32, info: { Title: `Attendance - ${month}` } });
  const fonts = configurePdfFonts(doc);
  const theme = documentTheme(businessProfile);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="ATTENDANCE-${month}.pdf"`);
  doc.pipe(res);
  doc.rect(0, 0, doc.page.width, doc.page.height).fill('#ffffff');
  doc.roundedRect(32, 28, 531, 58, 8).fill(theme.primary);
  doc.fillColor('white').font(fonts.bold).fontSize(18).text('Attendance Sheet', 48, 44);
  doc.font(fonts.regular).fontSize(9).text(`${businessProfile.businessName || 'CaterPro'} | ${month}`, 360, 48, { width: 180, align: 'right' });
  const byEmployee = new Map();
  for (const employee of employees) byEmployee.set(employee.id, { employee, present: 0, absent: 0, partial: 0, hours: 0, salary: 0 });
  for (const record of records) {
    if (!byEmployee.has(record.employeeId)) byEmployee.set(record.employeeId, { employee: { name: record.employeeName, designation: '', payPerDay: record.payPerDay, payPerHour: record.payPerHour }, present: 0, absent: 0, partial: 0, hours: 0, salary: 0 });
    const bucket = byEmployee.get(record.employeeId);
    bucket[record.status] = (bucket[record.status] || 0) + 1;
    bucket.hours += Number(record.hours || 0);
    const partialPay = Number(record.payPerHour || bucket.employee.payPerHour || 0) * Number(record.hours || 0);
    bucket.salary += record.status === 'present' ? Math.round(Number(record.payPerDay || bucket.employee.payPerDay || 0)) : record.status === 'partial' ? Math.round(partialPay) : 0;
  }
  let y = 112;
  const header = () => {
    doc.roundedRect(32, y, 531, 24, 4).fill(theme.primary);
    doc.fillColor('white').font(fonts.bold).fontSize(PDF_BODY_FONT_SIZE)
      .text('Employee', 42, y + 7, { width: 142 })
      .text('Present', 205, y + 7, { width: 48, align: 'right' })
      .text('Absent', 270, y + 7, { width: 48, align: 'right' })
      .text('Partial', 334, y + 7, { width: 48, align: 'right' })
      .text('Hours', 400, y + 7, { width: 48, align: 'right' })
      .text('Salary', 478, y + 7, { width: 62, align: 'right' });
    y += 30;
  };
  header();
  for (const { employee, present, absent, partial, hours, salary } of byEmployee.values()) {
    if (y > 760) {
      doc.addPage();
      doc.rect(0, 0, doc.page.width, doc.page.height).fill('#ffffff');
      y = 42;
      header();
    }
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(8.5).text(employee.name || '-', 42, y, { width: 142 });
    doc.fillColor(theme.muted).font(fonts.regular).fontSize(PDF_BODY_FONT_SIZE).text(employee.designation || '', 42, y + 11, { width: 142 });
    doc.fillColor(theme.ink).font(fonts.regular).fontSize(8.5)
      .text(String(present || 0), 205, y, { width: 48, align: 'right' })
      .text(String(absent || 0), 270, y, { width: 48, align: 'right' })
      .text(String(partial || 0), 334, y, { width: 48, align: 'right' })
      .text(String(hours || 0), 400, y, { width: 48, align: 'right' })
      .text(money(salary || 0), 478, y, { width: 62, align: 'right' });
    doc.moveTo(32, y + 24).lineTo(563, y + 24).strokeColor('#d7dde2').lineWidth(0.5).stroke();
    y += 30;
  }
  if (records.length === 0) doc.fillColor(theme.muted).font(fonts.regular).fontSize(11).text('No attendance records for this month.', 42, y + 10);
  doc.fillColor('#6b7280').font(fonts.regular).fontSize(6.6).text(caterProPdfFooter, 42, 575, { width: 510, align: 'center', lineBreak: false, link: caterProBrandUrl, underline: false });
  doc.end();
}

function generateAttendancePdf({ res, records, employees, month, businessProfile = emptyBusinessProfile() }) {
  const doc = new PDFDocument({ size: 'A4', layout: 'landscape', margin: 22, info: { Title: `Attendance - ${month}` } });
  const fonts = configurePdfFonts(doc);
  const theme = documentTheme(businessProfile);
  const [year, rawMonth] = String(month).split('-').map(Number);
  const daysInMonth = new Date(year, rawMonth, 0).getDate();
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="ATTENDANCE-${month}.pdf"`);
  doc.pipe(res);
  doc.rect(0, 0, doc.page.width, doc.page.height).fill('#ffffff');
  doc.roundedRect(22, 18, 798, 42, 6).fill(theme.primary);
  doc.fillColor('white').font(fonts.bold).fontSize(16).text('Attendance Sheet', 36, 31);
  doc.font(fonts.regular).fontSize(PDF_BODY_FONT_SIZE).text(`${businessProfile.businessName || 'CaterPro'} - ${month}`, 610, 33, { width: 180, align: 'right' });

  const byEmployee = new Map();
  for (const employee of employees) byEmployee.set(employee.id, { employee, days: {}, present: 0, absent: 0, partial: 0, hours: 0, salary: 0 });
  for (const record of records) {
    if (!byEmployee.has(record.employeeId)) byEmployee.set(record.employeeId, { employee: { name: record.employeeName, designation: '', payPerDay: record.payPerDay, payPerHour: record.payPerHour }, days: {}, present: 0, absent: 0, partial: 0, hours: 0, salary: 0 });
    const bucket = byEmployee.get(record.employeeId);
    const day = Number(String(record.date || '').slice(-2));
    if (day > 0) bucket.days[day] = record;
    bucket[record.status] = (bucket[record.status] || 0) + 1;
    bucket.hours += Number(record.hours || 0);
    const partialPay = Number(record.payPerHour || bucket.employee.payPerHour || 0) * Number(record.hours || 0);
    bucket.salary += record.status === 'present' ? Math.round(Number(record.payPerDay || bucket.employee.payPerDay || 0)) : record.status === 'partial' ? Math.round(partialPay) : 0;
  }

  const left = 22;
  const nameW = 100;
  const dayW = 16;
  const pW = 20;
  const aW = 20;
  const hW = 28;
  const salaryW = 55;
  const tableW = nameW + daysInMonth * dayW + pW + aW + hW + salaryW;
  let y = 78;
  const dayText = (record) => {
    if (!record) return '-';
    if (record.status === 'present') return 'P';
    if (record.status === 'absent') return 'A';
    const hours = Number(record.hours || 0);
    return Number.isInteger(hours) ? String(hours) : hours.toFixed(1);
  };
  const header = () => {
    doc.rect(left, y, tableW, 20).fill(theme.primary);
    doc.fillColor('white').font(fonts.bold).fontSize(6.2).text('Employee', left + 4, y + 7, { width: nameW - 6 });
    let x = left + nameW;
    for (let day = 1; day <= daysInMonth; day++) {
      doc.text(String(day), x, y + 7, { width: dayW, align: 'center' });
      x += dayW;
    }
    doc.text('P', x, y + 7, { width: pW, align: 'center' }); x += pW;
    doc.text('A', x, y + 7, { width: aW, align: 'center' }); x += aW;
    doc.text('Hrs', x, y + 7, { width: hW, align: 'center' }); x += hW;
    doc.text('Salary', x, y + 7, { width: salaryW, align: 'right' });
    y += 20;
  };
  header();
  for (const { employee, days, present, absent, hours, salary } of byEmployee.values()) {
    if (y > 555) {
      doc.addPage();
      doc.rect(0, 0, doc.page.width, doc.page.height).fill('#ffffff');
      y = 28;
      header();
    }
    const rowH = 19;
    doc.rect(left, y, tableW, rowH).fill(y % 2 ? '#ffffff' : '#f7fafc').strokeColor('#d7dde2').lineWidth(0.35).stroke();
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(6.7).text(employee.name || '-', left + 4, y + 4, { width: nameW - 8, height: 8 });
    doc.fillColor(theme.muted).font(fonts.regular).fontSize(5.5).text(employee.designation || '', left + 4, y + 12, { width: nameW - 8, height: 6 });
    let x = left + nameW;
    doc.fillColor(theme.ink).font(fonts.regular).fontSize(6.2);
    for (let day = 1; day <= daysInMonth; day++) {
      doc.text(dayText(days[day]), x, y + 6, { width: dayW, align: 'center' });
      doc.moveTo(x, y).lineTo(x, y + rowH).strokeColor('#e4e8eb').lineWidth(0.25).stroke();
      x += dayW;
    }
    doc.font(fonts.bold).text(String(present || 0), x, y + 6, { width: pW, align: 'center' }); x += pW;
    doc.text(String(absent || 0), x, y + 6, { width: aW, align: 'center' }); x += aW;
    doc.text(String(hours || 0), x, y + 6, { width: hW, align: 'center' }); x += hW;
    doc.text(money(salary || 0), x, y + 6, { width: salaryW, align: 'right' });
    y += rowH;
  }
  if (records.length === 0) doc.fillColor(theme.muted).font(fonts.regular).fontSize(11).text('No attendance records for this month.', 42, y + 10);
  doc.end();
}

function parseIsoDateValue(value) {
  if (!value) return null;
  const parsed = new Date(`${value}T00:00:00`);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function eventFirstDateValue(event) {
  const dates = asArray(event.dates).map((date) => parseIsoDateValue(date.date)).filter(Boolean).sort((a, b) => a - b);
  return dates[0] || null;
}

function sameMonthValue(date, month) {
  return date && date.getFullYear() === month.getFullYear() && date.getMonth() === month.getMonth();
}

function isoDateFromDate(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function parseStrictIsoDate(value) {
  const text = String(value || '').trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return null;
  const [year, month, day] = text.split('-').map(Number);
  const date = new Date(year, month - 1, day);
  return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day ? date : null;
}

function reportRangeFromQuery(query = {}) {
  const today = parseStrictIsoDate(todayIso());
  const hasCustomRange = query.startDate || query.endDate;
  let startDate;
  let endDate;
  let label;
  let fileKey;
  if (hasCustomRange) {
    startDate = parseStrictIsoDate(query.startDate);
    endDate = parseStrictIsoDate(query.endDate);
    if (!startDate || !endDate) return { error: 'Start date and to-date must be valid dates' };
    if (endDate > today) endDate = today;
    label = `${prettyDate(isoDateFromDate(startDate))} to ${prettyDate(isoDateFromDate(endDate))}`;
    fileKey = `${isoDateFromDate(startDate)}-to-${isoDateFromDate(endDate)}`;
  } else {
    const [yearText, monthText] = String(query.month || todayIso().slice(0, 7)).split('-');
    const year = Number(yearText || today.getFullYear());
    const month = Number(monthText || today.getMonth() + 1);
    startDate = new Date(year, month - 1, 1);
    endDate = new Date(year, month, 0);
    if (endDate > today) endDate = today;
    label = startDate.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
    fileKey = `${startDate.getFullYear()}-${String(startDate.getMonth() + 1).padStart(2, '0')}`;
  }
  if (startDate > endDate) return { error: 'Start date cannot be after to-date' };
  const maxEndDate = new Date(startDate);
  maxEndDate.setDate(maxEndDate.getDate() + 365);
  if (endDate > maxEndDate) return { error: 'Report date range cannot exceed 1 year' };
  return {
    startDate,
    endDate,
    startKey: isoDateFromDate(startDate),
    endKey: isoDateFromDate(endDate),
    label,
    fileKey,
  };
}

function eventMemberTotal(event) {
  return asArray(event.dates).reduce((dateSum, date) => dateSum + asArray(date.menuSlots).reduce((slotSum, slot) => slotSum + Number(slot.pax || 0), 0), 0);
}

function generateMonthlyReportPdf({ res, events, manualInvoices = [], range, businessProfile = emptyBusinessProfile(), disposition = 'attachment' }) {
  const reportRange = range || reportRangeFromQuery({});
  const reportLabel = reportRange.label || `${prettyDate(reportRange.startKey)} to ${prettyDate(reportRange.endKey)}`;
  const rangeContains = (value) => {
    const date = parseStrictIsoDate(value);
    return date && date >= reportRange.startDate && date <= reportRange.endDate;
  };
  const monthEvents = asArray(events).filter((event) => asArray(event.dates).some((date) => rangeContains(date.date)));
  const monthPayments = asArray(events).flatMap((event) => asArray(event.payments)
    .filter((payment) => rangeContains(payment.date))
    .map((payment) => ({ ...payment, eventName: event.name || 'Event', client: event.primaryClient || event.mobile || '' })));
  const monthManualInvoices = asArray(manualInvoices).filter((invoice) => rangeContains(invoice.invoiceDate));
  const bookedRevenue = monthEvents.reduce((sum, event) => sum + eventTotals(event).total, 0);
  const collected = monthPayments.reduce((sum, payment) => sum + Number(payment.amount || 0), 0)
    + monthManualInvoices.reduce((sum, invoice) => sum + Number(invoice.paidAmount || 0), 0);
  const outstanding = monthEvents.reduce((sum, event) => sum + eventTotals(event).balance, 0)
    + monthManualInvoices.reduce((sum, invoice) => {
      const subtotal = asArray(invoice.items).reduce((itemSum, item) => itemSum + Number(item.amount || 0), 0);
      const paid = Number(invoice.paidAmount || 0) + Number(invoice.settlementAmount || 0);
      return sum + Math.max(0, subtotal - paid);
    }, 0);
  const netProfit = collected - outstanding;
  const clients = new Set(monthEvents.map((event) => normalizeMobile(event.mobile)).filter(Boolean));
  const members = monthEvents.reduce((sum, event) => sum + eventMemberTotal(event), 0);
  const avgMembers = monthEvents.length ? Math.round(members / monthEvents.length) : 0;
  const pendingEvents = monthEvents.filter((event) => eventTotals(event).balance > 0);

  const doc = new PDFDocument({ size: 'A4', margin: 24, info: { Title: `Report - ${reportLabel}` }, autoFirstPage: false });
  const fonts = configurePdfFonts(doc);
  const pageW = 595.28;
  const pageH = 841.89;
  const left = 28;
  const right = pageW - 28;
  const width = right - left;
  let pageNo = 0;
  let y = 0;
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `${disposition}; filename="monthly-report-${reportRange.fileKey}.pdf"`);
  doc.pipe(res);

  function addPage() {
    doc.addPage({ size: 'A4', margin: 24 });
    pageNo += 1;
    doc.rect(0, 0, pageW, pageH).fill('#ffffff');
    doc.fillColor('#111827').font(fonts.bold).fontSize(18).text('Report', left, 24, { width: 220 });
    doc.fillColor('#4b5563').font(fonts.regular).fontSize(PDF_BODY_FONT_SIZE).text(`${reportLabel} - ${businessProfile.businessName || 'CaterPro'} - Page ${pageNo}`, right - 270, 29, { width: 270, align: 'right' });
    doc.moveTo(left, 52).lineTo(right, 52).strokeColor('#d1d5db').lineWidth(0.6).stroke();
    doc.fillColor('#6b7280').font(fonts.regular).fontSize(6.8).text(caterProPdfFooter, left, pageH - 38, { width, align: 'center', lineBreak: false, link: caterProBrandUrl, underline: false });
    y = 68;
  }
  function ensure(height) {
    if (y + height > pageH - 34) addPage();
  }
  function section(title) {
    ensure(28);
    doc.roundedRect(left, y, width, 20, 4).fill('#eef2f7');
    doc.fillColor('#111827').font(fonts.bold).fontSize(10.5).text(title, left + 8, y + 5, { width: width - 16 });
    y += 28;
  }
  function metric(x, w, title, value, note, color = '#06445d') {
    doc.roundedRect(x, y, w, 58, 5).fill('#f8fafc').strokeColor('#d9e2ec').lineWidth(0.5).stroke();
    doc.fillColor('#6b7280').font(fonts.bold).fontSize(PDF_BODY_FONT_SIZE).text(title, x + 8, y + 8, { width: w - 16 });
    doc.fillColor(color).font(fonts.bold).fontSize(13).text(value, x + 8, y + 25, { width: w - 16, ellipsis: true });
    doc.fillColor('#6b7280').font(fonts.regular).fontSize(7).text(note, x + 8, y + 43, { width: w - 16, ellipsis: true });
  }
  function row(cells, widths, opts = {}) {
    const h = opts.header ? 20 : 24;
    ensure(h);
    let x = left;
    if (opts.header) doc.rect(left, y, width, h).fill('#f3f4f6');
    cells.forEach((cell, index) => {
      doc.fillColor(opts.color || '#202124').font(opts.header ? fonts.bold : fonts.regular).fontSize(opts.header ? 8 : 7.5)
        .text(String(cell ?? ''), x + 4, y + 6, { width: widths[index] - 8, height: h - 8, ellipsis: true, align: opts.align?.[index] || 'left' });
      x += widths[index];
    });
    doc.moveTo(left, y + h).lineTo(right, y + h).strokeColor('#edf0f2').lineWidth(0.4).stroke();
    y += h;
  }

  addPage();
  const cardGap = 8;
  const cardW = (width - cardGap * 2) / 3;
  metric(left, cardW, 'COLLECTED', money(collected), `${monthPayments.length} event payments`, '#0f766e');
  metric(left + cardW + cardGap, cardW, 'BOOKED', money(bookedRevenue), `${monthEvents.length} events`, '#06445d');
  metric(left + (cardW + cardGap) * 2, cardW, 'OUTSTANDING', money(outstanding), `${pendingEvents.length} pending`, '#ba1a1a');
  y += 70;
  metric(left, cardW, 'NET POSITION', money(netProfit), netProfit >= 0 ? 'Positive cash position' : 'Pending exceeds collection', netProfit >= 0 ? '#0f766e' : '#ba1a1a');
  metric(left + cardW + cardGap, cardW, 'CLIENTS', `${clients.size}`, 'Unique event mobiles', '#1c7c8a');
  metric(left + (cardW + cardGap) * 2, cardW, 'AVG MEMBERS', `${avgMembers}`, `${members} total members`, '#7c3aed');
  y += 76;

  section('Events');
  row(['Date', 'Event', 'Client', 'Members', 'Booked', 'Paid', 'Discount', 'Balance'], [48, 122, 82, 48, 66, 58, 58, 66], { header: true, align: ['', '', '', 'right', 'right', 'right', 'right', 'right'] });
  for (const event of monthEvents) {
    const totals = eventTotals(event);
    row([eventFirstDateValue(event)?.toISOString().slice(0, 10) || '-', event.name || 'Event', event.primaryClient || event.mobile || '-', eventMemberTotal(event), money(totals.total), money(totals.paid), money(totals.discount), money(totals.balance)], [48, 122, 82, 48, 66, 58, 58, 66], { align: ['', '', '', 'right', 'right', 'right', 'right', 'right'] });
  }
  if (!monthEvents.length) row(['No events for this range'], [width]);

  section('Payments Collected');
  row(['Date', 'Event', 'Client', 'Mode', 'Reference', 'Amount'], [56, 132, 96, 62, 132, 72], { header: true, align: ['', '', '', '', '', 'right'] });
  for (const payment of monthPayments) {
    row([payment.date || '-', payment.eventName, payment.client || '-', payment.mode || '-', payment.reference || '-', money(payment.amount)], [56, 132, 96, 62, 132, 72], { align: ['', '', '', '', '', 'right'] });
  }
  if (!monthPayments.length) row(['No event payments collected in this range'], [width]);

  section('Manual Invoices');
  row(['Date', 'Invoice', 'Client', 'Total', 'Paid', 'Pending'], [58, 120, 148, 76, 76, 76], { header: true, align: ['', '', '', 'right', 'right', 'right'] });
  for (const invoice of monthManualInvoices) {
    const total = asArray(invoice.items).reduce((sum, item) => sum + Number(item.amount || 0), 0);
    const paid = Number(invoice.paidAmount || 0) + Number(invoice.settlementAmount || 0);
    row([invoice.invoiceDate || '-', invoice.invoiceNumber || invoice.id, invoice.clientName || '-', money(total), money(paid), money(Math.max(0, total - paid))], [58, 120, 148, 76, 76, 76], { align: ['', '', '', 'right', 'right', 'right'] });
  }
  if (!monthManualInvoices.length) row(['No manual invoices for this range'], [width]);
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

function menuPdfFontSize(businessProfile = emptyBusinessProfile()) {
  return Math.min(16, Math.max(10, Number(businessProfile.pdfMenuFontSize || 12) || 12));
}

function menuHeader(doc, event, date, fonts, businessProfile, pageLabel, pageNo) {
  const menuFontSize = menuPdfFontSize(businessProfile);
  doc.rect(0, 0, doc.page.width, doc.page.height).fill('#ffffff');
  doc.fillColor('#111827').font(fonts.bold).fontSize(16).text('EVENT MENU', 42, 36, { width: 180 });
  drawTextRun(doc, `${businessProfile.businessName || 'CaterPro'} | Page ${pageNo}`, 330, 38, 220, fonts, {
    fontSize: menuFontSize,
    color: '#4b5563',
    align: 'right',
    lineBreak: false,
  });
  drawTextRun(doc, pageLabel, 330, 54, 220, fonts, {
    fontSize: Math.max(8, menuFontSize - 1),
    color: '#4b5563',
    align: 'right',
    lineBreak: false,
  });
  doc.moveTo(42, 70).lineTo(553, 70).strokeColor('#9ca3af').lineWidth(0.7).stroke();

  const leftY = 84;
  const rightY = 84;
  const clientH = drawTextRun(doc, event.primaryClient || event.name || 'Customer', 42, leftY, 210, fonts, {
    fontSize: 10,
    color: '#111827',
    bold: true,
  });
  const mobileH = drawTextRun(doc, `Mobile: ${event.mobile || '-'}`, 42, leftY + clientH + 6, 240, fonts, {
    fontSize: menuFontSize,
    color: '#374151',
  });
  const eventH = drawTextRun(doc, `Event: ${event.name || '-'}`, 42, leftY + clientH + mobileH + 12, 240, fonts, {
    fontSize: menuFontSize,
    color: '#374151',
  });
  const dateText = `Date: ${prettyDate(date.date)}${date.label ? ` (${date.label})` : ''}`;
  const dateH = drawTextRun(doc, dateText, 330, rightY, 220, fonts, {
    fontSize: menuFontSize,
    color: '#374151',
    align: 'right',
  });
  const venueH = drawTextRun(doc, `Venue: ${event.venue || '-'}`, 330, rightY + dateH + 6, 220, fonts, {
    fontSize: menuFontSize,
    color: '#374151',
    align: 'right',
  });
  const bottom = Math.max(leftY + clientH + mobileH + 12 + eventH, rightY + dateH + 6 + venueH) + 14;
  doc.moveTo(42, bottom).lineTo(553, bottom).strokeColor('#d1d5db').lineWidth(0.6).stroke();
  return bottom + 16;
}

function menuItemText(item = {}) {
  return item.kannada && item.english ? `${item.kannada} / ${item.english}` : item.kannada || item.english || '';
}

function menuItemTextHeight(doc, item, width, fonts, fontSize = 12) {
  const text = menuItemText(item);
  return Math.max(fontSize + 3, textRunHeight(doc, text, width - 16, fonts, { fontSize, lineGap: 1 }) + 1);
}

function drawChefMenuItem(doc, item, x, y, width, fonts, shaded = false, fontSize = 12) {
  const height = menuItemTextHeight(doc, item, width, fonts, fontSize);
  if (shaded) doc.roundedRect(x - 4, y - 2, width, height + 2, 2).fill('#f2f7f5');
  doc.rect(x, y + Math.max(3, fontSize * 0.36), 5, 5).strokeColor('#68747b').lineWidth(0.5).stroke();
  const textX = x + 12;
  drawTextRun(doc, menuItemText(item), textX, y - 1, width - 16, fonts, { fontSize, lineGap: 1 });
  return height;
}

function menuFooter(doc, fonts, businessProfile, pageNo) {
  doc.moveTo(42, 780).lineTo(553, 780).strokeColor('#d1d5db').lineWidth(0.5).stroke();
  doc.fillColor('#6b7280').font(fonts.regular).fontSize(MENU_PDF_FOOTER_FONT_SIZE).text(caterProPdfFooter, 42, 788, { width: 390, lineBreak: false, link: caterProBrandUrl, underline: false });
  doc.text(`Page ${pageNo}`, 470, 788, { width: 82, align: 'right', lineBreak: false });
}

function serviceLineText(service) {
  const quantity = serviceQuantityText(service);
  return `${repairMojibake(service.name || '')}${quantity ? ` - ${quantity}` : ''}`;
}

function twoColumnTextBlockHeight(doc, items, width, fonts, fontSize, textForItem, { checkbox = true } = {}) {
  if (!items.length) return 0;
  const splitAt = Math.ceil(items.length / 2);
  const columns = [items.slice(0, splitAt), items.slice(splitAt)];
  const gapY = 4;
  const textW = checkbox ? width - 16 : width;
  return Math.max(...columns.map((columnItems) =>
    columnItems.reduce((sum, item) => {
      const text = textForItem(item);
      return sum + Math.max(fontSize + 3, textRunHeight(doc, text, textW, fonts, { fontSize, lineGap: 1 }) + 1) + gapY;
    }, 0)
  ));
}

function drawTwoColumnTextBlock(doc, items, x, y, width, fonts, fontSize, textForItem, { checkbox = true, color = '#202124' } = {}) {
  if (!items.length) return 0;
  const splitAt = Math.ceil(items.length / 2);
  const columns = [items.slice(0, splitAt), items.slice(splitAt)];
  const gap = 18;
  const colWidth = (width - gap) / 2;
  const gapY = 4;
  let maxHeight = 0;
  columns.forEach((columnItems, col) => {
    let cursorY = y;
    columnItems.forEach((item) => {
      const text = textForItem(item);
      const textX = x + col * (colWidth + gap) + (checkbox ? 12 : 0);
      const textW = colWidth - (checkbox ? 16 : 0);
      if (checkbox) {
        doc.rect(x + col * (colWidth + gap), cursorY + Math.max(3, fontSize * 0.36), 5, 5).strokeColor('#68747b').lineWidth(0.5).stroke();
      }
      const height = Math.max(fontSize + 3, drawTextRun(doc, text, textX, cursorY - 1, textW, fonts, { fontSize, color, lineGap: 1 }) + 1);
      cursorY += height + gapY;
    });
    maxHeight = Math.max(maxHeight, cursorY - y);
  });
  return maxHeight;
}

function drawServiceSection(doc, date, y, fonts, businessProfile = emptyBusinessProfile()) {
  const menuFontSize = menuPdfFontSize(businessProfile);
  if (!date.additionalServices.length) return y;
  doc.fillColor('#111827').font(fonts.bold).fontSize(10).text('Service Requirements', 42, y);
  y += 16;
  const used = drawTwoColumnTextBlock(doc, date.additionalServices, 42, y, 511, fonts, menuFontSize, serviceLineText, { checkbox: true });
  return y + used + 10;
}

function menuItemGridMetrics(doc, items, fontSize, fonts, width) {
  const height = twoColumnTextBlockHeight(doc, items, width, fonts, fontSize, menuItemText, { checkbox: true });
  return {
    height: Math.max(0, height),
  };
}

function drawMenuItemsTwoColumns(doc, items, x, y, width, fonts, fontSize) {
  return drawTwoColumnTextBlock(doc, items, x, y, width, fonts, fontSize, menuItemText, { checkbox: true });
}

function drawMenuPage({ doc, db, event, date, fonts, pageLabel, businessProfile, pageNo, menuItems = [] }) {
  const menuFontSize = menuPdfFontSize(businessProfile);
  let y = menuHeader(doc, event, date, fonts, businessProfile, pageLabel, pageNo);
  const visibleSlots = sortedVisibleMenuSlots(date.menuSlots);
  if (visibleSlots.length === 0) {
    y = drawServiceSection(doc, date, y, fonts, businessProfile);
    doc.fillColor('#5f6368').font(fonts.regular).fontSize(11).text('No menu configured for this date.', 42, y + 12);
    menuFooter(doc, fonts, businessProfile, pageNo);
    return pageNo;
  }

  for (const [slotIndex, slot] of visibleSlots.entries()) {
    const items = slot.menuItemIds.map((id) => menuPartsById(db, id, event, menuItems));
    const legacyServices = slotIndex === 0 ? date.additionalServices || [] : [];
    const services = [...(slot.additionalServices || []), ...legacyServices];
    const itemMetrics = menuItemGridMetrics(doc, items, menuFontSize, fonts, 482);
    const serviceBlockHeight = services.length
      ? 16 + twoColumnTextBlockHeight(doc, services, 431, fonts, menuFontSize, serviceLineText, { checkbox: true })
      : 0;
    const rowHeight = Math.max(52, 34 + itemMetrics.height + serviceBlockHeight + (services.length ? 12 : 0));
    if (y + rowHeight > 786) {
      menuFooter(doc, fonts, businessProfile, pageNo);
      doc.addPage();
      pageNo += 1;
      y = menuHeader(doc, event, date, fonts, businessProfile, pageLabel, pageNo);
    }
    doc.rect(42, y, 511, rowHeight).strokeColor('#d1d5db').lineWidth(0.5).stroke();
    const line = [slot.time, slot.pax ? `${slot.pax} members` : ''].filter(Boolean).join(' - ');
    doc.fillColor('#111827').font(fonts.bold).fontSize(11).text(slot.type || 'Menu', 52, y + 7, { width: 220 });
    doc.fillColor('#4b5563').font(fonts.regular).fontSize(menuFontSize).text(line, 364, y + 9, { width: 178, align: 'right' });
    doc.moveTo(52, y + 22).lineTo(543, y + 22).strokeColor('#e5e7eb').lineWidth(0.45).stroke();
    const usedItemHeight = drawMenuItemsTwoColumns(doc, items, 56, y + 30, 482, fonts, menuFontSize);
    if (!items.length && (slot.menuImages || []).length) {
      doc.fillColor('#4b5563').font(fonts.regular).fontSize(menuFontSize)
        .text(`Uploaded menu image${slot.menuImages.length > 1 ? 's' : ''} attached at end of PDF.`, 56, y + 31, { width: 320 });
    }
    if (services.length) {
      const serviceY = y + 30 + usedItemHeight + 8;
      doc.fillColor('#4b5563').font(fonts.bold).fontSize(menuFontSize).text('Services', 56, serviceY, { width: 70 });
      drawTwoColumnTextBlock(doc, services, 112, serviceY, 431, fonts, menuFontSize, serviceLineText, { checkbox: true });
    }
    y += rowHeight + 7;
  }
  menuFooter(doc, fonts, businessProfile, pageNo);
  return pageNo;
}

function menuImageAttachments(dates) {
  const attachments = [];
  for (const date of dates) {
    for (const slot of asArray(date.menuSlots)) {
      for (const image of asArray(slot.menuImages).slice(0, 2)) {
        if (!image?.dataUrl) continue;
        attachments.push({ date, slot, image });
      }
    }
  }
  return attachments;
}

function drawMenuImagePage({ doc, attachment, fonts, businessProfile, pageNo }) {
  const menuFontSize = menuPdfFontSize(businessProfile);
  const { date, slot, image } = attachment;
  const title = `${slot.type || 'Menu'} - ${prettyDate(date.date || '')}`;
  doc.fillColor('#111827').font(fonts.bold).fontSize(15).text('UPLOADED MENU IMAGE', 42, 34, { width: 260 });
  doc.fillColor('#4b5563').font(fonts.regular).fontSize(menuFontSize)
    .text(`${title}${image.name ? ` - ${image.name}` : ''}`, 42, 56, { width: 500, height: 22 });
  const buffer = imageBufferFromDataUrl(image.dataUrl);
  if (buffer) {
    try {
      doc.image(buffer, 42, 86, {
        fit: [511, 660],
        align: 'center',
        valign: 'center',
      });
    } catch {
      doc.fillColor('#991b1b').font(fonts.regular).fontSize(10).text('Unable to render uploaded image.', 42, 110);
    }
  } else {
    doc.fillColor('#991b1b').font(fonts.regular).fontSize(10).text('Uploaded image data is missing.', 42, 110);
  }
  menuFooter(doc, fonts, businessProfile, pageNo);
}

function generateMenuPdf({ res, db, event, dateId, allDates = false, businessProfile = emptyBusinessProfile(), menuItems = [] }) {
  const hasVisibleMenuSlot = (date) => sortedVisibleMenuSlots(date.menuSlots).length > 0;
  const hasMenuContent = (date) => hasVisibleMenuSlot(date) || date.additionalServices.length > 0 || date.menuSlots.some((slot) => (slot.menuImages || []).length > 0);
  const dates = allDates
    ? sortedEventDates(event.dates.filter(hasMenuContent))
    : event.dates.filter((date) => date.id === dateId || date.date === dateId);
  if (!dates.length) {
    res.status(404).json({ message: 'Event date not found' });
    return;
  }
  const doc = new PDFDocument({ size: 'A4', margin: 28, info: { Title: `Menu - ${event.name}` }, autoFirstPage: false });
  const fonts = configurePdfFonts(doc);
  const suffix = allDates ? 'ALL_DAYS' : (dates[0].date || dates[0].id);
  const number = `MENU_${event.id}_${suffix}`.replace(/[^A-Za-z0-9_-]/g, '_');
  res.setHeader('Content-Type', 'application/pdf');
  setPdfAttachment(res, [allDates ? 'All-Menus' : 'Menu', eventClientName(event), event.name || event.id, suffix]);
  doc.pipe(res);
  let pageNo = 1;
  dates.forEach((date, index) => {
    doc.addPage();
    pageNo = drawMenuPage({ doc, db, event, date, fonts, pageLabel: allDates ? `Day ${index + 1} of ${dates.length}` : 'Single day menu', businessProfile, pageNo, menuItems });
    pageNo += 1;
  });
  for (const attachment of menuImageAttachments(dates)) {
    doc.addPage();
    drawMenuImagePage({ doc, attachment, fonts, businessProfile, pageNo });
    pageNo += 1;
  }
  doc.end();
}

function addDaysIso(baseIso, days) {
  const [year, month, day] = String(baseIso).split('-').map(Number);
  const date = new Date(year, (month || 1) - 1, day || 1);
  date.setDate(date.getDate() + days);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function todayIso() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}

function generateUpcomingMenusPdf({ res, db, events, days = 3, businessProfile = emptyBusinessProfile(), menuItems = [] }) {
  const hasVisibleMenuSlot = (date) => sortedVisibleMenuSlots(date.menuSlots).length > 0;
  const hasMenuContent = (date) => hasVisibleMenuSlot(date) || date.additionalServices.length > 0 || date.menuSlots.some((slot) => (slot.menuImages || []).length > 0);
  const start = addDaysIso(todayIso(), 1);
  const end = addDaysIso(start, Math.max(1, days) - 1);
  const pages = [];
  events.forEach((event) => {
    (event.dates || []).filter((date) => date.date >= start && date.date <= end && hasMenuContent(date)).forEach((date) => pages.push({ event, date }));
  });
  pages.sort((a, b) => a.date.date.localeCompare(b.date.date) || (a.event.name || '').localeCompare(b.event.name || ''));
  if (!pages.length) {
    res.status(404).json({ message: 'No upcoming menus found' });
    return;
  }
  const doc = new PDFDocument({ size: 'A4', margin: 28, info: { Title: 'Upcoming Menus' }, autoFirstPage: false });
  const fonts = configurePdfFonts(doc);
  const number = `UPCOMING_MENUS_${start}_TO_${end}`.replace(/[^A-Za-z0-9_-]/g, '_');
  res.setHeader('Content-Type', 'application/pdf');
  setPdfAttachment(res, ['Upcoming-Menus', start, 'to', end]);
  doc.pipe(res);
  let pageNo = 1;
  pages.forEach((page, index) => {
    doc.addPage();
    pageNo = drawMenuPage({ doc, db, event: page.event, date: page.date, fonts, pageLabel: `Upcoming ${index + 1} of ${pages.length}`, businessProfile, pageNo, menuItems });
    pageNo += 1;
  });
  for (const attachment of menuImageAttachments(pages.map((page) => page.date))) {
    doc.addPage();
    drawMenuImagePage({ doc, attachment, fonts, businessProfile, pageNo });
    pageNo += 1;
  }
  doc.end();
}

function consolidatedMenuHeader(doc, fonts, businessProfile, date, pageNo, title = 'Consolidated Menus') {
  const menuFontSize = menuPdfFontSize(businessProfile);
  doc.rect(0, 0, doc.page.width, doc.page.height).fill('#ffffff');
  doc.fillColor('#111827').font(fonts.bold).fontSize(16).text('CONSOLIDATED EVENT MENU', 42, 36, { width: 260 });
  drawTextRun(doc, `${businessProfile.businessName || 'CaterPro'} | Page ${pageNo}`, 330, 39, 220, fonts, {
    fontSize: menuFontSize,
    color: '#4b5563',
    align: 'right',
    lineBreak: false,
  });
  doc.moveTo(42, 62).lineTo(553, 62).strokeColor('#9ca3af').lineWidth(0.7).stroke();
  const titleH = drawTextRun(doc, title, 42, 78, 280, fonts, {
    fontSize: 12,
    color: '#111827',
    bold: true,
  });
  const dateH = drawTextRun(doc, `Date: ${prettyDate(date)}`, 330, 80, 220, fonts, {
    fontSize: menuFontSize,
    color: '#374151',
    align: 'right',
  });
  const bottom = Math.max(78 + titleH, 80 + dateH) + 14;
  doc.moveTo(42, bottom).lineTo(553, bottom).strokeColor('#d1d5db').lineWidth(0.6).stroke();
  return bottom + 16;
}

function addConsolidatedPage(doc, fonts, businessProfile, date, pageNo, title) {
  doc.addPage();
  return consolidatedMenuHeader(doc, fonts, businessProfile, date, pageNo, title);
}

function drawConsolidatedMenuDate({ doc, db, entries, fonts, businessProfile, pageNo, title, menuItems = [] }) {
  const menuFontSize = menuPdfFontSize(businessProfile);
  const date = entries[0]?.date?.date || '';
  let y = addConsolidatedPage(doc, fonts, businessProfile, date, pageNo, title);
  for (const { event, date: eventDate } of entries) {
    const visibleSlots = sortedVisibleMenuSlots(eventDate.menuSlots);
    const eventHeaderHeight = Math.max(
      textRunHeight(doc, event.primaryClient || event.name || 'Customer', 230, fonts, { fontSize: 12, bold: true }) +
        6 +
        textRunHeight(doc, `Event: ${event.name || '-'}`, 230, fonts, { fontSize: menuFontSize }),
      textRunHeight(doc, `Venue: ${event.venue || '-'}`, 252, fonts, { fontSize: menuFontSize, align: 'right' }) +
        6 +
        textRunHeight(doc, `Mobile: ${event.mobile || '-'}`, 252, fonts, { fontSize: menuFontSize, align: 'right' })
    ) + 16;
    const baseEventHeight = eventHeaderHeight + (visibleSlots.length ? 0 : 30);
    if (y + baseEventHeight > 766) {
      menuFooter(doc, fonts, businessProfile, pageNo);
      pageNo += 1;
      y = addConsolidatedPage(doc, fonts, businessProfile, date, pageNo, title);
    }

    const clientH = drawTextRun(doc, event.primaryClient || event.name || 'Customer', 42, y, 230, fonts, {
      fontSize: 12,
      color: '#111827',
      bold: true,
    });
    drawTextRun(doc, `Event: ${event.name || '-'}`, 42, y + clientH + 6, 230, fonts, {
      fontSize: menuFontSize,
      color: '#4b5563',
    });
    const venueH = drawTextRun(doc, `Venue: ${event.venue || '-'}`, 300, y, 252, fonts, {
      fontSize: menuFontSize,
      color: '#4b5563',
      align: 'right',
    });
    drawTextRun(doc, `Mobile: ${event.mobile || '-'}`, 300, y + venueH + 6, 252, fonts, {
      fontSize: menuFontSize,
      color: '#4b5563',
      align: 'right',
    });
    y += eventHeaderHeight;

    if (!visibleSlots.length) {
      y = drawServiceSection(doc, eventDate, y, fonts, businessProfile);
      doc.fillColor('#5f6368').font(fonts.regular).fontSize(11)
        .text('No menu configured for this date.', 42, y + 4);
      y += 28;
    }

    for (const [slotIndex, slot] of visibleSlots.entries()) {
      const items = slot.menuItemIds.map((id) => menuPartsById(db, id, event, menuItems));
      const legacyServices = slotIndex === 0 ? eventDate.additionalServices || [] : [];
      const services = [...(slot.additionalServices || []), ...legacyServices];
      const itemMetrics = menuItemGridMetrics(doc, items, menuFontSize, fonts, 482);
      const serviceBlockHeight = services.length
        ? 16 + twoColumnTextBlockHeight(doc, services, 431, fonts, menuFontSize, serviceLineText, { checkbox: true })
        : 0;
      const rowHeight = Math.max(52, 34 + itemMetrics.height + serviceBlockHeight + (services.length ? 12 : 0));
      if (y + rowHeight > 766) {
        menuFooter(doc, fonts, businessProfile, pageNo);
        pageNo += 1;
        y = addConsolidatedPage(doc, fonts, businessProfile, date, pageNo, title);
      }
      doc.rect(42, y, 511, rowHeight).strokeColor('#d1d5db').lineWidth(0.5).stroke();
      const line = [slot.time, slot.pax ? `${slot.pax} members` : ''].filter(Boolean).join(' - ');
      doc.fillColor('#111827').font(fonts.bold).fontSize(11).text(slot.type || 'Menu', 52, y + 7, { width: 220 });
      doc.fillColor('#4b5563').font(fonts.regular).fontSize(menuFontSize)
        .text(line, 364, y + 9, { width: 178, align: 'right' });
      doc.moveTo(52, y + 22).lineTo(543, y + 22).strokeColor('#e5e7eb').lineWidth(0.45).stroke();
      const usedItemHeight = drawMenuItemsTwoColumns(doc, items, 56, y + 30, 482, fonts, menuFontSize);
      if (!items.length && (slot.menuImages || []).length) {
        doc.fillColor('#4b5563').font(fonts.regular).fontSize(menuFontSize)
          .text(`Uploaded menu image${slot.menuImages.length > 1 ? 's' : ''} available in the event menu PDF.`, 56, y + 31, { width: 320 });
      }
      if (services.length) {
        const serviceY = y + 30 + usedItemHeight + 8;
        doc.fillColor('#4b5563').font(fonts.bold).fontSize(menuFontSize).text('Services', 56, serviceY, { width: 70 });
        drawTwoColumnTextBlock(doc, services, 112, serviceY, 431, fonts, menuFontSize, serviceLineText, { checkbox: true });
      }
      y += rowHeight + 7;
    }
    doc.moveTo(42, y + 4).lineTo(553, y + 4).strokeColor('#e5e7eb').lineWidth(0.5).stroke();
    y += 18;
  }
  menuFooter(doc, fonts, businessProfile, pageNo);
  return pageNo + 1;
}

function generateConsolidatedMenusPdf({ res, db, events, dateFilter, startDate, endDate, title = 'Consolidated Menus', businessProfile = emptyBusinessProfile(), menuItems = [] }) {
  const hasVisibleMenuSlot = (date) => sortedVisibleMenuSlots(date.menuSlots).length > 0;
  const hasMenuContent = (date) => hasVisibleMenuSlot(date) || date.additionalServices.length > 0 || date.menuSlots.some((slot) => (slot.menuImages || []).length > 0);
  const entries = [];
  events.forEach((event) => {
    (event.dates || [])
      .filter((date) => !dateFilter || date.date === dateFilter)
      .filter((date) => !startDate || date.date >= startDate)
      .filter((date) => !endDate || date.date <= endDate)
      .filter(hasMenuContent)
      .forEach((date) => entries.push({ event, date }));
  });
  entries.sort((a, b) =>
    a.date.date.localeCompare(b.date.date) ||
    (a.event.name || '').localeCompare(b.event.name || '') ||
    (a.event.primaryClient || '').localeCompare(b.event.primaryClient || ''));
  if (!entries.length) {
    res.status(404).json({ message: 'No menus found for the selected events' });
    return;
  }
  const doc = new PDFDocument({ size: 'A4', margin: 28, info: { Title: title }, autoFirstPage: false });
  const fonts = configurePdfFonts(doc);
  const suffix = dateFilter || [startDate, endDate].filter(Boolean).join('_TO_') || 'ALL_DATES';
  res.setHeader('Content-Type', 'application/pdf');
  setPdfAttachment(res, ['Consolidated-Menus', suffix]);
  doc.pipe(res);
  let pageNo = 1;
  const grouped = new Map();
  entries.forEach((entry) => {
    const key = entry.date.date || 'No Date';
    grouped.set(key, [...(grouped.get(key) || []), entry]);
  });
  for (const groupEntries of grouped.values()) {
    pageNo = drawConsolidatedMenuDate({ doc, db, entries: groupEntries, fonts, businessProfile, pageNo, title, menuItems });
  }
  doc.end();
}

function generateMaterialDocumentPdf({ res, event = {}, materialDocument, businessProfile = emptyBusinessProfile() }) {
  const title = materialDocument.type === 'produce'
    ? 'VEGETABLES & FRUITS'
    : materialDocument.type === 'vessels'
      ? 'VESSELS & UTENSILS'
      : 'RAW MATERIALS';
  const filePrefix = materialDocument.type === 'produce'
    ? 'PRODUCE'
    : materialDocument.type === 'vessels'
      ? 'VESSELS'
      : 'RAW';
  const number = `${filePrefix}_${event.id}_${materialDocument.id}`.replace(/[^A-Za-z0-9_-]/g, '_');
  const eventName = event.name || 'Standalone Requirement List';
  const doc = new PDFDocument({ size: 'A4', margin: 12, info: { Title: `${title} - ${eventName}` }, autoFirstPage: false });
  const fonts = configurePdfFonts(doc);
  const pageX = 18;
  const pageW = 559;
  const cellGap = 7;
  const cellWidth = (pageW - cellGap * 2) / 3;
  res.setHeader('Content-Type', 'application/pdf');
  setPdfAttachment(res, [title, eventName, eventClientName(event), event.id || materialDocument.id]);
  doc.pipe(res);

  function drawHeader(pageNo = 1) {
    doc.rect(0, 0, doc.page.width, doc.page.height).fill('#ffffff');
    doc.fillColor('#111827').font(fonts.bold).fontSize(16).text(title, pageX, 24, { width: 240 });
    doc.fillColor('#4b5563').font(fonts.regular).fontSize(PDF_BODY_FONT_SIZE)
      .text(`${businessProfile.businessName || 'CaterPro'} | Page ${pageNo}`, 360, 27, { width: 217, align: 'right' });
    doc.moveTo(pageX, 50).lineTo(pageX + pageW, 50).strokeColor('#9ca3af').lineWidth(0.7).stroke();
    doc.fillColor('#111827').font(fonts.bold).fontSize(10).text(event.primaryClient || event.name || 'Requirement List', pageX, 64, { width: 245 });
    doc.fillColor('#374151').font(fonts.regular).fontSize(PDF_BODY_FONT_SIZE)
      .text(event.id ? `Event: ${event.name || '-'}` : 'Created directly from dashboard', pageX, 80, { width: 260 })
      .text(event.id ? `Venue: ${event.venue || '-'}` : `Type: ${title}`, pageX, 94, { width: 260 })
      .text(`Document: ${materialDocument.title || title}`, 360, 64, { width: 217, align: 'right' })
      .text(`Generated: ${prettyDate(new Date().toISOString().slice(0, 10))}`, 360, 80, { width: 217, align: 'right' })
      .text(`${materialDocument.items.length} items`, 360, 94, { width: 217, align: 'right' });
    doc.moveTo(pageX, 114).lineTo(pageX + pageW, 114).strokeColor('#d1d5db').lineWidth(0.6).stroke();
  }

  function drawTableHeader(y) {
    doc.rect(pageX, y, pageW, 20).fill('#f3f4f6').strokeColor('#d1d5db').lineWidth(0.5).stroke();
    [pageX, pageX + cellWidth + cellGap, pageX + (cellWidth + cellGap) * 2].forEach((x) => {
      doc.fillColor('#111827').font(fonts.bold).fontSize(9)
        .text('Item', x + 10, y + 6, { width: cellWidth - 70 })
        .text('Qty', x + cellWidth - 60, y + 6, { width: 50, align: 'right' });
    });
  }

  function drawMaterialCell(item, x, y, width) {
    const qtyText = [item.quantity, item.unit].filter(Boolean).join(' ');
    drawSingleLineText(doc, repairMojibake(item.name || item.itemId), x + 10, y + 6, width - 74, fonts, { fontSize: PDF_BODY_FONT_SIZE, height: 14, color: '#111827' });
    drawSingleLineText(doc, repairMojibake(qtyText), x + width - 60, y + 6, 50, fonts, { fontSize: PDF_BODY_FONT_SIZE, height: 14, color: '#111827', align: 'right' });
  }

  function drawFooter(pageNo = 1) {
    doc.moveTo(pageX, 790).lineTo(pageX + pageW, 790).strokeColor('#d1d5db').lineWidth(0.5).stroke();
    doc.fillColor('#6b7280').font(fonts.regular).fontSize(7).text(caterProPdfFooter, pageX, 798, { width: 390, lineBreak: false, link: caterProBrandUrl, underline: false });
    doc.text(`Page ${pageNo}`, 495, 798, { width: 82, align: 'right', lineBreak: false });
  }

  doc.addPage();
  drawHeader();
  let pageNo = 1;
  let y = 128;
  drawTableHeader(y);
  y += 20;
  const rowHeight = 27;
  for (let rowStart = 0; rowStart < materialDocument.items.length; rowStart += 3) {
    if (y + rowHeight > 782) {
      drawFooter(pageNo);
      doc.addPage();
      pageNo += 1;
      drawHeader(pageNo);
      y = 128;
      drawTableHeader(y);
      y += 20;
    }
    const rowIndex = Math.floor(rowStart / 3);
    doc.rect(pageX, y, pageW, rowHeight).fill(rowIndex % 2 === 0 ? '#ffffff' : '#fbfbfb').strokeColor('#d1d5db').lineWidth(0.45).stroke();
    for (let col = 1; col <= 2; col += 1) {
      const lineX = pageX + col * cellWidth + (col - 0.5) * cellGap;
      doc.moveTo(lineX, y).lineTo(lineX, y + rowHeight).strokeColor('#e5e7eb').lineWidth(0.45).stroke();
    }
    for (let col = 0; col < 3; col += 1) {
      const item = materialDocument.items[rowStart + col];
      if (!item) continue;
      drawMaterialCell(item, pageX + col * (cellWidth + cellGap), y, cellWidth);
    }
    y += rowHeight;
  }
  if (materialDocument.items.length === 0) {
    doc.fillColor('#6b7280').font(fonts.regular).fontSize(10).text('No items added.', pageX, y + 14);
  }
  drawFooter(pageNo);
  doc.end();
}

function menuCatalogLabel(item, language) {
  const english = repairMojibake(item.english || '');
  const kannada = repairMojibake(item.kannada || '');
  if (language === 'kannada') return kannada || english || item.id || '';
  if (language === 'english') return english || kannada || item.id || '';
  if (kannada && english) return `${kannada} / ${english}`;
  return kannada || english || item.id || '';
}

function generateMenuCatalogPdf({ res, db, menuItems, language = 'both', filters = {} }) {
  const normalizedLanguage = ['kannada', 'english', 'both'].includes(language) ? language : 'both';
  const doc = new PDFDocument({
    size: 'A4',
    layout: 'portrait',
    margin: 12,
    info: { Title: 'Menu Catalog' },
    autoFirstPage: false,
  });
  const fonts = configurePdfFonts(doc);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="caterpro-menu-catalog-${normalizedLanguage}.pdf"`);
  doc.pipe(res);

  const search = repairMojibake(String(filters.search || '')).trim().toLowerCase();
  const mealFilter = String(filters.meal || '').trim();
  const vegOnly = filters.vegOnly === true || String(filters.vegOnly || '').toLowerCase() === 'true';
  const mealText = (item) => Array.isArray(item.meals) ? item.meals.join(', ') : String(item.meals || '');

  const items = asArray(menuItems || db.universal?.menuItems)
    .map((item) => ({
      ...item,
      english: repairMojibake(item.english || ''),
      kannada: repairMojibake(item.kannada || ''),
      category: repairMojibake(item.category || 'Other') || 'Other',
      mealsText: repairMojibake(mealText(item)),
      label: menuCatalogLabel(item, normalizedLanguage),
      veg: item.veg !== false,
    }))
    .filter((item) => item.label)
    .filter((item) => {
      if (vegOnly && !item.veg) return false;
      if (mealFilter && mealFilter !== 'All') {
        const meals = item.mealsText.split(',').map((meal) => meal.trim());
        if (!meals.includes(mealFilter)) return false;
      }
      if (search) {
        const haystack = `${item.id || ''} ${item.english} ${item.kannada} ${item.category} ${item.mealsText}`.toLowerCase();
        if (!haystack.includes(search)) return false;
      }
      return true;
    });

  const page = { width: 595.28, height: 841.89 };
  const margin = 12;
  const footerH = 14;
  const topY = 40;
  const gap = 9;
  const columns = 3;
  const colW = (page.width - margin * 2 - gap * (columns - 1)) / columns;
  const bottomY = page.height - margin - footerH;
  const itemFontSize = PDF_BODY_FONT_SIZE;
  const itemLineGap = 0.8;
  let col = 0;
  let y = topY;
  let columnTopY = topY;
  let pageNo = 0;

  function addPage() {
    doc.addPage({ size: 'A4', layout: 'portrait', margin });
    pageNo += 1;
    doc.fillColor('#111827').font(fonts.bold).fontSize(15).text('Menu Catalog', margin, 10, { width: 160, lineBreak: false });
    doc.fillColor('#6b7280').font(fonts.regular).fontSize(PDF_BODY_FONT_SIZE).text(
      `${normalizedLanguage === 'both' ? 'Kannada + English' : normalizedLanguage} - ${items.length} items - CaterPro - Page ${pageNo}`,
      page.width - 270,
      15,
      { width: 248, align: 'right', lineBreak: false },
    );
    doc.moveTo(margin, 32).lineTo(page.width - margin, 32).strokeColor('#d1d5db').lineWidth(0.5).stroke();
    doc.fillColor('#6b7280').font(fonts.regular).fontSize(6.4).text(caterProPdfFooter, margin, page.height - 18, { width: page.width - margin * 2, align: 'center', lineBreak: false, link: caterProBrandUrl, underline: false });
    doc.x = margin;
    doc.y = topY;
    col = 0;
    y = topY;
    columnTopY = topY;
  }

  function nextColumn() {
    col += 1;
    if (col >= columns) addPage();
    else y = columnTopY;
  }

  function ensureSpace(height) {
    if (y + height > bottomY) nextColumn();
  }

  function x() {
    return margin + col * (colW + gap);
  }

  function sectionHeader(text, color = '#06445d') {
    ensureSpace(26 + 24 + 22);
    doc.roundedRect(x(), y, colW, 18, 3).fill(color);
    doc.fillColor('white').font(fonts.bold).fontSize(10.6).text(text, x() + 6, y + 3.8, { width: colW - 12, height: 12, ellipsis: true, lineBreak: false });
    y += 27;
    columnTopY = Math.max(columnTopY, y);
  }

  function groupHeader(text) {
    ensureSpace(23 + 22);
    doc.roundedRect(x(), y, colW, 17, 3).fill('#eef2f7').strokeColor('#d7dee8').lineWidth(0.45).stroke();
    doc.fillColor('#111827').font(fonts.bold).fontSize(10.5).text(text, x() + 5, y + 3.1, { width: colW - 10, height: 12, ellipsis: true, lineBreak: false });
    y += 23;
    if (col === 0 && columnTopY < topY + 60) columnTopY = Math.max(columnTopY, y);
  }

  function wrappedTextHeight(text, width) {
    const source = repairMojibake(String(text || ''));
    const font = hasKannadaText(source) ? fonts.kannada : fonts.regular;
    doc.font(font).fontSize(itemFontSize);
    return doc.heightOfString(source, { width, lineGap: itemLineGap });
  }

  function itemLine(item) {
    const label = menuCatalogLabel(item, normalizedLanguage);
    const source = repairMojibake(String(label || ''));
    const textW = colW - 13;
    const bothParts = normalizedLanguage === 'both' && source.includes('/')
      ? source.split(/\s*\/\s*/).filter(Boolean)
      : [];
    const kannadaPart = bothParts[0] || '';
    const englishPart = bothParts.slice(1).join(' / ');
    const textH = bothParts.length
      ? wrappedTextHeight(kannadaPart, textW) + wrappedTextHeight(englishPart, textW) + 1.5
      : wrappedTextHeight(source, textW);
    const rowH = Math.max(18, Math.ceil(textH) + 5);
    ensureSpace(rowH);
    const textX = x() + 13;
    const boxSize = 7.2;
    doc.rect(x(), y + 3.6, boxSize, boxSize).lineWidth(0.75).strokeColor(item.veg ? '#0f766e' : '#991b1b').stroke();
    if (bothParts.length) {
      const kannadaH = wrappedTextHeight(kannadaPart, textW);
      doc.fillColor('#202124')
        .font(fonts.kannada)
        .fontSize(itemFontSize)
        .text(kannadaPart, textX, y, { width: textW, height: kannadaH + 1, lineGap: itemLineGap });
      if (englishPart) {
        doc.fillColor('#374151')
          .font(fonts.regular)
          .fontSize(itemFontSize)
          .text(englishPart, textX, y + kannadaH + 1.5, { width: textW, height: Math.max(8, rowH - kannadaH - 3), lineGap: itemLineGap });
      }
    } else {
      doc.fillColor('#202124')
        .font(hasKannadaText(source) ? fonts.kannada : fonts.regular)
        .fontSize(itemFontSize)
        .text(source, textX, y, { width: textW, height: rowH - 2, lineGap: itemLineGap });
    }
    y += rowH;
  }

  function writeSide(isVeg) {
    const sideItems = items.filter((item) => item.veg === isVeg);
    if (!sideItems.length) return;
    sectionHeader(isVeg ? 'VEG' : 'NON VEG', isVeg ? '#0f766e' : '#991b1b');
    const categories = [...new Set(sideItems.map((item) => item.category || 'Other'))]
      .sort((a, b) => a.localeCompare(b, 'en-IN'));
    for (const category of categories) {
      const categoryItems = sideItems
        .filter((item) => (item.category || 'Other') === category)
        .sort((a, b) => menuCatalogLabel(a, normalizedLanguage).localeCompare(menuCatalogLabel(b, normalizedLanguage), 'kn-IN'));
      groupHeader(category);
      for (const item of categoryItems) itemLine(item);
      y += 5;
    }
  }

  addPage();
  writeSide(true);
  writeSide(false);
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
      MaterialDocument: { type: 'object', properties: { id: { type: 'string' }, type: { type: 'string', enum: ['raw', 'produce', 'vessels'] }, title: { type: 'string' }, items: { type: 'array' } } },
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
    '/api/vessel-items': { get: { tags: ['Universal Catalogs'], summary: 'List universal vessels and utensils', responses: { 200: { description: 'Vessels and utensils' } } }, post: { tags: ['Universal Catalogs'], summary: 'Create universal vessel/utensil item', responses: { 201: { description: 'Created' } } } },
    '/api/vessel-items/{id}': { put: { tags: ['Universal Catalogs'], summary: 'Update universal vessel/utensil item', parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'Updated' }, 404: { description: 'Not found' } } } },
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
    '/api/documents/consolidated-menus': { get: { tags: ['Events'], summary: 'Download one consolidated menu PDF for selected events', parameters: [{ name: 'eventIds', in: 'query', required: false, schema: { type: 'string' } }, { name: 'date', in: 'query', required: false, schema: { type: 'string' } }, { name: 'startDate', in: 'query', required: false, schema: { type: 'string' } }, { name: 'endDate', in: 'query', required: false, schema: { type: 'string' } }, { name: 'token', in: 'query', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'PDF file' }, 404: { description: 'No menus found' } } } },
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
    universal: ['menuItems', 'rawMaterials', 'produceItems', 'vesselItems'],
    userOwned: ['events', 'clients', 'employees', 'attendance', 'additionalServices', 'customMenus', 'requirementLists', 'businessProfile', 'payments', 'manualInvoices', 'auditLogs'],
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

app.post('/api/admin/users', async (req, res) => {
  const db = readDb();
  const admin = requireAdminUser(req, res, db);
  if (!admin) return;
  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');
  const name = String(req.body.name || '').trim() || email;
  const businessName = String(req.body.businessName || '').trim() || name;
  const id = String(req.body.id || '').trim() || makeId('usr');
  if (!email.includes('@') || password.length < 4) {
    return res.status(400).json({ message: 'Valid email and password are required' });
  }
  const duplicate = db.users.find((user) =>
    String(user.id || '') === id ||
    String(user.email || '').toLowerCase() === email);
  if (duplicate) {
    return res.status(409).json({
      message: 'User already exists',
      user: { id: duplicate.id, name: duplicate.name, email: duplicate.email },
    });
  }
  const now = new Date().toISOString();
  const user = {
    id,
    name,
    email,
    password,
    plan: String(req.body.plan || 'Pro').trim() || 'Pro',
    status: String(req.body.status || 'Active').trim() || 'Active',
    subscriptionStatus: String(req.body.subscriptionStatus || 'Active').trim() || 'Active',
    billingCycle: String(req.body.billingCycle || '').trim(),
    createdAt: now,
    updatedAt: now,
  };
  db.users.push(user);
  db.userData[id] = ensureUserDataShape(emptyUserData());
  db.userData[id].businessProfile = {
    ...db.userData[id].businessProfile,
    businessName,
    phone: String(req.body.phone || '').trim(),
    email,
    city: String(req.body.city || '').trim(),
    address: String(req.body.address || '').trim(),
    plan: user.plan,
    updatedAt: now,
  };
  await writeDbAndFlush(db);
  res.status(201).json({
    message: 'User inserted',
    user: adminUserMetrics(db, user),
  });
});

function rupees(value) {
  return Number(value || 0);
}

function adminUserData(db, userId) {
  const raw = db.userData?.[userId] || {};
  return {
    ...emptyUserData(),
    ...raw,
    events: asArray(raw.events),
    clients: asArray(raw.clients),
    employees: asArray(raw.employees),
    attendance: asArray(raw.attendance),
    additionalServices: asArray(raw.additionalServices),
    menuItems: asArray(raw.menuItems),
    rawMaterials: asArray(raw.rawMaterials),
    produceItems: asArray(raw.produceItems),
    vesselItems: asArray(raw.vesselItems),
    customMenus: asArray(raw.customMenus),
    requirementLists: asArray(raw.requirementLists),
    payments: asArray(raw.payments),
    manualInvoices: asArray(raw.manualInvoices),
    auditLogs: asArray(raw.auditLogs),
    businessProfile: { ...emptyBusinessProfile(), ...(raw.businessProfile || {}) },
  };
}

function adminManualInvoiceTotal(invoice) {
  return rupees(invoice.total ?? asArray(invoice.items).reduce((sum, item) => sum + rupees(item.amount), 0));
}

function adminManualInvoicePaid(invoice) {
  return rupees(invoice.advance) + rupees(invoice.settlement) + rupees(invoice.paidAmount) + rupees(invoice.settlementAmount);
}

function adminManualInvoicePending(invoice) {
  return Math.max(0, rupees(invoice.pending ?? (adminManualInvoiceTotal(invoice) - adminManualInvoicePaid(invoice))));
}

function adminEventDateValue(event) {
  const dates = asArray(event.dates).map((date) => String(date.date || '')).filter(Boolean).sort();
  return dates[0] || '';
}

function adminEventDateSurpassed(event) {
  const today = new Date().toISOString().slice(0, 10);
  return asArray(event.dates).some((date) => String(date.date || '') < today);
}

function adminClientName(user, userData, mobile = '') {
  const normalized = normalizeMobile(mobile);
  const client = asArray(userData.clients).find((item) => normalizeMobile(item.mobile) === normalized);
  return client?.name || user.name || user.email || 'Client';
}

function adminUserMetrics(db, user) {
  const userData = adminUserData(db, user.id);
  const eventSummary = asArray(userData.events).reduce((summary, event) => {
    const totals = eventTotals(normalizeEventShape(event));
    summary.earned += totals.total;
    summary.paid += totals.paid + totals.discount;
    summary.pending += totals.balance;
    return summary;
  }, { earned: 0, paid: 0, pending: 0 });
  const invoiceSummary = asArray(userData.manualInvoices).reduce((summary, invoice) => {
    summary.earned += adminManualInvoiceTotal(invoice);
    summary.paid += adminManualInvoicePaid(invoice);
    summary.pending += adminManualInvoicePending(invoice);
    return summary;
  }, { earned: 0, paid: 0, pending: 0 });
  const profile = userData.businessProfile || emptyBusinessProfile();
  const businessName = profile.businessName || user.name || user.email || 'Unnamed Business';
  const lastSyncCandidates = [
    user.updatedAt,
    profile.updatedAt,
    ...asArray(userData.clients).map((item) => item.updatedAt),
    ...asArray(userData.events).map((item) => item.updatedAt),
    ...asArray(userData.manualInvoices).map((item) => item.updatedAt),
  ].filter(Boolean).sort();
  return {
    id: user.id,
    name: user.name || '',
    email: user.email || '',
    role: user.role || '',
    businessName,
    ownerName: user.name || businessName,
    phone: profile.phone || '',
    city: profile.city || profile.address || '',
    plan: user.plan || profile.plan || 'Pro',
    status: user.status || 'Active',
    subscriptionStatus: user.subscriptionStatus || 'Active',
    billingCycle: user.billingCycle || '',
    subscriptionStartDate: user.subscriptionStartDate || '',
    subscriptionEndDate: user.subscriptionEndDate || '',
    nextRenewal: user.nextRenewal || '',
    clientCount: asArray(userData.clients).length,
    eventCount: asArray(userData.events).length,
    invoiceCount: asArray(userData.manualInvoices).length,
    menuItemCount: asArray(userData.menuItems).length,
    employeeCount: asArray(userData.employees).length,
    auditCount: asArray(userData.auditLogs).length,
    totalEarning: eventSummary.earned + invoiceSummary.earned,
    paidAmount: eventSummary.paid + invoiceSummary.paid,
    pendingPayment: eventSummary.pending + invoiceSummary.pending,
    lastSyncAt: lastSyncCandidates.at(-1) || null,
    businessProfile: profile,
  };
}

function isConsoleOnlyAdminUser(user) {
  return String(user.email || '').toLowerCase() === 'admin@caterpro.in'
    && rupees(user.totalEarning) === 0
    && rupees(user.pendingPayment) === 0
    && rupees(user.clientCount) === 0
    && rupees(user.eventCount) === 0
    && rupees(user.invoiceCount) === 0
    && rupees(user.menuItemCount) === 0
    && rupees(user.employeeCount) === 0;
}

function adminEventDto(event) {
  const normalized = normalizeEventShape(event);
  const totals = eventTotals(normalized);
  return {
    id: normalized.id,
    name: normalized.name || '',
    primaryClient: normalized.primaryClient || normalized.clientName || '',
    mobile: normalized.mobile || '',
    venue: normalized.venue || '',
    date: adminEventDateValue(normalized),
    status: normalized.status || (totals.balance <= 0 && totals.total > 0 ? 'Paid' : 'Pending'),
    total: totals.total,
    paid: totals.paid,
    balance: totals.balance,
    dates: asArray(normalized.dates),
    materialDocuments: asArray(normalized.materialDocuments),
    menuTypes: asArray(normalized.dates).flatMap((date) => asArray(date.menuSlots).map((slot) => slot.type).filter(Boolean)),
  };
}

function adminInvoiceDtos(userData) {
  const eventDocuments = asArray(userData.events).flatMap((event) => {
    const normalized = normalizeEventShape(event);
    const totals = eventTotals(normalized);
    if (!asArray(normalized.payments).length && !adminEventDateSurpassed(normalized)) {
      return [{
        id: normalized.id,
        type: 'Quotation',
        pdfType: 'quotation',
        documentNumber: `QUOTE-${String(normalized.id || '').toUpperCase()}`,
        clientName: normalized.primaryClient || normalized.clientName || adminClientName({}, userData, normalized.mobile),
        mobile: normalized.mobile || '',
        eventName: normalized.name || '',
        venue: normalized.venue || '',
        notes: normalized.notes || '',
        date: adminEventDateValue(normalized),
        total: totals.total,
        paid: 0,
        pending: totals.total,
        source: 'event',
        eventId: normalized.id,
      }];
    }
    if (!asArray(normalized.payments).length) {
      return [{
        id: normalized.id,
        type: 'Invoice',
        pdfType: 'invoice',
        documentNumber: `INV-${String(normalized.id || '').toUpperCase()}`,
        clientName: normalized.primaryClient || normalized.clientName || adminClientName({}, userData, normalized.mobile),
        mobile: normalized.mobile || '',
        eventName: normalized.name || '',
        venue: normalized.venue || '',
        notes: normalized.notes || '',
        date: adminEventDateValue(normalized),
        total: totals.balance,
        paid: totals.paid,
        pending: totals.balance,
        source: 'event',
        eventId: normalized.id,
      }];
    }
    return asArray(normalized.payments).map((payment) => ({
      id: normalized.id,
      type: 'Invoice',
      pdfType: 'invoice',
      documentNumber: `INV-${String(payment.id || normalized.id || '').toUpperCase()}`,
      clientName: normalized.primaryClient || normalized.clientName || adminClientName({}, userData, normalized.mobile),
      mobile: normalized.mobile || '',
      eventName: normalized.name || '',
      venue: normalized.venue || '',
      notes: normalized.notes || '',
      date: payment.date || adminEventDateValue(normalized),
      total: Number(payment.amount || 0),
      paid: totals.paid,
      pending: totals.balance,
      source: 'event',
      eventId: normalized.id,
      paymentId: payment.id || '',
    }));
  });
  const manualInvoices = asArray(userData.manualInvoices).map((invoice) => ({
    id: invoice.id || invoice.invoiceNumber || '',
    type: 'Invoice',
    pdfType: 'manual-invoice',
    documentNumber: invoice.invoiceNumber || documentNumber('INV', invoice),
    clientName: invoice.clientName || 'Client',
    mobile: invoice.mobile || '',
    eventName: invoice.eventName || '',
    venue: invoice.venue || '',
    notes: invoice.notes || '',
    date: invoice.invoiceDate || invoice.eventDate || '',
    total: adminManualInvoiceTotal(invoice),
    paid: adminManualInvoicePaid(invoice),
    pending: adminManualInvoicePending(invoice),
    source: 'manual',
    invoiceId: invoice.id || invoice.invoiceNumber || '',
  }));
  return [...eventDocuments, ...manualInvoices].sort((a, b) => String(b.date || '').localeCompare(String(a.date || '')));
}

function adminSelectedUser(db, req) {
  const requested = String(req.query.userId || req.params.userId || '').trim();
  const users = asArray(db.users)
    .map((user) => adminUserMetrics(db, user))
    .filter((user) => !isConsoleOnlyAdminUser(user));
  if (requested) return asArray(db.users).find((user) => user.id === requested) || null;
  const firstUserId = users[0]?.id || asArray(db.users)[0]?.id || '';
  return asArray(db.users).find((user) => user.id === firstUserId) || null;
}

function requireAdminTargetUser(req, res, db) {
  const admin = requireAdminUser(req, res, db);
  if (!admin) return null;
  const targetUser = adminSelectedUser(db, req);
  if (!targetUser) {
    res.status(404).json({ message: 'User not found' });
    return null;
  }
  db.userData[targetUser.id] = ensureUserDataShape(db.userData?.[targetUser.id] || emptyUserData());
  return targetUser;
}

function menuItemFromAdminBody(body = {}, existing = {}, list = []) {
  const mealsValue = Array.isArray(body.meals)
    ? body.meals
    : String(body.meals || existing.meals || '')
      .split(',')
      .map((meal) => meal.trim())
      .filter(Boolean);
  const english = String(body.english ?? existing.english ?? '').trim();
  const kannada = String(body.kannada ?? existing.kannada ?? '').trim();
  return {
    ...existing,
    id: String(body.id || existing.id || nextCatalogId(list, 'MNU')).trim(),
    english,
    kannada,
    title: String(body.title ?? existing.title ?? [kannada, english].filter(Boolean).join('/')).trim(),
    category: String(body.category ?? existing.category ?? '').trim(),
    meals: mealsValue,
    veg: body.veg === undefined ? existing.veg !== false : Boolean(body.veg),
    disabled: body.disabled === undefined ? Boolean(existing.disabled) : Boolean(body.disabled),
    updatedAt: new Date().toISOString(),
    createdAt: existing.createdAt || new Date().toISOString(),
  };
}

async function writeDbAndFlush(db) {
  writeDb(db);
  await flushSupabaseWrites();
}

function adminUserPayload(db, user) {
  const userData = adminUserData(db, user.id);
  const metrics = adminUserMetrics(db, user);
  const events = asArray(userData.events).map(adminEventDto).sort((a, b) => String(b.date || '').localeCompare(String(a.date || '')));
  const invoices = adminInvoiceDtos(userData);
  return {
    user: metrics,
    businessProfile: userData.businessProfile,
    clients: asArray(userData.clients),
    events,
    invoices,
    menuItems: asArray(userData.menuItems),
    customMenus: asArray(userData.customMenus),
    rawMaterials: asArray(userData.rawMaterials),
    produceItems: asArray(userData.produceItems),
    vesselItems: asArray(userData.vesselItems),
    employees: asArray(userData.employees),
    attendance: asArray(userData.attendance),
    reports: {
      totalRevenue: metrics.totalEarning,
      pendingPayment: metrics.pendingPayment,
      paidAmount: metrics.paidAmount,
      monthlyOrders: events.length,
      invoiceCount: invoices.length,
    },
    auditLogs: asArray(userData.auditLogs),
  };
}

function customMenuFromAdminBody(body = {}, existing = {}) {
  return {
    ...existing,
    id: String(body.id || existing.id || makeId('cmenu')).trim(),
    name: String(body.name ?? existing.name ?? '').trim(),
    type: String(body.type ?? existing.type ?? '').trim(),
    itemIds: asArray(body.itemIds ?? existing.itemIds).map((item) => String(item || '').trim()).filter(Boolean),
    updatedAt: new Date().toISOString(),
    createdAt: existing.createdAt || body.createdAt || new Date().toISOString(),
  };
}

app.get('/api/admin/overview', (req, res) => {
  const db = readDb();
  const admin = requireAdminUser(req, res, db);
  if (!admin) return;
  const users = asArray(db.users).map((user) => adminUserMetrics(db, user));
  const businessUsers = users.filter((user) => !isConsoleOnlyAdminUser(user));
  const totals = businessUsers.reduce((summary, user) => {
    summary.totalEarning += user.totalEarning;
    summary.pendingPayment += user.pendingPayment;
    summary.events += user.eventCount;
    summary.clients += user.clientCount;
    summary.invoices += user.invoiceCount;
    return summary;
  }, { totalEarning: 0, pendingPayment: 0, events: 0, clients: 0, invoices: 0 });
  res.json({
    admin: { id: admin.id, name: admin.name, email: admin.email },
    totals: {
      users: businessUsers.length,
      activeUsers: businessUsers.filter((user) => String(user.status).toLowerCase() === 'active').length,
      trialUsers: businessUsers.filter((user) => String(user.plan).toLowerCase().includes('trial')).length,
      ...totals,
    },
    users: businessUsers,
    storage: { stateId: supabaseStateId, supabaseEnabled: Boolean(supabase) },
  });
});

app.get('/api/admin/profile', (req, res) => {
  const db = readDb();
  const admin = requireAdminUser(req, res, db);
  if (!admin) return;
  res.json({
    id: admin.id,
    name: admin.name || '',
    email: admin.email || '',
    role: admin.role || 'admin',
    phone: admin.phone || '',
    designation: admin.designation || 'Super Admin',
    avatarUrl: admin.avatarUrl || '',
    status: admin.status || 'Active',
    createdAt: admin.createdAt || '',
    updatedAt: admin.updatedAt || '',
  });
});

app.put('/api/admin/profile', async (req, res) => {
  const db = readDb();
  const admin = requireAdminUser(req, res, db);
  if (!admin) return;
  const nextEmail = req.body.email === undefined
    ? String(admin.email || '').trim().toLowerCase()
    : String(req.body.email || '').trim().toLowerCase();
  if (!nextEmail.includes('@')) return res.status(400).json({ message: 'Valid email is required' });
  const emailOwner = asArray(db.users).find((user) => user.id !== admin.id && String(user.email || '').toLowerCase() === nextEmail);
  if (emailOwner) return res.status(409).json({ message: 'Email is already used by another user' });
  if (req.body.name !== undefined) admin.name = String(req.body.name || '').trim();
  admin.email = nextEmail;
  if (req.body.phone !== undefined) admin.phone = String(req.body.phone || '').trim();
  if (req.body.designation !== undefined) admin.designation = String(req.body.designation || '').trim();
  if (req.body.avatarUrl !== undefined) admin.avatarUrl = String(req.body.avatarUrl || '').trim();
  if (req.body.status !== undefined) admin.status = String(req.body.status || '').trim() || 'Active';
  if (req.body.password) admin.password = String(req.body.password);
  admin.role = admin.role || 'admin';
  admin.updatedAt = new Date().toISOString();
  await writeDbAndFlush(db);
  res.json({
    id: admin.id,
    name: admin.name || '',
    email: admin.email || '',
    role: admin.role || 'admin',
    phone: admin.phone || '',
    designation: admin.designation || 'Super Admin',
    avatarUrl: admin.avatarUrl || '',
    status: admin.status || 'Active',
    createdAt: admin.createdAt || '',
    updatedAt: admin.updatedAt || '',
  });
});

app.get('/api/admin/users', (req, res) => {
  const db = readDb();
  const admin = requireAdminUser(req, res, db);
  if (!admin) return;
  res.json(asArray(db.users)
    .map((user) => adminUserMetrics(db, user))
    .filter((user) => !isConsoleOnlyAdminUser(user)));
});

app.put('/api/admin/users/:userId', async (req, res) => {
  const db = readDb();
  const admin = requireAdminUser(req, res, db);
  if (!admin) return;
  const user = asArray(db.users).find((entry) => entry.id === req.params.userId);
  if (!user) return res.status(404).json({ message: 'User not found' });
  db.userData[user.id] = ensureUserDataShape(db.userData?.[user.id] || emptyUserData());
  const profile = db.userData[user.id].businessProfile || emptyBusinessProfile();
  if (req.body.name !== undefined) user.name = String(req.body.name || '').trim();
  if (req.body.email !== undefined) user.email = String(req.body.email || '').trim().toLowerCase();
  if (req.body.plan !== undefined) user.plan = String(req.body.plan || '').trim();
  if (req.body.status !== undefined) user.status = String(req.body.status || '').trim() || 'Active';
  if (req.body.subscriptionStatus !== undefined) user.subscriptionStatus = String(req.body.subscriptionStatus || '').trim();
  if (req.body.billingCycle !== undefined) user.billingCycle = String(req.body.billingCycle || '').trim();
  if (req.body.subscriptionStartDate !== undefined) user.subscriptionStartDate = String(req.body.subscriptionStartDate || '').trim();
  if (req.body.subscriptionEndDate !== undefined) user.subscriptionEndDate = String(req.body.subscriptionEndDate || '').trim();
  if (req.body.nextRenewal !== undefined) user.nextRenewal = String(req.body.nextRenewal || '').trim();
  for (const key of Object.keys(emptyBusinessProfile())) {
    if (req.body[key] === undefined) continue;
    if (key === 'gstRate' || key === 'invoiceTextScale' || key === 'pdfMenuFontSize') {
      profile[key] = Number(req.body[key]) || emptyBusinessProfile()[key];
    } else {
      profile[key] = String(req.body[key] || '').trim();
    }
  }
  profile.updatedAt = new Date().toISOString();
  user.updatedAt = new Date().toISOString();
  db.userData[user.id].businessProfile = profile;
  await writeDbAndFlush(db);
  res.json(adminUserMetrics(db, user));
});

app.get('/api/admin/users/:userId', (req, res) => {
  const db = readDb();
  const admin = requireAdminUser(req, res, db);
  if (!admin) return;
  const user = adminSelectedUser(db, req);
  if (!user) return res.status(404).json({ message: 'User not found' });
  res.json(adminUserPayload(db, user));
});

app.get('/api/admin/client-data', (req, res) => {
  const db = readDb();
  const admin = requireAdminUser(req, res, db);
  if (!admin) return;
  const user = adminSelectedUser(db, req);
  if (!user) return res.status(404).json({ message: 'User not found' });
  res.json(adminUserPayload(db, user));
});

app.get('/api/admin/users/:userId/events/:eventId/documents/:type', (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  if (!['quotation', 'invoice', 'menu', 'all-menus'].includes(req.params.type)) {
    return res.status(400).json({ message: 'Document type must be quotation, invoice, menu, or all-menus' });
  }
  const event = findUserEvent(db, targetUser.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  if (req.params.type === 'menu') {
    return generateMenuPdf({
      res,
      db,
      event,
      dateId: req.query.dateId || event.dates?.[0]?.id || event.dates?.[0]?.date,
      businessProfile: db.userData[targetUser.id].businessProfile,
      menuItems: db.userData[targetUser.id].menuItems,
    });
  }
  if (req.params.type === 'all-menus') {
    return generateMenuPdf({
      res,
      db,
      event,
      allDates: true,
      businessProfile: db.userData[targetUser.id].businessProfile,
      menuItems: db.userData[targetUser.id].menuItems,
    });
  }
  return generateEventPdf({
    res,
    db,
    event,
    type: req.params.type,
    businessProfile: boxedInvoiceBusinessProfile(db.userData[targetUser.id].businessProfile),
    clients: db.userData[targetUser.id].clients || [],
    disposition: 'inline',
  });
});

app.get('/api/admin/users/:userId/events/:eventId/material-documents/:documentId/pdf', (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  const event = findUserEvent(db, targetUser.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  const materialDocument = asArray(event.materialDocuments)
    .find((item) => item.id === req.params.documentId);
  if (!materialDocument) return res.status(404).json({ message: 'Material document not found' });
  return generateMaterialDocumentPdf({
    res,
    event,
    materialDocument,
    businessProfile: db.userData[targetUser.id].businessProfile,
  });
});

app.get('/api/admin/users/:userId/reports/monthly.pdf', (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  const userData = db.userData[targetUser.id];
  const range = reportRangeFromQuery(req.query);
  if (range.error) return res.status(400).json({ message: range.error });
  return generateMonthlyReportPdf({
    res,
    events: userData.events,
    manualInvoices: userData.manualInvoices,
    range,
    businessProfile: userData.businessProfile,
    disposition: 'inline',
  });
});

app.put('/api/admin/users/:userId/events/:eventId/documents/:type', async (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  if (!['quotation', 'invoice'].includes(req.params.type)) {
    return res.status(400).json({ message: 'Document type must be quotation or invoice' });
  }
  const userData = db.userData[targetUser.id];
  const index = asArray(userData.events).findIndex((event) => event.id === req.params.eventId);
  if (index === -1) return res.status(404).json({ message: 'Event not found' });
  const existing = userData.events[index];
  const next = eventFromBody({
    ...existing,
    name: req.body.eventName ?? existing.name,
    primaryClient: req.body.clientName ?? existing.primaryClient,
    mobile: req.body.mobile ?? existing.mobile,
    venue: req.body.venue ?? existing.venue,
    notes: req.body.notes ?? existing.notes,
    status: req.body.status ?? existing.status,
    dates: req.body.date
      ? asArray(existing.dates).map((date, dateIndex) => dateIndex === 0 ? { ...date, date: req.body.date } : date)
      : existing.dates,
  }, existing);
  userData.events[index] = next;
  await writeDbAndFlush(db);
  res.json(adminInvoiceDtos(userData).find((invoice) => invoice.source === 'event' && invoice.eventId === next.id && invoice.pdfType === req.params.type) || adminEventDto(next));
});

app.get('/api/admin/users/:userId/manual-invoices/:invoiceId/pdf', (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  const invoice = asArray(db.userData[targetUser.id].manualInvoices)
    .find((item) => item.id === req.params.invoiceId || item.invoiceNumber === req.params.invoiceId);
  if (!invoice) return res.status(404).json({ message: 'Manual invoice not found' });
  return generateManualInvoicePdf({
    res,
    invoice,
    businessProfile: boxedInvoiceBusinessProfile(db.userData[targetUser.id].businessProfile),
    disposition: 'inline',
  });
});

app.put('/api/admin/users/:userId/manual-invoices/:invoiceId', async (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  const userData = db.userData[targetUser.id];
  const index = asArray(userData.manualInvoices)
    .findIndex((item) => item.id === req.params.invoiceId || item.invoiceNumber === req.params.invoiceId);
  if (index === -1) return res.status(404).json({ message: 'Manual invoice not found' });
  const invoice = manualInvoiceFromBody(req.body, userData.manualInvoices[index]);
  userData.manualInvoices[index] = invoice;
  await writeDbAndFlush(db);
  res.json(adminInvoiceDtos(userData).find((item) => item.source === 'manual' && item.invoiceId === invoice.id) || invoice);
});

app.put('/api/admin/users/:userId/menu-items/:itemId', async (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  const list = db.userData[targetUser.id].menuItems;
  const existing = list.find((item) => item.id === req.params.itemId);
  const item = menuItemFromAdminBody({ ...req.body, id: req.body.id || req.params.itemId }, existing || {}, list);
  if (item.id !== req.params.itemId) {
    db.userData[targetUser.id].menuItems = list.filter((entry) => entry.id !== req.params.itemId);
  }
  upsertById(db.userData[targetUser.id].menuItems, item);
  await writeDbAndFlush(db);
  res.status(existing ? 200 : 201).json(item);
});

app.delete('/api/admin/users/:userId/menu-items/:itemId', async (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  const references = menuItemReferences(db.userData[targetUser.id], req.params.itemId);
  if (sendMenuItemReferenceConflict(res, references)) return;
  const before = db.userData[targetUser.id].menuItems.length;
  db.userData[targetUser.id].menuItems = db.userData[targetUser.id].menuItems
    .filter((entry) => entry.id !== req.params.itemId);
  if (db.userData[targetUser.id].menuItems.length === before) {
    return res.status(404).json({ message: 'Menu item not found' });
  }
  await writeDbAndFlush(db);
  res.status(204).end();
});

app.post('/api/admin/users/:userId/employees', async (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  const list = db.userData[targetUser.id].employees;
  const employee = employeeFromBody(req.body);
  upsertById(list, employee);
  await writeDbAndFlush(db);
  res.status(201).json(employee);
});

app.put('/api/admin/users/:userId/employees/:employeeId', async (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  const list = db.userData[targetUser.id].employees;
  const existing = list.find((employee) => employee.id === req.params.employeeId);
  const employee = employeeFromBody({ ...req.body, id: req.body.id || req.params.employeeId }, existing || {});
  if (employee.id !== req.params.employeeId) {
    db.userData[targetUser.id].employees = list.filter((entry) => entry.id !== req.params.employeeId);
  }
  upsertById(db.userData[targetUser.id].employees, employee);
  await writeDbAndFlush(db);
  res.status(existing ? 200 : 201).json(employee);
});

app.delete('/api/admin/users/:userId/employees/:employeeId', async (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  const before = db.userData[targetUser.id].employees.length;
  db.userData[targetUser.id].employees = db.userData[targetUser.id].employees
    .filter((entry) => entry.id !== req.params.employeeId);
  if (db.userData[targetUser.id].employees.length === before) {
    return res.status(404).json({ message: 'Employee not found' });
  }
  await writeDbAndFlush(db);
  res.status(204).end();
});

app.post('/api/admin/users/:userId/menu-items/import', async (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  const list = db.userData[targetUser.id].menuItems;
  const rows = asArray(req.body.items);
  if (!rows.length) return res.status(400).json({ message: 'No menu items supplied' });
  let created = 0;
  let updated = 0;
  for (const row of rows) {
    const requestedId = String(row.id || '').trim();
    const existing = requestedId ? list.find((item) => item.id === requestedId) : null;
    const item = menuItemFromAdminBody(row, existing || {}, list);
    if (existing) updated += 1;
    else created += 1;
    upsertById(list, item);
  }
  await writeDbAndFlush(db);
  res.json({ message: 'Menu import completed', created, updated, count: list.length });
});

app.post('/api/admin/users/:userId/custom-menus', async (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  const list = db.userData[targetUser.id].customMenus;
  const menu = customMenuFromAdminBody(req.body, {});
  upsertById(list, menu);
  await writeDbAndFlush(db);
  res.status(201).json(menu);
});

app.put('/api/admin/users/:userId/custom-menus/:menuId', async (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  const list = db.userData[targetUser.id].customMenus;
  const existing = list.find((menu) => menu.id === req.params.menuId);
  if (!existing) return res.status(404).json({ message: 'Custom menu not found' });
  const menu = customMenuFromAdminBody({ ...req.body, id: req.params.menuId }, existing);
  upsertById(list, menu);
  await writeDbAndFlush(db);
  res.json(menu);
});

app.delete('/api/admin/users/:userId/custom-menus/:menuId', async (req, res) => {
  const db = readDb();
  const targetUser = requireAdminTargetUser(req, res, db);
  if (!targetUser) return;
  const before = db.userData[targetUser.id].customMenus.length;
  db.userData[targetUser.id].customMenus = db.userData[targetUser.id].customMenus
    .filter((menu) => menu.id !== req.params.menuId);
  if (db.userData[targetUser.id].customMenus.length === before) {
    return res.status(404).json({ message: 'Custom menu not found' });
  }
  await writeDbAndFlush(db);
  res.status(204).end();
});

function changePasswordHandler(req, res) {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const oldPassword = String(req.body.oldPassword || '');
  const newPassword = String(req.body.newPassword || '');
  if (user.password !== oldPassword) {
    return res.status(400).json({ message: 'Old password is incorrect' });
  }
  if (newPassword.length < 4) {
    return res.status(400).json({ message: 'New password must be at least 4 characters' });
  }
  user.password = newPassword;
  writeDb(db);
  res.json({ message: 'Password updated' });
}

app.post('/api/auth/change-password', changePasswordHandler);
app.post('/api/auth/reset-password', changePasswordHandler);
app.put('/api/auth/change-password', changePasswordHandler);
app.put('/api/auth/reset-password', changePasswordHandler);

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
  writeDb(db);
  res.json({ universal: db.universal, userData: db.userData[user.id] });
});

function recordUpdatedAtValue(item) {
  const value = Date.parse(item?.updatedAt || item?.updated_at || item?.createdAt || item?.created_at || '');
  return Number.isFinite(value) ? value : 0;
}

const PDF_BODY_FONT_SIZE = 8.5;
const MENU_PDF_FOOTER_FONT_SIZE = 8;

function recordKeyForSync(item, listKey) {
  if (!item || typeof item !== 'object') return '';
  if (listKey === 'eventDates') return item.date || item.id || '';
  if (listKey === 'attendance') return [item.eventId, item.employeeId, item.date].map((value) => value || '').join('|');
  if (listKey === 'selectedServices') return [item.serviceId || item.id || item.name, item.count || item.quantity || ''].map((value) => value || '').join('|');
  if (listKey === 'materialItems') return [item.itemId || item.id || item.name, item.quantity || ''].map((value) => value || '').join('|');
  if (listKey === 'auditLogs') return [item.id, item.action, item.entityType, item.entityId, item.createdAt].map((value) => value || '').join('|');
  return item.id || item.mobile || item.name || JSON.stringify(item);
}

function mergeSyncRecord(existing = {}, incoming = {}, listKey = '') {
  if (listKey === 'businessProfile') {
    return mergeBusinessProfile(existing, incoming);
  }
  const existingUpdatedAt = recordUpdatedAtValue(existing);
  const incomingUpdatedAt = recordUpdatedAtValue(incoming);
  const base = incomingUpdatedAt >= existingUpdatedAt ? { ...existing, ...incoming } : { ...incoming, ...existing };
  if (listKey === 'events') {
    base.dates = mergeSyncRecordList(existing.dates, incoming.dates, 'eventDates');
    base.payments = mergeSyncRecordList(existing.payments, incoming.payments, 'payments');
    base.materialDocuments = mergeSyncRecordList(existing.materialDocuments, incoming.materialDocuments, 'materialDocuments');
    base.employeeAssignments = mergeSyncRecordList(existing.employeeAssignments, incoming.employeeAssignments, 'employeeAssignments');
  } else if (listKey === 'eventDates') {
    base.menuSlots = mergeSyncRecordList(existing.menuSlots, incoming.menuSlots, 'menuSlots');
    base.additionalServices = mergeSyncRecordList(existing.additionalServices, incoming.additionalServices, 'selectedServices');
  } else if (listKey === 'menuSlots') {
    base.menuItemIds = [...new Set([...asArray(existing.menuItemIds), ...asArray(incoming.menuItemIds)].map(String).filter(Boolean))];
    base.additionalServices = mergeSyncRecordList(existing.additionalServices, incoming.additionalServices, 'selectedServices');
  } else if (listKey === 'materialDocuments') {
    base.items = mergeSyncRecordList(existing.items, incoming.items, 'materialItems');
  }
  return base;
}

function mergeSyncRecordList(existing, incoming, listKey) {
  const records = new Map();
  for (const source of [asArray(existing), asArray(incoming)]) {
    for (const item of source) {
      if (!item || typeof item !== 'object') continue;
      const key = recordKeyForSync(item, listKey);
      if (!key) continue;
      records.set(key, records.has(key) ? mergeSyncRecord(records.get(key), item, listKey) : item);
    }
  }
  return [...records.values()];
}

function menuItemReferences(userData = emptyUserData(), itemId = '') {
  const id = String(itemId || '');
  const todayKey = new Date().toISOString().slice(0, 10);
  const eventMenus = [];
  for (const event of asArray(userData.events)) {
    for (const date of asArray(event.dates)) {
      for (const slot of asArray(date.menuSlots)) {
        if (!asArray(slot.menuItemIds).map(String).includes(id)) continue;
        eventMenus.push({
          eventId: event.id || '',
          eventName: event.name || 'Untitled event',
          clientName: event.primaryClient || '',
          date: date.date || '',
          menuType: slot.type || '',
          isFuture: !date.date || String(date.date) >= todayKey,
        });
      }
    }
  }
  const customMenus = asArray(userData.customMenus)
    .filter((menu) => asArray(menu.itemIds).map(String).includes(id))
    .map((menu) => ({
      id: menu.id || '',
      name: menu.name || 'Unnamed ready-made menu',
      type: menu.type || '',
    }));
  return { eventMenus, customMenus };
}

function sendMenuItemReferenceConflict(res, references) {
  const eventCount = references.eventMenus.length;
  const customMenuCount = references.customMenus.length;
  if (!eventCount && !customMenuCount) return false;
  res.status(409).json({
    message:
      'This menu item is used in event or ready-made menus. Edit this item or add a new menu item instead of deleting it.',
    references,
  });
  return true;
}

function mergeUserDataForSync(existing = emptyUserData(), incoming = emptyUserData()) {
  const current = ensureUserDataShape({ ...emptyUserData(), ...existing });
  const next = ensureUserDataShape({ ...emptyUserData(), ...incoming });
  return ensureUserDataShape({
    ...current,
    ...next,
    events: mergeSyncRecordList(current.events, next.events, 'events'),
    clients: mergeSyncRecordList(current.clients, next.clients, 'clients'),
    employees: mergeSyncRecordList(current.employees, next.employees, 'employees'),
    attendance: mergeSyncRecordList(current.attendance, next.attendance, 'attendance'),
    additionalServices: mergeSyncRecordList(current.additionalServices, next.additionalServices, 'additionalServices'),
    menuItems: mergeSyncRecordList(current.menuItems, next.menuItems, 'menuItems'),
    rawMaterials: mergeSyncRecordList(current.rawMaterials, next.rawMaterials, 'rawMaterials'),
    produceItems: mergeSyncRecordList(current.produceItems, next.produceItems, 'produceItems'),
    vesselItems: mergeSyncRecordList(current.vesselItems, next.vesselItems, 'vesselItems'),
    customMenus: mergeSyncRecordList(current.customMenus, next.customMenus, 'customMenus'),
    requirementLists: mergeSyncRecordList(current.requirementLists, next.requirementLists, 'requirementLists'),
    payments: mergeSyncRecordList(current.payments, next.payments, 'payments'),
    manualInvoices: mergeSyncRecordList(current.manualInvoices, next.manualInvoices, 'manualInvoices'),
    auditLogs: mergeSyncRecordList(current.auditLogs, next.auditLogs, 'auditLogs'),
    businessProfile: mergeSyncRecord(current.businessProfile || {}, next.businessProfile || {}, 'businessProfile'),
  });
}

function backupUserDataForSync(existing = emptyUserData(), incoming = {}) {
  return mergeUserDataForSync(existing, incoming);
}

function syncSnapshotForUser(db, userId) {
  ensureUniversal(db);
  db.userData[userId] = ensureUserDataShape(db.userData[userId] || emptyUserData());
  return {
    stateId: supabaseStateId,
    serverUpdatedAt: new Date().toISOString(),
    universal: db.universal,
    userData: db.userData[userId],
  };
}

app.get('/api/sync/snapshot', async (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const profileChanged = await hydrateBusinessProfileFromSupabase(db, user.id);
  const menuItemsChanged = await hydrateUserMenuItemsFromSupabase(db, user.id);
  if (profileChanged || menuItemsChanged) writeDb(db);
  res.json(syncSnapshotForUser(db, user.id));
});

app.post('/api/sync/snapshot', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const incomingUserData = req.body?.userData && typeof req.body.userData === 'object' ? req.body.userData : {};
  const incomingUniversal = req.body?.universal && typeof req.body.universal === 'object' ? req.body.universal : {};
  const isAdminSync = String(user.email || '').toLowerCase() === 'admin@caterpro.in';
  const includeUniversal = isAdminSync && Object.keys(incomingUniversal).length > 0;
  db.userData[user.id] = backupUserDataForSync(db.userData[user.id] || emptyUserData(), incomingUserData);
  if (includeUniversal) db.universal = mergeProtectedUniversalCatalog(db.universal || {}, incomingUniversal);
  ensureUniversal(db);
  if (req.body?.includeMirrorSync === true) {
    runtimeDb = db;
    saveSupabaseDb(db, { userId: user.id, includeUniversal })
      .then((mirrorSync) => res.json({ ...syncSnapshotForUser(db, user.id), mirrorSync }))
      .catch((error) => {
        console.warn('Supabase sync skipped after local merge:', error.message);
        res.json({
          ...syncSnapshotForUser(db, user.id),
          mirrorSync: {
            status: 'failed',
            error: error.message,
            failedTables: ['supabase_tables'],
          },
        });
      });
    return;
  }
  writeDb(db, { userId: user.id, includeUniversal });
  res.json(syncSnapshotForUser(db, user.id));
});

app.post('/api/storage/repair-normalize', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  const user = requireUser(req, res, db);
  if (!user) return;
  const before = {
    events: db.userData[user.id].events.length,
    dates: db.userData[user.id].events.reduce((sum, event) => sum + asArray(event.dates).length, 0),
    attendance: db.userData[user.id].attendance.length,
  };
  db.userData[user.id] = ensureUserDataShape(db.userData[user.id]);
  writeDb(db);
  const after = {
    events: db.userData[user.id].events.length,
    dates: db.userData[user.id].events.reduce((sum, event) => sum + asArray(event.dates).length, 0),
    attendance: db.userData[user.id].attendance.length,
  };
  res.json({ message: 'Storage normalized', before, after });
});

function exportBackup(req, res) {
  const db = readDb();
  ensureUniversal(db);
  const user = requireUser(req, res, db);
  if (!user) return;
  const backup = {
    schemaVersion: 1,
    app: 'CaterPro',
    exportedAt: new Date().toISOString(),
    user: { id: user.id, email: user.email, name: user.name },
    userData: db.userData[user.id],
    universal: db.universal,
  };
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Content-Disposition', `attachment; filename="caterpro-backup-${stamp}.json"`);
  res.send(JSON.stringify(backup, null, 2));
}

app.get('/api/backup', exportBackup);
app.get('/api/backup/export', exportBackup);

app.get('/api/admin/audit-logs', (req, res) => {
  const db = readDb();
  const admin = requireAdminUser(req, res, db);
  if (!admin) return;
  const userIdFilter = String(req.query.userId || '').trim();
  const limit = Math.min(1000, Math.max(1, Number(req.query.limit || 200) || 200));
  const logs = [];
  for (const user of asArray(db.users)) {
    if (userIdFilter && user.id !== userIdFilter) continue;
    const userData = ensureUserDataShape(db.userData?.[user.id] || emptyUserData());
    for (const entry of asArray(userData.auditLogs)) {
      logs.push({
        ...entry,
        userId: user.id,
        userName: user.name || '',
        userEmail: user.email || '',
      });
    }
  }
  logs.sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
  res.json(logs.slice(0, limit));
});

app.post('/api/backup/import', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  const user = requireUser(req, res, db);
  if (!user) return;
  const payload = req.body || {};
  const importedUserData = payload.userData || payload;
  if (!importedUserData || typeof importedUserData !== 'object' || Array.isArray(importedUserData)) {
    return res.status(400).json({ message: 'Invalid CaterPro backup file' });
  }
  db.userData[user.id] = ensureUserDataShape({
    ...emptyUserData(),
    ...importedUserData,
    businessProfile: { ...emptyBusinessProfile(), ...(importedUserData.businessProfile || {}) },
  });
  if (payload.universal && typeof payload.universal === 'object' && !Array.isArray(payload.universal)) {
    db.universal = mergeProtectedUniversalCatalog(db.universal || {}, payload.universal);
  }
  writeDb(db);
  res.json({
    message: 'Backup imported',
    counts: {
      events: db.userData[user.id].events.length,
      clients: db.userData[user.id].clients.length,
      employees: db.userData[user.id].employees.length,
      attendance: db.userData[user.id].attendance.length,
      additionalServices: db.userData[user.id].additionalServices.length,
      customMenus: db.userData[user.id].customMenus.length,
      requirementLists: db.userData[user.id].requirementLists.length,
      manualInvoices: db.userData[user.id].manualInvoices.length,
      auditLogs: db.userData[user.id].auditLogs.length,
      menuItems: db.universal.menuItems.length,
      rawMaterials: db.universal.rawMaterials.length,
      produceItems: db.universal.produceItems.length,
      vesselItems: db.universal.vesselItems.length,
    },
  });
});

app.get('/api/business-profile', async (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const hydrated = await hydrateBusinessProfileFromSupabase(db, user.id);
  if (hydrated) writeDb(db);
  res.json(db.userData[user.id].businessProfile);
});

app.get('/api/document-templates/invoices', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  res.json({
    defaultTemplate: 'boxed',
    templates: invoiceDocumentTemplates,
  });
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

app.post('/api/additional-services', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const service = {
    id: req.body.id || makeId('srv'),
    name: req.body.name || '',
    unit: req.body.unit || '',
    quantity: Number(req.body.quantity || 0),
    price: Number(req.body.price || 0),
    updatedAt: new Date().toISOString(),
  };
  upsertById(db.userData[user.id].additionalServices, service);
  writeDb(db);
  res.status(201).json(service);
});

app.put('/api/additional-services/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const existing = db.userData[user.id].additionalServices.find((item) => item.id === req.params.id);
  const service = {
    ...(existing || {}),
    ...req.body,
    id: req.params.id,
    quantity: Number(req.body.quantity ?? existing?.quantity ?? 0),
    price: Number(req.body.price ?? existing?.price ?? 0),
    updatedAt: new Date().toISOString(),
  };
  upsertById(db.userData[user.id].additionalServices, service);
  writeDb(db);
  res.status(existing ? 200 : 201).json(service);
});

app.delete('/api/additional-services/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const before = db.userData[user.id].additionalServices.length;
  db.userData[user.id].additionalServices = db.userData[user.id].additionalServices.filter((item) => item.id !== req.params.id);
  if (db.userData[user.id].additionalServices.length === before) return res.status(404).json({ message: 'Additional service not found' });
  writeDb(db);
  res.json({ message: 'Additional service deleted' });
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
  const previousMobile = normalizeMobile(existing.mobile);
  const previousName = existing.name || '';
  const client = clientFromBody({ ...req.body, id: req.params.id }, existing);
  if (!client.name || !client.mobile) return res.status(400).json({ message: 'Client name and mobile number are required' });
  if (client.mobile.length !== 10) return res.status(400).json({ message: 'Mobile number must be 10 digits' });
  upsertById(db.userData[user.id].clients, client);
  const clientMobile = normalizeMobile(client.mobile);
  for (const event of db.userData[user.id].events || []) {
    const eventMobile = normalizeMobile(event.mobile);
    const linkedByMobile = (previousMobile && eventMobile === previousMobile) || (clientMobile && eventMobile === clientMobile);
    const linkedByPreviousName = previousName && String(event.primaryClient || '').trim() === previousName.trim();
    if (linkedByMobile || linkedByPreviousName) {
      event.mobile = client.mobile;
      if (client.name) event.primaryClient = client.name;
      event.updatedAt = new Date().toISOString();
    }
  }
  for (const invoice of db.userData[user.id].manualInvoices || []) {
    const invoiceMobile = normalizeMobile(invoice.mobile);
    const linkedByMobile = (previousMobile && invoiceMobile === previousMobile) || (clientMobile && invoiceMobile === clientMobile);
    const linkedByPreviousName = previousName && String(invoice.clientName || '').trim() === previousName.trim();
    if (linkedByMobile || linkedByPreviousName) {
      invoice.mobile = client.mobile;
      if (client.name) invoice.clientName = client.name;
      if (client.address || client.city) invoice.clientAddress = client.address || client.city;
      if (client.gst) invoice.clientGst = client.gst;
      invoice.updatedAt = new Date().toISOString();
    }
  }
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

app.get('/api/employees', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  writeDb(db);
  res.json(db.userData[user.id].employees);
});

app.post('/api/employees', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const employee = employeeFromBody(req.body);
  if (!employee.name || !employee.mobile || !employee.designation) return res.status(400).json({ message: 'Name, mobile, and designation are required' });
  if (employee.mobile.length !== 10) return res.status(400).json({ message: 'Mobile number must be 10 digits' });
  if (employee.payPerDay <= 0 || employee.payPerHour <= 0) return res.status(400).json({ message: 'Daily and hourly pay must be more than zero' });
  const existing = db.userData[user.id].employees.find((item) => normalizeMobile(item.mobile) === employee.mobile);
  const saved = employeeFromBody(employee, existing || {});
  upsertById(db.userData[user.id].employees, saved);
  writeDb(db);
  res.status(existing ? 200 : 201).json(saved);
});

app.put('/api/employees/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const existing = db.userData[user.id].employees.find((item) => item.id === req.params.id);
  if (!existing) return res.status(404).json({ message: 'Employee not found' });
  const employee = employeeFromBody({ ...req.body, id: req.params.id }, existing);
  if (!employee.name || !employee.mobile || !employee.designation) return res.status(400).json({ message: 'Name, mobile, and designation are required' });
  if (employee.mobile.length !== 10) return res.status(400).json({ message: 'Mobile number must be 10 digits' });
  if (employee.payPerDay <= 0 || employee.payPerHour <= 0) return res.status(400).json({ message: 'Daily and hourly pay must be more than zero' });
  upsertById(db.userData[user.id].employees, employee);
  writeDb(db);
  res.json(employee);
});

app.delete('/api/employees/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const before = db.userData[user.id].employees.length;
  db.userData[user.id].employees = db.userData[user.id].employees.filter((item) => item.id !== req.params.id);
  if (db.userData[user.id].employees.length === before) return res.status(404).json({ message: 'Employee not found' });
  writeDb(db);
  res.json({ message: 'Employee deleted' });
});

app.get('/api/attendance', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const month = req.query.month ? String(req.query.month) : '';
  const eventId = req.query.eventId ? String(req.query.eventId) : '';
  const records = db.userData[user.id].attendance.filter((record) => (!month || String(record.date || '').startsWith(month)) && (!eventId || record.eventId === eventId));
  res.json(records);
});

app.post('/api/attendance', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const employee = db.userData[user.id].employees.find((item) => item.id === req.body.employeeId);
  const event = findUserEvent(db, user.id, req.body.eventId);
  const existing = db.userData[user.id].attendance.find((item) => item.employeeId === req.body.employeeId && item.eventId === req.body.eventId && item.date === req.body.date);
  const record = attendanceFromBody({
    ...req.body,
    employeeName: req.body.employeeName || employee?.name || '',
    eventName: req.body.eventName || event?.name || '',
    payPerDay: req.body.payPerDay ?? employee?.payPerDay ?? 0,
    payPerHour: req.body.payPerHour ?? employee?.payPerHour ?? 0,
  }, existing || {});
  if (!record.employeeId || !record.date) return res.status(400).json({ message: 'Employee and date are required' });
  if (record.status === 'partial' && record.hours <= 0) return res.status(400).json({ message: 'Partial attendance requires hours' });
  upsertById(db.userData[user.id].attendance, record);
  writeDb(db);
  res.status(existing ? 200 : 201).json(record);
});

app.get('/api/attendance/monthly.pdf', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const month = String(req.query.month || new Date().toISOString().slice(0, 7));
  const records = db.userData[user.id].attendance.filter((record) => String(record.date || '').startsWith(month));
  return generateAttendancePdf({ res, records, employees: db.userData[user.id].employees, month, businessProfile: db.userData[user.id].businessProfile });
});

app.get('/api/reports/monthly.pdf', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const range = reportRangeFromQuery(req.query);
  if (range.error) return res.status(400).json({ message: range.error });
  return generateMonthlyReportPdf({
    res,
    events: db.userData[user.id].events,
    manualInvoices: db.userData[user.id].manualInvoices,
    range,
    businessProfile: db.userData[user.id].businessProfile,
  });
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

app.get('/api/requirement-lists', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  res.json(db.userData[user.id].requirementLists || []);
});

app.post('/api/requirement-lists', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const list = materialDocumentFromBody(req.body);
  db.userData[user.id].requirementLists = db.userData[user.id].requirementLists || [];
  db.userData[user.id].requirementLists.push(list);
  writeDb(db);
  res.status(201).json(list);
});

app.put('/api/requirement-lists/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  db.userData[user.id].requirementLists = db.userData[user.id].requirementLists || [];
  const existing = db.userData[user.id].requirementLists.find((item) => item.id === req.params.id);
  if (!existing) return res.status(404).json({ message: 'Requirement list not found' });
  Object.assign(existing, materialDocumentFromBody({ ...req.body, id: req.params.id }, existing));
  writeDb(db);
  res.json(existing);
});

app.delete('/api/requirement-lists/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const before = asArray(db.userData[user.id].requirementLists).length;
  db.userData[user.id].requirementLists = asArray(db.userData[user.id].requirementLists)
    .filter((item) => item.id !== req.params.id);
  if (db.userData[user.id].requirementLists.length === before) {
    return res.status(404).json({ message: 'Requirement list not found' });
  }
  writeDb(db);
  res.json({ message: 'Requirement list deleted' });
});

app.get('/api/requirement-lists/:id/pdf', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const list = asArray(db.userData[user.id].requirementLists).find((item) => item.id === req.params.id);
  if (!list) return res.status(404).json({ message: 'Requirement list not found' });
  return generateMaterialDocumentPdf({
    res,
    materialDocument: list,
    businessProfile: db.userData[user.id].businessProfile,
  });
});

app.get('/api/menu-items', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  res.json(db.userData[user.id].menuItems);
});

function handleMenuCatalogPdf(req, res) {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  return generateMenuCatalogPdf({
    res,
    db,
    menuItems: db.userData[user.id].menuItems,
    language: String(req.query.language || 'both'),
    filters: {
      search: req.query.search,
      meal: req.query.meal,
      vegOnly: req.query.vegOnly,
    },
  });
}

app.get('/api/menu-items/pdf', handleMenuCatalogPdf);
app.get('/api/menu-items/export.pdf', handleMenuCatalogPdf);
app.get('/api/menu-catalog.pdf', handleMenuCatalogPdf);

app.post('/api/menu-items', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const list = db.userData[user.id].menuItems;
  const requestedId = String(req.body.id || '').trim();
  const idExists = requestedId && list.some((entry) => entry.id === requestedId);
  const item = {
    id: requestedId && !idExists ? requestedId : nextCatalogId(list, 'MNU'),
    english: req.body.english || '',
    kannada: req.body.kannada || '',
    title: req.body.title || `${req.body.kannada || ''}/${req.body.english || ''}`,
    category: req.body.category || '',
    meals: Array.isArray(req.body.meals) ? req.body.meals : [],
    veg: Boolean(req.body.veg),
  };
  upsertById(list, item);
  writeDb(db);
  res.status(201).json(item);
});

app.put('/api/menu-items/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const list = db.userData[user.id].menuItems;
  const existing = list.find((item) => item.id === req.params.id);
  const item = { ...(existing || {}), ...req.body, id: req.body.id || req.params.id };
  if (item.id !== req.params.id) {
    db.userData[user.id].menuItems = list.filter((entry) => entry.id !== req.params.id);
  }
  upsertById(db.userData[user.id].menuItems, item);
  writeDb(db);
  res.status(existing ? 200 : 201).json(item);
});

app.delete('/api/menu-items/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const references = menuItemReferences(db.userData[user.id], req.params.id);
  if (sendMenuItemReferenceConflict(res, references)) return;
  db.userData[user.id].menuItems = db.userData[user.id].menuItems.filter((entry) => entry.id !== req.params.id);
  writeDb(db);
  res.status(204).end();
});

app.get('/api/raw-materials', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  writeDb(db);
  res.json(db.userData[user.id].rawMaterials);
});

app.post('/api/raw-materials', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const item = { id: req.body.id || makeId('raw'), name: req.body.name || '', category: req.body.category || '', unit: req.body.unit || '' };
  upsertById(db.userData[user.id].rawMaterials, item);
  writeDb(db);
  res.status(201).json(item);
});

app.put('/api/raw-materials/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const existing = db.userData[user.id].rawMaterials.find((item) => item.id === req.params.id);
  if (!existing) return res.status(404).json({ message: 'Raw material not found' });
  const item = { ...existing, ...req.body, id: req.body.id || req.params.id };
  if (item.id !== req.params.id) {
    db.userData[user.id].rawMaterials = db.userData[user.id].rawMaterials.filter((entry) => entry.id !== req.params.id);
  }
  upsertById(db.userData[user.id].rawMaterials, item);
  writeDb(db);
  res.json(item);
});

app.delete('/api/raw-materials/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  db.userData[user.id].rawMaterials = db.userData[user.id].rawMaterials.filter((entry) => entry.id !== req.params.id);
  writeDb(db);
  res.status(204).end();
});

app.get('/api/produce-items', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  writeDb(db);
  res.json(db.userData[user.id].produceItems);
});

app.post('/api/produce-items', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const item = { id: req.body.id || makeId('prd'), name: req.body.name || '', category: req.body.category || '', unit: req.body.unit || '' };
  upsertById(db.userData[user.id].produceItems, item);
  writeDb(db);
  res.status(201).json(item);
});

app.put('/api/produce-items/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const existing = db.userData[user.id].produceItems.find((item) => item.id === req.params.id);
  if (!existing) return res.status(404).json({ message: 'Vegetable/fruit item not found' });
  const item = { ...existing, ...req.body, id: req.body.id || req.params.id };
  if (item.id !== req.params.id) {
    db.userData[user.id].produceItems = db.userData[user.id].produceItems.filter((entry) => entry.id !== req.params.id);
  }
  upsertById(db.userData[user.id].produceItems, item);
  writeDb(db);
  res.json(item);
});

app.delete('/api/produce-items/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  db.userData[user.id].produceItems = db.userData[user.id].produceItems.filter((entry) => entry.id !== req.params.id);
  writeDb(db);
  res.status(204).end();
});

app.get('/api/vessel-items', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  writeDb(db);
  res.json(db.userData[user.id].vesselItems);
});

app.post('/api/vessel-items', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const item = { id: req.body.id || makeId('ves'), name: req.body.name || '', category: req.body.category || '', unit: req.body.unit || '' };
  upsertById(db.userData[user.id].vesselItems, item);
  writeDb(db);
  res.status(201).json(item);
});

app.put('/api/vessel-items/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const existing = db.userData[user.id].vesselItems.find((item) => item.id === req.params.id);
  if (!existing) return res.status(404).json({ message: 'Vessel/utensil item not found' });
  const item = { ...existing, ...req.body, id: req.body.id || req.params.id };
  if (item.id !== req.params.id) {
    db.userData[user.id].vesselItems = db.userData[user.id].vesselItems.filter((entry) => entry.id !== req.params.id);
  }
  upsertById(db.userData[user.id].vesselItems, item);
  writeDb(db);
  res.json(item);
});

app.delete('/api/vessel-items/:id', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  db.userData[user.id].vesselItems = db.userData[user.id].vesselItems.filter((entry) => entry.id !== req.params.id);
  writeDb(db);
  res.status(204).end();
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

app.delete('/api/events/:eventId', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const events = db.userData[user.id].events;
  const before = events.length;
  db.userData[user.id].events = events.filter((event) => event.id !== req.params.eventId);
  if (db.userData[user.id].events.length === before) return res.status(404).json({ message: 'Event not found' });
  db.userData[user.id].attendance = (db.userData[user.id].attendance || []).filter((item) => item.eventId !== req.params.eventId);
  writeDb(db);
  res.json({ ok: true });
});

app.put('/api/events/:eventId/employee-assignments', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  const assignments = Array.isArray(req.body.employeeAssignments) ? req.body.employeeAssignments : [];
  event.employeeAssignments = assignments.map((assignment) => {
    const employee = db.userData[user.id].employees.find((item) => item.id === (assignment.employeeId || assignment.id));
    return employeeAssignmentFromBody({ ...employee, ...assignment });
  }).filter((assignment) => assignment.employeeId && assignment.employeeName);
  for (const assignment of event.employeeAssignments) {
    for (const date of event.dates || []) {
      if (!date.date) continue;
      const existing = db.userData[user.id].attendance.find((item) => item.employeeId === assignment.employeeId && item.eventId === event.id && item.date === date.date);
      if (existing) continue;
      db.userData[user.id].attendance.push(attendanceFromBody({
        employeeId: assignment.employeeId,
        employeeName: assignment.employeeName,
        eventId: event.id,
        eventName: event.name,
        date: date.date,
        status: 'present',
        hours: 8,
        payPerDay: assignment.payPerDay,
        payPerHour: assignment.payPerHour,
      }));
    }
  }
  event.updatedAt = new Date().toISOString();
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
  if (event.dates.some((item) => sameEventDate(item, date))) {
    return res.status(409).json({ message: 'Date already added' });
  }
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
  const nextDate = dateFromBody({ ...req.body, id: req.params.dateId }, date);
  if (event.dates.some((item) => item.id !== date.id && sameEventDate(item, nextDate))) {
    return res.status(409).json({ message: 'Date already added' });
  }
  Object.assign(date, nextDate);
  event.updatedAt = new Date().toISOString();
  writeDb(db);
  res.json(date);
});

app.delete('/api/events/:eventId/dates/:dateId', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  if (!event) return res.status(404).json({ message: 'Event not found' });
  const before = event.dates.length;
  event.dates = event.dates.filter((date) => date.id !== req.params.dateId);
  if (event.dates.length === before) return res.status(404).json({ message: 'Date not found' });
  event.updatedAt = new Date().toISOString();
  writeDb(db);
  res.json(event);
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

app.delete('/api/events/:eventId/dates/:dateId/menu-slots/:slotId', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const event = findUserEvent(db, user.id, req.params.eventId);
  const date = event?.dates.find((item) => item.id === req.params.dateId);
  if (!date) return res.status(404).json({ message: 'Event date not found' });
  const before = date.menuSlots.length;
  date.menuSlots = date.menuSlots.filter((slot) => slot.id !== req.params.slotId);
  if (date.menuSlots.length === before) return res.status(404).json({ message: 'Menu slot not found' });
  event.updatedAt = new Date().toISOString();
  writeDb(db);
  res.json(event);
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
    return generateMenuPdf({ res, db, event, dateId: req.query.dateId || event.dates[0]?.id || event.dates[0]?.date, businessProfile: db.userData[user.id].businessProfile, menuItems: db.userData[user.id].menuItems });
  }
  if (req.params.type === 'all-menus') {
    return generateMenuPdf({ res, db, event, allDates: true, businessProfile: db.userData[user.id].businessProfile, menuItems: db.userData[user.id].menuItems });
  }
  if (!['quotation', 'invoice'].includes(req.params.type)) return res.status(400).json({ message: 'Document type must be quotation, invoice, menu, or all-menus' });
  return generateEventPdf({ res, db, event, type: req.params.type, businessProfile: db.userData[user.id].businessProfile, clients: db.userData[user.id].clients || [] });
});

app.get('/api/documents/upcoming-menus', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const days = Math.max(1, Math.min(14, Number(req.query.days || 3)));
  return generateUpcomingMenusPdf({ res, db, events: db.userData[user.id].events, days, businessProfile: db.userData[user.id].businessProfile, menuItems: db.userData[user.id].menuItems });
});

app.get('/api/documents/consolidated-menus', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const ids = String(req.query.eventIds || '')
    .split(',')
    .map((id) => id.trim())
    .filter(Boolean);
  const idSet = new Set(ids);
  const events = (db.userData[user.id].events || [])
    .filter((event) => idSet.size === 0 || idSet.has(event.id));
  return generateConsolidatedMenusPdf({
    res,
    db,
    events,
    dateFilter: req.query.date ? String(req.query.date) : '',
    startDate: req.query.startDate ? String(req.query.startDate) : '',
    endDate: req.query.endDate ? String(req.query.endDate) : '',
    title: req.query.title ? String(req.query.title).slice(0, 80) : 'Consolidated Menus',
    businessProfile: db.userData[user.id].businessProfile,
    menuItems: db.userData[user.id].menuItems,
  });
});

app.post('/api/documents/consolidated-menus', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const events = asArray(req.body?.events)
    .filter((event) => event && typeof event === 'object')
    .map((event) => ({
      ...event,
      dates: asArray(event.dates).map((date) => ({
        ...date,
        additionalServices: asArray(date.additionalServices),
        menuSlots: asArray(date.menuSlots).map((slot) => ({
          ...slot,
          menuItemIds: asArray(slot.menuItemIds),
          additionalServices: asArray(slot.additionalServices),
          menuImages: asArray(slot.menuImages),
        })),
      })),
    }));
  const exportId = crypto.randomUUID();
  consolidatedMenuExports.set(exportId, {
    userId: user.id,
    events,
    dateFilter: req.body?.date ? String(req.body.date) : '',
    startDate: req.body?.startDate ? String(req.body.startDate) : '',
    endDate: req.body?.endDate ? String(req.body.endDate) : '',
    title: req.body?.title ? String(req.body.title).slice(0, 80) : 'Consolidated Menus',
    createdAt: Date.now(),
  });
  for (const [id, exportPayload] of consolidatedMenuExports.entries()) {
    if (Date.now() - exportPayload.createdAt > 15 * 60 * 1000) {
      consolidatedMenuExports.delete(id);
    }
  }
  res.status(201).json({ id: exportId });
});

app.get('/api/documents/consolidated-menus/:exportId', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const exportPayload = consolidatedMenuExports.get(req.params.exportId);
  if (!exportPayload || exportPayload.userId !== user.id) {
    return res.status(404).json({ message: 'Consolidated menu export expired' });
  }
  return generateConsolidatedMenusPdf({
    res,
    db,
    events: exportPayload.events,
    dateFilter: exportPayload.dateFilter,
    startDate: exportPayload.startDate,
    endDate: exportPayload.endDate,
    title: exportPayload.title,
    businessProfile: db.userData[user.id].businessProfile,
    menuItems: db.userData[user.id].menuItems,
  });
});

function storageCountsFor(db, userId) {
  return {
    users: db.users.length,
    events: db.userData[userId].events.length,
    menuItems: db.universal.menuItems.length,
    rawMaterials: db.universal.rawMaterials.length,
    produceItems: db.universal.produceItems.length,
    vesselItems: db.universal.vesselItems.length,
  };
}

async function supabaseTableCount(table) {
  const { count } = await supabaseRequest(
    supabase.from(table).select('*', { count: 'exact', head: true }).eq('state_id', supabaseStateId),
  );
  return count || 0;
}

app.get('/api/storage/status', async (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  let supabaseStatus = { enabled: Boolean(supabase), connected: false, updatedAt: null };
  if (supabase) {
    try {
      const userCount = await supabaseTableCount('cp_users');
      supabaseStatus = {
        enabled: true,
        connected: true,
        stateId: supabaseStateId,
        liveState: 'tables',
        userCount,
      };
    } catch (error) {
      supabaseStatus = { enabled: true, connected: false, stateId: supabaseStateId, error: error.message };
    }
  }
  res.json({
    storage: 'supabase',
    supabase: supabaseStatus,
    counts: storageCountsFor(db, user.id),
  });
});

app.get('/api/storage/tables', async (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  if (!supabase) return res.status(400).json({ message: 'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are not configured' });
  try {
    const mirrorSync = await syncSupabaseTables(db);
    const counts = {};
    for (const table of supabaseTables) {
      counts[table] = await supabaseTableCount(table);
    }
    res.json({ stateId: supabaseStateId, counts, mirrorSync });
  } catch (error) {
    res.status(500).json({ message: 'Unable to inspect Supabase tables', error: error.message });
  }
});

app.post('/api/storage/import-menu-items-from-supabase', async (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  if (!supabase) return res.status(400).json({ message: 'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are not configured' });
  try {
    const { data: rows } = await supabaseRequest(
      supabase
        .from('cp_menu_items')
        .select('id, english, kannada, title, category, meals, veg, raw')
        .eq('state_id', supabaseStateId)
        .order('id'),
    );
    if (!rows || rows.length === 0) {
      return res.status(404).json({ message: 'No menu items found in cp_menu_items' });
    }
    db.universal = db.universal || {};
    db.universal.menuItems = rows.map((row) => {
      const raw = row.raw && typeof row.raw === 'object' ? row.raw : {};
      return {
        ...raw,
        id: row.id || raw.id || makeId('mnu'),
        english: row.english ?? raw.english ?? '',
        kannada: row.kannada ?? raw.kannada ?? '',
        title: row.title ?? raw.title ?? `${row.kannada || raw.kannada || ''}/${row.english || raw.english || ''}`,
        category: row.category ?? raw.category ?? '',
        meals: asArray(row.meals ?? raw.meals),
        veg: row.veg === null || row.veg === undefined ? Boolean(raw.veg) : Boolean(row.veg),
      };
    });
    writeDb(db);
    await flushSupabaseWrites();
    res.json({
      message: 'Menu items imported from Supabase table',
      count: db.universal.menuItems.length,
    });
  } catch (error) {
    res.status(500).json({ message: 'Unable to import menu items from Supabase table', error: error.message });
  }
});

async function pushLocalToSupabase(req, res) {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  if (!supabase) return res.status(400).json({ message: 'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are not configured' });
  try {
    await saveSupabaseDb(db);
    res.json({
      message: 'Current backend state pushed to Supabase',
      stateId: supabaseStateId,
      counts: storageCountsFor(db, user.id),
    });
  } catch (error) {
    res.status(500).json({ message: 'Unable to push to Supabase', error: error.message });
  }
}

app.post('/api/storage/push-local-to-supabase', pushLocalToSupabase);

const adminDashboardPath = path.join(__dirname, '..', 'AdminDashboard');
if (fs.existsSync(path.join(adminDashboardPath, 'pages', 'login.html'))) {
  app.use('/admin/assets', express.static(path.join(adminDashboardPath, 'assets')));
  app.use('/admin/pages', express.static(path.join(adminDashboardPath, 'pages')));
  app.get(['/admin', '/admin/'], (req, res) => {
    res.redirect('/admin/pages/login.html');
  });
}

const webBuildPath = path.join(__dirname, '..', 'frontend', 'build', 'web');
const webMimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
};

function serveBuiltWebApp(req, res, next) {
  if (req.path.startsWith('/api') || req.path === '/health') return next();
  if (!fs.existsSync(path.join(webBuildPath, 'index.html'))) return next();
  const requestPath = decodeURIComponent((req.path || '/').split('?')[0]);
  const safePath = path.normalize(requestPath).replace(/^(\.\.[/\\])+/, '').replace(/^[/\\]+/, '');
  let filePath = path.join(webBuildPath, safePath || 'index.html');
  if (!filePath.startsWith(webBuildPath)) filePath = path.join(webBuildPath, 'index.html');
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(webBuildPath, 'index.html');
  }
  const ext = path.extname(filePath).toLowerCase();
  res.setHeader('Content-Type', webMimeTypes[ext] || 'application/octet-stream');
  fs.createReadStream(filePath).on('error', next).pipe(res);
}

app.use(serveBuiltWebApp);
app.use((req, res) => res.status(404).json({ message: 'Not found' }));

if (require.main === module) {
  initializeStorage().then(() => {
    app.listen(port, '0.0.0.0', () => {
      console.log(`CaterPro API running on port ${port}`);
    });
  }).catch((error) => {
    console.error('Unable to initialize CaterPro storage:', error);
    process.exit(1);
  });
}

module.exports = {
  boxedInvoiceBusinessProfile,
  emptyBusinessProfile,
  generateManualInvoicePdf,
};
