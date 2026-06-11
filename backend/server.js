const express = require('express');
const swaggerUi = require('swagger-ui-express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const PDFDocument = require('pdfkit');
const { Pool } = require('pg');

const app = express();
const dbPath = path.join(__dirname, 'db.json');
const universalCatalogBackupPath = path.join(__dirname, 'universal-catalog.backup.json');
const port = Number(process.env.PORT || 8787);
const databaseUrl = process.env.DATABASE_URL || '';
const pgStateId = process.env.PG_STATE_ID || 'default';
const allowJsonStorage = process.env.ALLOW_DB_JSON_STORAGE === 'true';
const pgPool = databaseUrl ? new Pool({
  connectionString: databaseUrl,
  ssl: process.env.PGSSL === 'false' ? false : { rejectUnauthorized: false },
}) : null;
let runtimeDb = null;
let pendingPostgresWrite = Promise.resolve();

app.use(express.json({ limit: '50mb' }));
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

function readLocalDb() {
  const db = JSON.parse(fs.readFileSync(dbPath, 'utf8').replace(/^\uFEFF/, ''));
  ensureUniversal(db);
  return db;
}

function readDb() {
  if (!runtimeDb) runtimeDb = readLocalDb();
  ensureUniversal(runtimeDb);
  return runtimeDb;
}

function writeDb(db) {
  ensureUniversal(db);
  runtimeDb = db;
  persistUniversalCatalogBackup(db.universal);
  if (allowJsonStorage) {
    fs.writeFileSync(dbPath, `${JSON.stringify(db, null, 2)}\n`);
  }
  schedulePostgresSave(db);
}

async function ensurePostgresStateTable() {
  if (!pgPool) return;
  await pgPool.query(`
    create table if not exists caterpro_state (
      id text primary key,
      data jsonb not null,
      updated_at timestamptz not null default now()
    )
  `);
}

async function loadPostgresDb() {
  if (!pgPool) return null;
  await ensurePostgresStateTable();
  const result = await pgPool.query('select data from caterpro_state where id = $1', [pgStateId]);
  if (result.rows.length === 0) return null;
  const db = result.rows[0].data;
  ensureUniversal(db);
  return db;
}

async function savePostgresDb(db) {
  if (!pgPool) return;
  await ensurePostgresStateTable();
  await pgPool.query(
    `insert into caterpro_state (id, data, updated_at)
     values ($1, $2::jsonb, now())
     on conflict (id) do update set data = excluded.data, updated_at = now()`,
    [pgStateId, JSON.stringify(db)],
  );
  await syncRelationalTables(db);
}

function asJson(value) {
  return JSON.stringify(value ?? null);
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

async function ensureRelationalTables(client) {
  await client.query(`
    create table if not exists cp_users (
      state_id text not null,
      id text not null,
      name text,
      email text,
      role text,
      raw jsonb not null,
      primary key (state_id, id)
    );

    create table if not exists cp_business_profiles (
      state_id text not null,
      user_id text not null,
      business_name text,
      service_type text,
      gstin text,
      gst_type text,
      gst_rate numeric,
      phone text,
      email text,
      raw jsonb not null,
      primary key (state_id, user_id)
    );

    create table if not exists cp_clients (
      state_id text not null,
      user_id text not null,
      id text not null,
      name text,
      mobile text,
      city text,
      raw jsonb not null,
      primary key (state_id, user_id, id)
    );

    create table if not exists cp_employees (
      state_id text not null,
      user_id text not null,
      id text not null,
      name text,
      mobile text,
      designation text,
      pay_per_day numeric,
      pay_per_hour numeric,
      raw jsonb not null,
      primary key (state_id, user_id, id)
    );

    create table if not exists cp_events (
      state_id text not null,
      user_id text not null,
      id text not null,
      name text,
      primary_client text,
      mobile text,
      venue text,
      status text,
      notes text,
      add_ons jsonb not null default '[]'::jsonb,
      raw jsonb not null,
      primary key (state_id, user_id, id)
    );

    create table if not exists cp_event_dates (
      state_id text not null,
      user_id text not null,
      event_id text not null,
      id text not null,
      event_date text,
      label text,
      additional_services jsonb not null default '[]'::jsonb,
      raw jsonb not null,
      primary key (state_id, user_id, event_id, id)
    );

    create table if not exists cp_menu_slots (
      state_id text not null,
      user_id text not null,
      event_id text not null,
      date_id text not null,
      id text not null,
      type text,
      delivery_time text,
      pax integer,
      price_per_pax integer,
      enabled boolean,
      menu_item_ids jsonb not null default '[]'::jsonb,
      additional_services jsonb not null default '[]'::jsonb,
      raw jsonb not null,
      primary key (state_id, user_id, event_id, date_id, id)
    );

    create table if not exists cp_event_payments (
      state_id text not null,
      user_id text not null,
      event_id text not null,
      id text not null,
      amount integer,
      payment_date text,
      mode text,
      reference text,
      settled boolean,
      raw jsonb not null,
      primary key (state_id, user_id, event_id, id)
    );

    create table if not exists cp_event_assignments (
      state_id text not null,
      user_id text not null,
      event_id text not null,
      employee_id text not null,
      name text,
      designation text,
      pay_per_day numeric,
      pay_per_hour numeric,
      raw jsonb not null,
      primary key (state_id, user_id, event_id, employee_id)
    );

    create table if not exists cp_attendance (
      state_id text not null,
      user_id text not null,
      event_id text not null,
      employee_id text not null,
      attendance_date text not null,
      status text,
      hours numeric,
      pay_per_day numeric,
      pay_per_hour numeric,
      raw jsonb not null,
      primary key (state_id, user_id, event_id, employee_id, attendance_date)
    );

    create table if not exists cp_additional_services (
      state_id text not null,
      user_id text not null,
      id text not null,
      name text,
      unit text,
      price numeric,
      raw jsonb not null,
      primary key (state_id, user_id, id)
    );

    create table if not exists cp_custom_menus (
      state_id text not null,
      user_id text not null,
      id text not null,
      name text,
      type text,
      item_ids jsonb not null default '[]'::jsonb,
      raw jsonb not null,
      primary key (state_id, user_id, id)
    );

    create table if not exists cp_requirement_lists (
      state_id text not null,
      user_id text not null,
      id text not null,
      type text,
      title text,
      item_count integer,
      raw jsonb not null,
      primary key (state_id, user_id, id)
    );

    create table if not exists cp_manual_invoices (
      state_id text not null,
      user_id text not null,
      id text not null,
      invoice_number text,
      client_name text,
      mobile text,
      event_name text,
      event_date text,
      invoice_date text,
      total integer,
      pending integer,
      raw jsonb not null,
      primary key (state_id, user_id, id)
    );

    create table if not exists cp_manual_invoice_items (
      state_id text not null,
      user_id text not null,
      invoice_id text not null,
      id text not null,
      title text,
      quantity integer,
      rate integer,
      amount integer,
      raw jsonb not null,
      primary key (state_id, user_id, invoice_id, id)
    );

    create table if not exists cp_menu_items (
      state_id text not null,
      id text not null,
      english text,
      kannada text,
      title text,
      category text,
      meals jsonb not null default '[]'::jsonb,
      veg boolean,
      raw jsonb not null,
      primary key (state_id, id)
    );

    create table if not exists cp_raw_materials (
      state_id text not null,
      id text not null,
      name text,
      category text,
      unit text,
      raw jsonb not null,
      primary key (state_id, id)
    );

    create table if not exists cp_produce_items (
      state_id text not null,
      id text not null,
      name text,
      category text,
      unit text,
      raw jsonb not null,
      primary key (state_id, id)
    );

    create table if not exists cp_vessel_items (
      state_id text not null,
      id text not null,
      name text,
      category text,
      unit text,
      raw jsonb not null,
      primary key (state_id, id)
    );
  `);
}

async function syncRelationalTables(db) {
  if (!pgPool) return;
  const client = await pgPool.connect();
  try {
    await ensureRelationalTables(client);
    await client.query('begin');
    const tables = [
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
      'cp_employees',
      'cp_clients',
      'cp_business_profiles',
      'cp_users',
      'cp_menu_items',
      'cp_raw_materials',
      'cp_produce_items',
      'cp_vessel_items',
    ];
    for (const table of tables) {
      await client.query(`delete from ${table} where state_id = $1`, [pgStateId]);
    }

    for (const user of asArray(db.users)) {
      await client.query(
        `insert into cp_users (state_id, id, name, email, role, raw)
         values ($1, $2, $3, $4, $5, $6::jsonb)`,
        [pgStateId, user.id || '', user.name || '', user.email || '', user.role || '', asJson(user)],
      );
      const userData = ensureUserDataShape(db.userData?.[user.id] || emptyUserData());
      const profile = userData.businessProfile || emptyBusinessProfile();
      await client.query(
        `insert into cp_business_profiles
         (state_id, user_id, business_name, service_type, gstin, gst_type, gst_rate, phone, email, raw)
         values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb)`,
        [pgStateId, user.id, profile.businessName || '', profile.serviceType || '', profile.gstin || '', profile.gstType || '', Number(profile.gstRate || 0), profile.phone || '', profile.email || '', asJson(profile)],
      );

      for (const clientItem of asArray(userData.clients)) {
        await client.query(
          `insert into cp_clients (state_id, user_id, id, name, mobile, city, raw)
           values ($1,$2,$3,$4,$5,$6,$7::jsonb)`,
          [pgStateId, user.id, clientItem.id || '', clientItem.name || '', clientItem.mobile || '', clientItem.city || clientItem.address || '', asJson(clientItem)],
        );
      }

      for (const employee of asArray(userData.employees)) {
        await client.query(
          `insert into cp_employees
           (state_id, user_id, id, name, mobile, designation, pay_per_day, pay_per_hour, raw)
           values ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb)`,
          [pgStateId, user.id, employee.id || '', employee.name || '', employee.mobile || '', employee.designation || '', Number(employee.payPerDay || 0), Number(employee.payPerHour || 0), asJson(employee)],
        );
      }

      for (const service of asArray(userData.additionalServices)) {
        await client.query(
          `insert into cp_additional_services (state_id, user_id, id, name, unit, price, raw)
           values ($1,$2,$3,$4,$5,$6,$7::jsonb)`,
          [pgStateId, user.id, service.id || '', service.name || '', service.unit || '', Number(service.price || 0), asJson(service)],
        );
      }

      for (const customMenu of asArray(userData.customMenus)) {
        await client.query(
          `insert into cp_custom_menus (state_id, user_id, id, name, type, item_ids, raw)
           values ($1,$2,$3,$4,$5,$6::jsonb,$7::jsonb)`,
          [pgStateId, user.id, customMenu.id || '', customMenu.name || '', customMenu.type || '', asJson(asArray(customMenu.itemIds)), asJson(customMenu)],
        );
      }

      for (const list of asArray(userData.requirementLists)) {
        await client.query(
          `insert into cp_requirement_lists (state_id, user_id, id, type, title, item_count, raw)
           values ($1,$2,$3,$4,$5,$6,$7::jsonb)`,
          [pgStateId, user.id, list.id || '', list.type || '', list.title || '', asArray(list.items).length, asJson(list)],
        );
      }

      for (const event of asArray(userData.events)) {
        await client.query(
          `insert into cp_events
           (state_id, user_id, id, name, primary_client, mobile, venue, status, notes, add_ons, raw)
           values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb,$11::jsonb)`,
          [pgStateId, user.id, event.id || '', event.name || '', event.primaryClient || '', event.mobile || '', event.venue || '', event.status || '', event.notes || '', asJson(asArray(event.addOns)), asJson(event)],
        );
        for (const date of asArray(event.dates)) {
          await client.query(
            `insert into cp_event_dates
             (state_id, user_id, event_id, id, event_date, label, additional_services, raw)
             values ($1,$2,$3,$4,$5,$6,$7::jsonb,$8::jsonb)
             on conflict (state_id, user_id, event_id, id)
             do update set
               event_date = excluded.event_date,
               label = excluded.label,
               additional_services = excluded.additional_services,
               raw = excluded.raw`,
            [pgStateId, user.id, event.id || '', date.id || date.date || '', date.date || '', date.label || '', asJson(asArray(date.additionalServices)), asJson(date)],
          );
          for (const slot of asArray(date.menuSlots)) {
            await client.query(
              `insert into cp_menu_slots
               (state_id, user_id, event_id, date_id, id, type, delivery_time, pax, price_per_pax, enabled, menu_item_ids, additional_services, raw)
               values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb,$12::jsonb,$13::jsonb)
               on conflict (state_id, user_id, event_id, date_id, id)
               do update set
                 type = excluded.type,
                 delivery_time = excluded.delivery_time,
                 pax = excluded.pax,
                 price_per_pax = excluded.price_per_pax,
                 enabled = excluded.enabled,
                 menu_item_ids = excluded.menu_item_ids,
                 additional_services = excluded.additional_services,
                 raw = excluded.raw`,
              [pgStateId, user.id, event.id || '', date.id || date.date || '', slot.id || `${slot.type || 'slot'}-${date.id || date.date || ''}`, slot.type || '', slot.time || '', Number(slot.pax || 0), Number(slot.pricePerPax || 0), slot.enabled !== false, asJson(asArray(slot.menuItemIds)), asJson(asArray(slot.additionalServices)), asJson(slot)],
            );
          }
        }
        for (const payment of asArray(event.payments)) {
          await client.query(
            `insert into cp_event_payments
             (state_id, user_id, event_id, id, amount, payment_date, mode, reference, settled, raw)
             values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb)`,
            [pgStateId, user.id, event.id || '', payment.id || '', Number(payment.amount || 0), payment.date || '', payment.mode || '', payment.reference || '', payment.settled === true, asJson(payment)],
          );
        }
        for (const assignment of asArray(event.employeeAssignments)) {
          await client.query(
            `insert into cp_event_assignments
             (state_id, user_id, event_id, employee_id, name, designation, pay_per_day, pay_per_hour, raw)
             values ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb)
             on conflict (state_id, user_id, event_id, employee_id)
             do update set
               name = excluded.name,
               designation = excluded.designation,
               pay_per_day = excluded.pay_per_day,
               pay_per_hour = excluded.pay_per_hour,
               raw = excluded.raw`,
            [pgStateId, user.id, event.id || '', assignment.employeeId || assignment.id || '', assignment.name || '', assignment.designation || '', Number(assignment.payPerDay || 0), Number(assignment.payPerHour || 0), asJson(assignment)],
          );
        }
      }

      for (const attendance of asArray(userData.attendance)) {
        await client.query(
          `insert into cp_attendance
           (state_id, user_id, event_id, employee_id, attendance_date, status, hours, pay_per_day, pay_per_hour, raw)
           values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb)
           on conflict (state_id, user_id, event_id, employee_id, attendance_date)
           do update set
             status = excluded.status,
             hours = excluded.hours,
             pay_per_day = excluded.pay_per_day,
             pay_per_hour = excluded.pay_per_hour,
             raw = excluded.raw`,
          [pgStateId, user.id, attendance.eventId || '', attendance.employeeId || '', attendance.date || '', attendance.status || '', Number(attendance.hours || 0), Number(attendance.payPerDay || 0), Number(attendance.payPerHour || 0), asJson(attendance)],
        );
      }

      for (const invoice of asArray(userData.manualInvoices)) {
        await client.query(
          `insert into cp_manual_invoices
           (state_id, user_id, id, invoice_number, client_name, mobile, event_name, event_date, invoice_date, total, pending, raw)
           values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::jsonb)`,
          [pgStateId, user.id, invoice.id || '', invoice.invoiceNumber || '', invoice.clientName || '', invoice.mobile || '', invoice.eventName || '', invoice.eventDate || '', invoice.invoiceDate || '', Number(invoice.total || 0), Number(invoice.pending || 0), asJson(invoice)],
        );
        for (const item of asArray(invoice.items)) {
          await client.query(
          `insert into cp_manual_invoice_items
             (state_id, user_id, invoice_id, id, title, quantity, rate, amount, raw)
             values ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb)
             on conflict (state_id, user_id, invoice_id, id)
             do update set
               title = excluded.title,
               quantity = excluded.quantity,
               rate = excluded.rate,
               amount = excluded.amount,
               raw = excluded.raw`,
            [pgStateId, user.id, invoice.id || '', item.id || item.title || '', item.title || '', Number(item.quantity || 0), Number(item.rate || 0), Number(item.amount || 0), asJson(item)],
          );
        }
      }
    }

    for (const item of asArray(db.universal?.menuItems)) {
      await client.query(
        `insert into cp_menu_items (state_id, id, english, kannada, title, category, meals, veg, raw)
         values ($1,$2,$3,$4,$5,$6,$7::jsonb,$8,$9::jsonb)`,
        [pgStateId, item.id || '', item.english || '', item.kannada || '', item.title || '', item.category || '', asJson(asArray(item.meals)), item.veg === true, asJson(item)],
      );
    }
    for (const item of asArray(db.universal?.rawMaterials)) {
      await client.query(
        `insert into cp_raw_materials (state_id, id, name, category, unit, raw)
         values ($1,$2,$3,$4,$5,$6::jsonb)`,
        [pgStateId, item.id || '', item.name || '', item.category || '', item.unit || '', asJson(item)],
      );
    }
    for (const item of asArray(db.universal?.produceItems)) {
      await client.query(
        `insert into cp_produce_items (state_id, id, name, category, unit, raw)
         values ($1,$2,$3,$4,$5,$6::jsonb)`,
        [pgStateId, item.id || '', item.name || '', item.category || '', item.unit || '', asJson(item)],
      );
    }
    for (const item of asArray(db.universal?.vesselItems)) {
      await client.query(
        `insert into cp_vessel_items (state_id, id, name, category, unit, raw)
         values ($1,$2,$3,$4,$5,$6::jsonb)`,
        [pgStateId, item.id || '', item.name || '', item.category || '', item.unit || '', asJson(item)],
      );
    }

    await client.query('commit');
  } catch (error) {
    await client.query('rollback').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

function schedulePostgresSave(db) {
  if (!pgPool) return;
  const snapshot = JSON.parse(JSON.stringify(db));
  pendingPostgresWrite = pendingPostgresWrite
    .catch(() => {})
    .then(() => savePostgresDb(snapshot))
    .catch((error) => console.error('PostgreSQL sync failed:', error.message));
}

async function flushPostgresWrites() {
  await pendingPostgresWrite.catch(() => {});
}

async function initializeStorage() {
  const localDb = readLocalDb();
  if (!pgPool) {
    if (allowJsonStorage) {
      runtimeDb = localDb;
      console.log('CaterPro storage: local db.json');
      return;
    }
    throw new Error('DATABASE_URL is required. PostgreSQL storage is mandatory.');
  }
  const postgresDb = await loadPostgresDb();
  if (postgresDb) {
    postgresDb.universal = mergeProtectedUniversalCatalog(localDb.universal || {}, postgresDb.universal || {});
    runtimeDb = postgresDb;
    await savePostgresDb(runtimeDb);
    console.log(`CaterPro storage: loaded PostgreSQL state "${pgStateId}"`);
    return;
  }
  runtimeDb = localDb;
  await savePostgresDb(runtimeDb);
  console.log(`CaterPro storage: seeded PostgreSQL state "${pgStateId}" from db.json`);
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

function requireAdminUser(req, res, db) {
  const user = requireUser(req, res, db);
  if (!user) return null;
  if (String(user.email || '').toLowerCase() !== 'admin@caterpro.in') {
    res.status(403).json({ message: 'Admin access required' });
    return null;
  }
  return user;
}

function emptyUserData() {
  return { events: [], clients: [], employees: [], attendance: [], additionalServices: [], customMenus: [], requirementLists: [], payments: [], manualInvoices: [], businessProfile: emptyBusinessProfile() };
}

function emptyBusinessProfile() {
  return { businessName: '', serviceType: '', gstin: '', gstType: 'cgst_sgst', gstRate: 5, pan: '', address: '', phone: '', email: '', bankName: '', accountNumber: '', terms: '', logoBase64: '', signatureBase64: '', qrBase64: '', documentTemplate: 'modern', invoiceTextScale: 1 };
}

function defaultEmployees() {
  return [
    { id: 'emp_default_001', name: 'Ramesh K', age: 32, mobile: '9000000001', designation: 'Chef', payPerDay: 1200, payPerHour: 150 },
    { id: 'emp_default_002', name: 'Suresh P', age: 28, mobile: '9000000002', designation: 'Server', payPerDay: 700, payPerHour: 90 },
    { id: 'emp_default_003', name: 'Manjunath S', age: 35, mobile: '9000000003', designation: 'Supervisor', payPerDay: 1000, payPerHour: 125 },
    { id: 'emp_default_004', name: 'Lakshmi H', age: 30, mobile: '9000000004', designation: 'Cleaning', payPerDay: 600, payPerHour: 75 },
  ].map((employee) => ({ ...employee, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() }));
}

function ensureUserDataShape(userData) {
  userData.events = userData.events || [];
  userData.clients = userData.clients || [];
  userData.employees = userData.employees || [];
  if (userData.employees.length === 0) userData.employees = defaultEmployees();
  userData.employees = userData.employees.map((employee) => ({ ...employee, payPerHour: Number(employee.payPerHour ?? (employee.payPerDay ? Math.round(Number(employee.payPerDay) / 8) : 0)) }));
  userData.events = userData.events.map((event) => normalizeEventShape({ employeeAssignments: [], ...event }));
  userData.attendance = userData.attendance || [];
  userData.attendance = userData.attendance.map((record) => ({ ...record, payPerHour: Number(record.payPerHour ?? (record.payPerDay ? Math.round(Number(record.payPerDay) / 8) : 0)) }));
  userData.attendance = dedupeBy(userData.attendance, (record) => [record.eventId, record.employeeId, record.date].join('|'));
  userData.additionalServices = userData.additionalServices || [];
  userData.customMenus = userData.customMenus || [];
  userData.requirementLists = asArray(userData.requirementLists).map((item) => materialDocumentFromBody(item));
  userData.payments = userData.payments || [];
  userData.manualInvoices = userData.manualInvoices || [];
  userData.businessProfile = { ...emptyBusinessProfile(), ...(userData.businessProfile || {}) };
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

function readUniversalCatalogBackup() {
  if (!fs.existsSync(universalCatalogBackupPath)) return {};
  try {
    const backup = JSON.parse(fs.readFileSync(universalCatalogBackupPath, 'utf8'));
    return backup && typeof backup === 'object' && !Array.isArray(backup) ? backup : {};
  } catch {
    return {};
  }
}

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

function persistUniversalCatalogBackup(universal = {}) {
  const previous = readUniversalCatalogBackup();
  const backup = mergeProtectedUniversalCatalog(previous, universal);
  fs.writeFileSync(universalCatalogBackupPath, `${JSON.stringify(backup, null, 2)}\n`);
}

function ensureUniversal(db) {
  db.universal = db.universal || {};
  const backup = readUniversalCatalogBackup();
  db.universal.menuItems = Array.isArray(db.universal.menuItems) && db.universal.menuItems.length > 0 ? db.universal.menuItems : backup.menuItems || [];
  db.universal.rawMaterials = Array.isArray(db.universal.rawMaterials) && db.universal.rawMaterials.length > 0 ? db.universal.rawMaterials : backup.rawMaterials || [];
  db.universal.produceItems = Array.isArray(db.universal.produceItems) && db.universal.produceItems.length > 0 ? db.universal.produceItems : backup.produceItems || [];
  db.universal.vesselItems = Array.isArray(db.universal.vesselItems) && db.universal.vesselItems.length > 0 ? db.universal.vesselItems : backup.vesselItems || [];
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
    type: ['raw', 'produce', 'vessels'].includes(body.type) ? body.type : existing.type || 'raw',
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
    menuSlots: Array.isArray(body.menuSlots)
      ? body.menuSlots.map((slot) => menuSlotFromBody(slot))
      : existing.menuSlots || [],
    additionalServices: Array.isArray(body.additionalServices)
      ? body.additionalServices.map(serviceFromBody)
      : existing.additionalServices || [],
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
  const menuTotal = event.dates.reduce((dateSum, date) => dateSum + date.menuSlots.reduce((slotSum, slot) => slotSum + Number(slot.pax || 0) * Number(slot.pricePerPax || 0), 0), 0);
  const serviceTotal = event.dates.reduce((dateSum, date) => {
    const dateServices = (date.additionalServices || []).reduce((sum, service) => sum + Number(service.price || 0), 0);
    const slotServices = (date.menuSlots || []).reduce((slotSum, slot) => slotSum + (slot.additionalServices || []).reduce((sum, service) => sum + Number(service.price || 0), 0), 0);
    return dateSum + dateServices + slotServices;
  }, 0);
  const addOnTotal = (event.addOns || []).reduce((sum, addOn) => sum + Number(addOn.cost || 0), 0);
  const paid = event.payments.reduce((sum, payment) => sum + Number(payment.amount || 0), 0);
  const discount = event.payments.reduce((sum, payment) => sum + Number(payment.settledDiscount || 0), 0);
  const total = menuTotal + serviceTotal + addOnTotal;
  return { menuTotal, serviceTotal, addOnTotal, total, paid, discount, balance: Math.max(0, total - paid - discount) };
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

function menuTitleById(db, id) {
  const item = (db.universal?.menuItems || []).find((menuItem) => menuItem.id === id);
  return item ? item.english || item.title || id : id;
}

function menuDisplayById(db, id) {
  const item = (db.universal?.menuItems || []).find((menuItem) => menuItem.id === id);
  if (!item) return id;
  return item.kannada ? `${repairMojibake(item.kannada)} / ${repairMojibake(item.english)}` : repairMojibake(item.english || item.title || id);
}

function invoiceMenuDisplayById(db, id) {
  const item = (db.universal?.menuItems || []).find((menuItem) => menuItem.id === id);
  if (!item) return id;
  return repairMojibake(item.english || item.title || item.kannada || id);
}

function menuPartsById(db, id) {
  const item = (db.universal?.menuItems || []).find((menuItem) => menuItem.id === id);
  if (!item) return { kannada: '', english: id };
  return { kannada: repairMojibake(item.kannada || ''), english: repairMojibake(item.english || item.title || id) };
}

function hasKannadaText(value) {
  return /[\u0C80-\u0CFF]/.test(String(value || ''));
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
    doc.fillColor(color).font(fonts.kannada).fontSize(fontSize).text(kannada, x, y, textOptions);
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

function setPdfAttachment(res, parts) {
  res.setHeader('Content-Disposition', `attachment; filename="${pdfFilename(parts)}"`);
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
  const normalized = template === 'premium' ? 'elegant' : template === 'minimal' ? 'classic' : template;
  const themes = {
    classic: { name: 'classic', primary: '#111827', secondary: '#6b7280', accent: '#374151', soft: '#f3f4f6', page: '#ffffff', ink: '#111827', muted: '#4b5563', scale: businessProfile.invoiceTextScale || 1 },
    elegant: { name: 'elegant', primary: '#1f3b32', secondary: '#b8943c', accent: '#7b1b44', soft: '#fbf6e8', page: '#ffffff', ink: '#202124', muted: '#5f6368', scale: businessProfile.invoiceTextScale || 1 },
    modern: { name: 'modern', primary: '#06445d', secondary: '#f2a51a', accent: '#1c7c8a', soft: '#fff4db', page: '#ffffff', ink: '#202124', muted: '#59656b', scale: businessProfile.invoiceTextScale || 1 },
  };
  return themes[normalized] || themes.modern;
}

function documentMetrics(theme = documentTheme()) {
  if (theme.name === 'elegant') return { left: 106, right: 559, width: 453, tableY: 228 };
  return { left: 36, right: 559, width: 523, tableY: theme.name === 'classic' ? 238 : 232 };
}

function writeDocumentHeader(doc, title, event, number, fonts, businessProfile = emptyBusinessProfile()) {
  const theme = documentTheme(businessProfile);
  const businessName = businessProfile.businessName || 'CaterPro';
  const contactLine = [businessProfile.phone, businessProfile.email].filter(Boolean).join(' | ');
  const taxLine = [businessProfile.gstin ? `GSTIN: ${businessProfile.gstin}` : '', businessProfile.pan ? `PAN: ${businessProfile.pan}` : ''].filter(Boolean).join(' | ');
  doc.rect(0, 0, doc.page.width, doc.page.height).fill(theme.page);
  if (theme.name === 'classic') {
    doc.rect(36, 28, 523, 76).strokeColor(theme.ink).lineWidth(1).stroke();
    doc.moveTo(366, 28).lineTo(366, 104).strokeColor(theme.ink).lineWidth(0.7).stroke();
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(16).text(businessName, 52, 40, { width: 290 });
    doc.fillColor(theme.muted).font(fonts.regular).fontSize(7.5).text(businessProfile.address || 'Catering event management', 52, 62, { width: 290, height: 16 });
    if (contactLine) doc.text(contactLine, 52, 80, { width: 290 });
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(17).text(title, 388, 40, { width: 142, align: 'right' });
    doc.fillColor(theme.muted).font(fonts.regular).fontSize(7.5).text(number, 388, 64, { width: 142, align: 'right' });
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
    doc.fillColor(theme.muted).font(fonts.regular).fontSize(7.5).text(businessProfile.address || 'Catering event management', 106, 58, { width: 260, height: 16 });
    if (contactLine) doc.text(contactLine, 106, 78, { width: 260 });
    doc.fillColor(theme.primary).font(fonts.bold).fontSize(23).text(title, 392, 34, { width: 148, align: 'right' });
    doc.fillColor(theme.secondary).font(fonts.bold).fontSize(7.5).text(number, 392, 66, { width: 148, align: 'right' });
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
  doc.font(fonts.regular).fontSize(7.5).text(businessProfile.address || 'Catering event management', 116, 64, { width: 258, height: 17 });
  if (contactLine) doc.text(contactLine, 116, 84, { width: 258 });
  doc.font(fonts.bold).fontSize(20).text(title, 390, 42, { width: 140, align: 'right' });
  doc.fillColor('#f6f2df').font(fonts.regular).fontSize(7.5).text(number, 390, 68, { width: 140, align: 'right' });
  if (taxLine) doc.text(taxLine, 330, 84, { width: 200, align: 'right' });
}

function documentInfoSection(doc, title, event, number, fonts, businessProfile, isInvoice) {
  const theme = documentTheme(businessProfile);
  const metrics = documentMetrics(theme);
  const hasBusinessGst = Boolean(String(businessProfile.gstin || '').trim());
  const boxX = metrics.left;
  const boxW = metrics.width;
  const boxY = theme.name === 'classic' ? 116 : theme.name === 'elegant' ? 122 : 118;
  const boxH = 96;
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
  doc.fillColor(theme.ink).font(fonts.bold).fontSize(10.5).text(event.primaryClient || 'Customer', boxX + 14, boxY + 33, { width: 220 });
  const addressLine = event.clientAddress ? `Address: ${event.clientAddress}` : event.venue ? `Venue: ${event.venue}` : 'Venue: -';
  doc.fillColor(theme.muted).font(fonts.regular).fontSize(8)
    .text(event.mobile ? `Mobile: ${event.mobile}` : 'Mobile: -', boxX + 14, boxY + 51)
    .text(addressLine, boxX + 14, boxY + 66, { width: 220, height: 13 })
    .text(`Event: ${event.name || 'Untitled Event'}`, boxX + 14, boxY + 81, { width: 220 });
  if (hasBusinessGst && event.clientGst) doc.text(`Client GSTIN: ${event.clientGst}`, boxX + 14, boxY + 92, { width: 220 });

  const eventDates = event.dates.map((date) => prettyDate(date.date)).join(', ') || '-';
  const detailX = boxX + boxW - 238;
  doc.fillColor(theme.primary).font(fonts.bold).fontSize(10).text(`${title} Details`, detailX, boxY + 15, { width: 220, align: 'right' });
  doc.fillColor(theme.ink).font(fonts.regular).fontSize(8)
    .text(`${title} No: ${number}`, detailX, boxY + 35, { width: 220, align: 'right' })
    .text(`${title} Date: ${prettyDate(new Date().toISOString().slice(0, 10))}`, detailX, boxY + 51, { width: 220, align: 'right' })
    .text(`Event Date: ${eventDates}`, detailX, boxY + 67, { width: 220, align: 'right' });
  if (!isInvoice) doc.text('Valid Till: 15 days from quotation date', detailX, boxY + 83, { width: 220, align: 'right' });
}

function invoiceTableLayout(theme = documentTheme()) {
  if (theme.name === 'elegant') {
    return { x: 112, w: 447, descX: 126, descW: 194, qtyX: 328, qtyW: 46, rateX: 384, rateW: 62, amountX: 462, amountW: 78 };
  }
  if (theme.name === 'classic') {
    return { x: 36, w: 523, descX: 48, descW: 238, qtyX: 300, qtyW: 58, rateX: 372, rateW: 70, amountX: 460, amountW: 82 };
  }
  return { x: 36, w: 523, descX: 54, descW: 234, qtyX: 310, qtyW: 52, rateX: 374, rateW: 68, amountX: 462, amountW: 80 };
}

function tableHeader(doc, y, fonts, theme = documentTheme()) {
  const layout = invoiceTableLayout(theme);
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
  doc.font(fonts.bold).fontSize(8 * Math.min(theme.scale || 1, 1.12))
    .text('Description', layout.descX, y + (theme.name === 'modern' ? 10 : 7), { width: layout.descW })
    .text('Pax/Qty', layout.qtyX, y + (theme.name === 'modern' ? 10 : 7), { width: layout.qtyW, align: 'right' })
    .text('Rate', layout.rateX, y + (theme.name === 'modern' ? 10 : 7), { width: layout.rateW, align: 'right' })
    .text('Amount', layout.amountX, y + (theme.name === 'modern' ? 10 : 7), { width: layout.amountW, align: 'right' });
}

function ensurePageSpace(doc, y, needed = 44, onNewPage = null) {
  if (y + needed < 780) return y;
  doc.addPage();
  if (onNewPage) onNewPage();
  return 44;
}

function drawInvoiceRow(doc, y, fonts, columns, shaded = false, theme = documentTheme()) {
  const layout = invoiceTableLayout(theme);
  if (theme.name === 'classic') {
    doc.rect(layout.x, y - 4, layout.w, 25).strokeColor('#111827').lineWidth(0.35).stroke();
    [296, 364, 450].forEach((x) => doc.moveTo(x, y - 4).lineTo(x, y + 21).strokeColor('#9ca3af').lineWidth(0.3).stroke());
  } else if (shaded) {
    if (theme.name === 'elegant') {
      doc.rect(layout.x, y - 3, layout.w, 25).fill('#fffaf0');
    } else {
      doc.roundedRect(layout.x, y - 4, layout.w, 25, 6).fill('#ffffff').strokeColor('#d9e8ea').lineWidth(0.6).stroke();
    }
  } else if (theme.name === 'modern') {
    doc.roundedRect(layout.x, y - 4, layout.w, 25, 6).fill('#fbfdfd').strokeColor('#e1eef0').lineWidth(0.6).stroke();
  }
  doc.fillColor(theme.ink).font(fonts.regular).fontSize(7.8 * Math.min(theme.scale || 1, 1.08))
    .text(columns.description, layout.descX, y, { width: layout.descW, height: 16, ellipsis: true })
    .text(columns.qty, layout.qtyX, y, { width: layout.qtyW, align: 'right' })
    .text(columns.rate, layout.rateX, y, { width: layout.rateW, align: 'right' })
    .text(columns.amount, layout.amountX, y, { width: layout.amountW, align: 'right' });
  if (theme.name === 'elegant') doc.moveTo(layout.x, y + 23).lineTo(layout.x + layout.w, y + 23).strokeColor('#e9dcc2').lineWidth(0.5).stroke();
}

function drawTotalsPanel(doc, y, totalRows, fonts, theme = documentTheme()) {
  if (theme.name === 'classic') {
    const h = Math.max(66, 22 + totalRows.length * 15);
    doc.rect(332, y, 227, h).strokeColor(theme.ink).lineWidth(0.9).stroke();
    doc.rect(332, y, 227, 19).strokeColor(theme.ink).lineWidth(0.6).stroke();
    doc.fillColor(theme.ink).font(fonts.bold).fontSize(8.5).text('TOTALS', 344, y + 6, { width: 190, align: 'center' });
    totalRows.forEach((row, index) => {
      const rowY = y + 26 + index * 15;
      doc.fillColor(row[2]).font(row[3]).fontSize(8.3).text(row[0], 348, rowY, { width: 92 });
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
      doc.fillColor(row[2]).font(row[3]).fontSize(index === totalRows.length - 1 ? 9 : 8).text(row[0], 330, rowY, { width: 95 });
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
    doc.fillColor(isLast ? '#ffffff' : '#d9edf2').font(isLast ? fonts.bold : row[3]).fontSize(isLast ? 9 : 7.8).text(row[0], 334, rowY, { width: 96 });
    doc.text(row[1], 448, rowY, { width: 88, align: 'right' });
  });
}

function bankDetailLines(businessProfile = emptyBusinessProfile()) {
  const lines = [];
  if (businessProfile.bankName) lines.push(`Bank: ${businessProfile.bankName}`);
  if (businessProfile.accountNumber) lines.push(`A/C: ${businessProfile.accountNumber}`);
  if (businessProfile.upiId) lines.push(`UPI: ${businessProfile.upiId}`);
  return lines;
}

function drawPaymentDetails(doc, x, y, fonts, theme, businessProfile = emptyBusinessProfile()) {
  const lines = bankDetailLines(businessProfile);
  if (lines.length > 0) {
    doc.fillColor(theme.primary).font(fonts.bold).fontSize(8.5).text('Bank Details', x, y, { width: 220 });
    doc.fillColor(theme.ink).font(fonts.regular).fontSize(7.8)
      .text(lines.join('\n'), x, y + 14, { width: 220, height: 34 });
  }
  if (businessProfile.qrBase64) {
    const qrY = lines.length > 0 ? y + 52 : y;
    drawProfileImage(doc, businessProfile.qrBase64, x, qrY, { fit: [58, 58] });
    doc.fillColor(theme.muted).font(fonts.regular).fontSize(7).text('Payment QR', x, qrY + 60, { width: 58, align: 'center' });
  }
}

function totalsPanelHeight(totalRows, theme = documentTheme()) {
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

  doc.fillColor(theme.primary).font(fonts.bold).fontSize(8.5).text('Amount in words', metrics.left, y + 2);
  doc.fillColor(theme.ink).font(fonts.regular).fontSize(7.6).text(amountInWords(amountValue), metrics.left, y + 16, { width: 260, height: 24 });
  if (notes) doc.fillColor(theme.muted).font(fonts.regular).fontSize(7.2).text(notes, metrics.left, y + 43, { width: 260, height: 32 });

  const lowerY = Math.max(y + 82, totalsY + totalsH + 18);
  drawPaymentDetails(doc, metrics.left, lowerY, fonts, theme, businessProfile);

  const signatureX = metrics.right - 154;
  const signatureY = Math.min(Math.max(lowerY + 28, totalsY + totalsH + 36), 716);
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
  }
}

function drawDocumentFooter(doc, fonts, theme, businessProfile) {
  const metrics = documentMetrics(theme);
  doc.moveTo(metrics.left, 778).lineTo(metrics.right, 778).strokeColor(theme.name === 'classic' ? '#9ca3af' : '#d6dde0').lineWidth(0.5).stroke();
  doc.fillColor(theme.muted).font(fonts.regular).fontSize(7).text(`Generated by CaterPro on ${prettyDate(new Date().toISOString().slice(0, 10))}`, metrics.left, 786, { width: metrics.width, align: 'center', lineBreak: false });
}

function generateEventPdf({ res, db, event, type, businessProfile = emptyBusinessProfile(), clients = [] }) {
  const isInvoice = type === 'invoice';
  const title = isInvoice ? 'INVOICE' : 'QUOTATION';
  const number = documentNumber(isInvoice ? 'INV' : 'QUOTE', event);
  const totals = eventTotals(event);
  const gst = gstBreakdown(totals.total, businessProfile);
  const grandTotal = gst.total;
  const balanceDue = Math.max(0, grandTotal - totals.paid - totals.discount);
  const eventClient = clients.find((client) => normalizeMobile(client.mobile) === normalizeMobile(event.mobile));
  const documentEvent = {
    ...event,
    clientAddress: event.clientAddress || eventClient?.address || eventClient?.city || '',
    clientGst: event.clientGst || eventClient?.gst || '',
  };
  const doc = new PDFDocument({ size: 'A4', margin: 36, info: { Title: `${title} - ${event.name}` } });
  const fonts = configurePdfFonts(doc);
  const theme = documentTheme(businessProfile);
  res.setHeader('Content-Type', 'application/pdf');
  setPdfAttachment(res, [title, eventClientName(event), event.name || event.id, number]);
  doc.pipe(res);

  writeDocumentHeader(doc, title, documentEvent, number, fonts, businessProfile);
  documentInfoSection(doc, title, documentEvent, number, fonts, businessProfile, isInvoice);
  const metrics = documentMetrics(theme);
  let y = metrics.tableY;
  tableHeader(doc, y, fonts, theme);
  y += theme.name === 'modern' ? 32 : 26;

  let shaded = false;
  for (const date of event.dates) {
    y = ensurePageSpace(doc, y, 22, () => { resetDocumentPage(doc, theme); tableHeader(doc, 44, fonts, theme); });
    doc.fillColor(theme.primary).font(fonts.bold).fontSize(8.8).text(`${prettyDate(date.date)}${date.label ? ` - ${date.label}` : ''}`, metrics.left, y, { width: metrics.width });
    y += 15;
    for (const slot of date.menuSlots) {
      y = ensurePageSpace(doc, y, 30, () => { resetDocumentPage(doc, theme); tableHeader(doc, 44, fonts, theme); });
      const amount = Number(slot.pax || 0) * Number(slot.pricePerPax || 0);
      drawInvoiceRow(doc, y, fonts, {
        description: `${slot.type || 'Meal'}${slot.time ? ` (${slot.time})` : ''}`,
        qty: `${slot.pax || ''}`,
        rate: money(slot.pricePerPax),
        amount: money(amount),
      }, shaded, theme);
      shaded = !shaded;
      y += 28;
      for (const service of slot.additionalServices || []) {
        y = ensurePageSpace(doc, y, 30, () => { resetDocumentPage(doc, theme); tableHeader(doc, 44, fonts, theme); });
        const quantity = serviceQuantityText(service);
        drawInvoiceRow(doc, y, fonts, {
          description: `${slot.type || 'Meal'} service - ${service.name || 'Service'}${quantity ? ` (${quantity})` : ''}`,
          qty: '',
          rate: '',
          amount: money(service.price || 0),
        }, shaded, theme);
        shaded = !shaded;
        y += 28;
      }
    }
    for (const service of date.additionalServices || []) {
      y = ensurePageSpace(doc, y, 30, () => { resetDocumentPage(doc, theme); tableHeader(doc, 44, fonts, theme); });
      const quantity = serviceQuantityText(service);
      drawInvoiceRow(doc, y, fonts, {
        description: `Date service - ${service.name || 'Service'}${quantity ? ` (${quantity})` : ''}`,
        qty: '',
        rate: '',
        amount: money(service.price || 0),
      }, shaded, theme);
      shaded = !shaded;
      y += 28;
    }
  }
  if ((event.addOns || []).length > 0) {
    y = ensurePageSpace(doc, y, 22, () => { resetDocumentPage(doc, theme); tableHeader(doc, 44, fonts, theme); });
    doc.fillColor(theme.primary).font(fonts.bold).fontSize(8.8).text('Event Add-ons', metrics.left, y);
    y += 15;
    for (const addOn of event.addOns || []) {
      y = ensurePageSpace(doc, y, 30, () => { resetDocumentPage(doc, theme); tableHeader(doc, 44, fonts, theme); });
      drawInvoiceRow(doc, y, fonts, {
        description: addOn.title || 'Add-on',
        qty: '',
        rate: '',
        amount: money(addOn.cost),
      }, shaded, theme);
      shaded = !shaded;
      y += 28;
    }
  }

  const totalRows = [
    ['Menu Total', money(totals.menuTotal), '#202124', fonts.regular],
  ];
  if (totals.serviceTotal > 0) totalRows.push(['Services Total', money(totals.serviceTotal), '#202124', fonts.regular]);
  if (totals.addOnTotal > 0) totalRows.push(['Add-ons Total', money(totals.addOnTotal), '#202124', fonts.regular]);
  if (gst.enabled) gst.rows.forEach((row) => totalRows.push([row[0], money(row[1]), '#202124', fonts.regular]));
  totalRows.push(['Grand Total', money(grandTotal), theme.primary, fonts.bold]);
  if (isInvoice) {
    totalRows.push(['Paid Till Now', money(totals.paid), '#0b6b3a', fonts.regular]);
    if (totals.discount > 0) totalRows.push(['Settled Discount', money(totals.discount), '#0b6b3a', fonts.regular]);
    totalRows.push(['Balance Due', money(balanceDue), balanceDue > 0 ? '#ba1a1a' : '#0b6b3a', fonts.bold]);
  }
  y = ensurePageSpace(doc, y, Math.max(184, totalsPanelHeight(totalRows, theme) + 126));
  const terms = businessProfile.terms || (isInvoice ? 'Thank you for your payment. Balance, if any, is payable as per event agreement.' : 'Quotation is based on selected menu, pax and services. Final invoice may vary after confirmation.');
  drawDocumentClosing(doc, y + 4, {
    amountValue: isInvoice ? balanceDue || grandTotal : grandTotal,
    notes: terms,
    totalRows,
    fonts,
    theme,
    businessProfile,
  });
  drawDocumentFooter(doc, fonts, theme, businessProfile);
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
  setPdfAttachment(res, ['INVOICE', invoice.clientName || 'Client', invoice.eventName || invoice.id, number]);
  doc.pipe(res);

  writeDocumentHeader(doc, 'INVOICE', event, number, fonts, businessProfile);
  documentInfoSection(doc, 'Invoice', event, number, fonts, businessProfile, true);
  const metrics = documentMetrics(theme);
  let y = metrics.tableY;
  tableHeader(doc, y, fonts, theme);
  y += theme.name === 'modern' ? 32 : 26;
  let shaded = false;
  for (const finalItem of invoice.items || []) {
    y = ensurePageSpace(doc, y, 30, () => { resetDocumentPage(doc, theme); tableHeader(doc, 44, fonts, theme); });
    drawInvoiceRow(doc, y, fonts, {
      description: finalItem.title || 'Invoice item',
      qty: finalItem.quantity ? String(finalItem.quantity) : '',
      rate: finalItem.rate ? money(finalItem.rate) : '',
      amount: money(finalItem.amount),
    }, shaded, theme);
    shaded = !shaded;
    y += 28;
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
  y = ensurePageSpace(doc, y, Math.max(184, totalsPanelHeight(totalRows, theme) + 126));
  drawDocumentClosing(doc, y + 4, {
    amountValue: pending || grandTotal,
    notes: invoice.notes,
    totalRows,
    fonts,
    theme,
    businessProfile,
  });
  drawDocumentFooter(doc, fonts, theme, businessProfile);
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
  doc.font(fonts.regular).fontSize(9).text(`${businessProfile.businessName || 'CaterPro'} • ${month}`, 360, 48, { width: 180, align: 'right' });
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
    doc.fillColor('white').font(fonts.bold).fontSize(8)
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
    doc.fillColor(theme.muted).font(fonts.regular).fontSize(7.5).text(employee.designation || '', 42, y + 11, { width: 142 });
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
  doc.font(fonts.regular).fontSize(8).text(`${businessProfile.businessName || 'CaterPro'} - ${month}`, 610, 33, { width: 180, align: 'right' });

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

function eventMemberTotal(event) {
  return asArray(event.dates).reduce((dateSum, date) => dateSum + asArray(date.menuSlots).reduce((slotSum, slot) => slotSum + Number(slot.pax || 0), 0), 0);
}

function generateMonthlyReportPdf({ res, events, manualInvoices = [], monthKey, businessProfile = emptyBusinessProfile() }) {
  const [yearText, monthText] = String(monthKey || '').split('-');
  const monthDate = new Date(Number(yearText || new Date().getFullYear()), Number(monthText || new Date().getMonth() + 1) - 1, 1);
  const normalizedMonth = `${monthDate.getFullYear()}-${String(monthDate.getMonth() + 1).padStart(2, '0')}`;
  const monthLabel = monthDate.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
  const monthEvents = asArray(events).filter((event) => sameMonthValue(eventFirstDateValue(event), monthDate));
  const monthPayments = asArray(events).flatMap((event) => asArray(event.payments)
    .filter((payment) => String(payment.date || '').startsWith(normalizedMonth))
    .map((payment) => ({ ...payment, eventName: event.name || 'Event', client: event.primaryClient || event.mobile || '' })));
  const monthManualInvoices = asArray(manualInvoices).filter((invoice) => String(invoice.invoiceDate || '').startsWith(normalizedMonth));
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

  const doc = new PDFDocument({ size: 'A4', margin: 24, info: { Title: `Monthly Report - ${monthLabel}` }, autoFirstPage: false });
  const fonts = configurePdfFonts(doc);
  const pageW = 595.28;
  const pageH = 841.89;
  const left = 28;
  const right = pageW - 28;
  const width = right - left;
  let pageNo = 0;
  let y = 0;
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="monthly-report-${normalizedMonth}.pdf"`);
  doc.pipe(res);

  function addPage() {
    doc.addPage({ size: 'A4', margin: 24 });
    pageNo += 1;
    doc.rect(0, 0, pageW, pageH).fill('#ffffff');
    doc.fillColor('#111827').font(fonts.bold).fontSize(18).text('Monthly Report', left, 24, { width: 220 });
    doc.fillColor('#4b5563').font(fonts.regular).fontSize(8).text(`${monthLabel} - ${businessProfile.businessName || 'CaterPro'} - Page ${pageNo}`, right - 270, 29, { width: 270, align: 'right' });
    doc.moveTo(left, 52).lineTo(right, 52).strokeColor('#d1d5db').lineWidth(0.6).stroke();
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
    doc.fillColor('#6b7280').font(fonts.bold).fontSize(7.5).text(title, x + 8, y + 8, { width: w - 16 });
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
  if (!monthEvents.length) row(['No events for this month'], [width]);

  section('Payments Collected This Month');
  row(['Date', 'Event', 'Client', 'Mode', 'Reference', 'Amount'], [56, 132, 96, 62, 132, 72], { header: true, align: ['', '', '', '', '', 'right'] });
  for (const payment of monthPayments) {
    row([payment.date || '-', payment.eventName, payment.client || '-', payment.mode || '-', payment.reference || '-', money(payment.amount)], [56, 132, 96, 62, 132, 72], { align: ['', '', '', '', '', 'right'] });
  }
  if (!monthPayments.length) row(['No event payments collected this month'], [width]);

  section('Manual Invoices');
  row(['Date', 'Invoice', 'Client', 'Total', 'Paid', 'Pending'], [58, 120, 148, 76, 76, 76], { header: true, align: ['', '', '', 'right', 'right', 'right'] });
  for (const invoice of monthManualInvoices) {
    const total = asArray(invoice.items).reduce((sum, item) => sum + Number(item.amount || 0), 0);
    const paid = Number(invoice.paidAmount || 0) + Number(invoice.settlementAmount || 0);
    row([invoice.invoiceDate || '-', invoice.invoiceNumber || invoice.id, invoice.clientName || '-', money(total), money(paid), money(Math.max(0, total - paid))], [58, 120, 148, 76, 76, 76], { align: ['', '', '', 'right', 'right', 'right'] });
  }
  if (!monthManualInvoices.length) row(['No manual invoices for this month'], [width]);
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
  doc.rect(0, 0, doc.page.width, doc.page.height).fill('#ffffff');
  doc.fillColor('#111827').font(fonts.bold).fontSize(16).text('EVENT MENU', 42, 36, { width: 180 });
  doc.fillColor('#4b5563').font(fonts.regular).fontSize(8)
    .text(`${businessProfile.businessName || 'CaterPro'} | ${pageLabel} | Page ${pageNo}`, 330, 39, { width: 220, align: 'right' });
  doc.moveTo(42, 62).lineTo(553, 62).strokeColor('#9ca3af').lineWidth(0.7).stroke();
  doc.fillColor('#111827').font(fonts.bold).fontSize(10).text(event.primaryClient || event.name || 'Customer', 42, 78, { width: 210 });
  doc.fillColor('#374151').font(fonts.regular).fontSize(8)
    .text(`Event: ${event.name || '-'}`, 42, 94, { width: 240 })
    .text(`Date: ${prettyDate(date.date)}${date.label ? ` (${date.label})` : ''}`, 330, 78, { width: 220, align: 'right' })
    .text(`Venue: ${event.venue || '-'}`, 330, 94, { width: 220, align: 'right' });
  doc.moveTo(42, 116).lineTo(553, 116).strokeColor('#d1d5db').lineWidth(0.6).stroke();
}

function drawChefMenuItem(doc, item, x, y, width, fonts, shaded = false) {
  if (shaded) doc.roundedRect(x - 4, y - 2, width, 12, 2).fill('#f2f7f5');
  doc.rect(x, y + 1, 5, 5).strokeColor('#68747b').lineWidth(0.5).stroke();
  const textX = x + 12;
  const text = item.kannada && item.english ? `${item.kannada} / ${item.english}` : item.kannada || item.english;
  drawSingleLineText(doc, text, textX, y - 1, width - 16, fonts, { fontSize: 7.8, height: 11 });
}

function menuFooter(doc, fonts, businessProfile, pageNo) {
  doc.moveTo(42, 780).lineTo(553, 780).strokeColor('#d1d5db').lineWidth(0.5).stroke();
  doc.fillColor('#6b7280').font(fonts.regular).fontSize(7).text(businessProfile.businessName || 'CaterPro', 42, 788, { width: 220, lineBreak: false });
  doc.text(`Page ${pageNo}`, 470, 788, { width: 82, align: 'right', lineBreak: false });
}

function drawServiceSection(doc, date, y, fonts) {
  if (!date.additionalServices.length) return y;
  doc.fillColor('#111827').font(fonts.bold).fontSize(10).text('Service Requirements', 42, y);
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
  let y = 132;
  if (date.menuSlots.length === 0) {
    y = drawServiceSection(doc, date, y, fonts);
    doc.fillColor('#5f6368').font(fonts.regular).fontSize(11).text('No menu configured for this date.', 42, y + 12);
    menuFooter(doc, fonts, businessProfile, pageNo);
    return pageNo;
  }

  for (const [slotIndex, slot] of date.menuSlots.entries()) {
    const items = slot.menuItemIds.map((id) => menuPartsById(db, id));
    const legacyServices = slotIndex === 0 ? date.additionalServices || [] : [];
    const services = [...(slot.additionalServices || []), ...legacyServices];
    const itemRows = Math.ceil(Math.max(items.length, 1) / 3);
    const serviceRows = Math.ceil(services.length / 2);
    const rowHeight = Math.max(46, 30 + itemRows * 14 + serviceRows * 14 + (services.length ? 12 : 0));
    if (y + rowHeight > 786) {
      menuFooter(doc, fonts, businessProfile, pageNo);
      doc.addPage();
      pageNo += 1;
      menuHeader(doc, event, date, fonts, businessProfile, pageLabel, pageNo);
      y = 132;
    }
    doc.rect(42, y, 511, rowHeight).strokeColor('#d1d5db').lineWidth(0.5).stroke();
    const line = [slot.time, slot.pax ? `${slot.pax} pax` : ''].filter(Boolean).join(' - ');
    doc.fillColor('#111827').font(fonts.bold).fontSize(11).text(slot.type || 'Menu', 52, y + 7, { width: 220 });
    doc.fillColor('#4b5563').font(fonts.regular).fontSize(8).text(line, 364, y + 9, { width: 178, align: 'right' });
    doc.moveTo(52, y + 22).lineTo(543, y + 22).strokeColor('#e5e7eb').lineWidth(0.45).stroke();
    items.forEach((item, index) => {
      const col = index % 3;
      const row = Math.floor(index / 3);
      drawChefMenuItem(doc, item, 56 + col * 166, y + 30 + row * 14, 152, fonts, false);
    });
    if (!items.length && (slot.menuImages || []).length) {
      doc.fillColor('#4b5563').font(fonts.regular).fontSize(8)
        .text(`Uploaded menu image${slot.menuImages.length > 1 ? 's' : ''} attached at end of PDF.`, 56, y + 31, { width: 320 });
    }
    if (services.length) {
      const serviceY = y + 30 + itemRows * 14 + 7;
      doc.fillColor('#4b5563').font(fonts.bold).fontSize(7.8).text('Services', 56, serviceY, { width: 70 });
      services.forEach((service, index) => {
        const col = index % 2;
        const row = Math.floor(index / 2);
        const x = 112 + col * 238;
        const quantity = serviceQuantityText(service);
        doc.rect(x, serviceY + 2 + row * 14, 6, 6).strokeColor('#68747b').lineWidth(0.45).stroke();
        doc.fillColor('#202124').font(fonts.regular).fontSize(7.8)
          .text(`${service.name}${quantity ? ` - ${quantity}` : ''}`, x + 11, serviceY + row * 14, { width: 220 });
      });
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
  const { date, slot, image } = attachment;
  const title = `${slot.type || 'Menu'} - ${prettyDate(date.date || '')}`;
  doc.fillColor('#111827').font(fonts.bold).fontSize(15).text('UPLOADED MENU IMAGE', 42, 34, { width: 260 });
  doc.fillColor('#4b5563').font(fonts.regular).fontSize(8)
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

function generateMenuPdf({ res, db, event, dateId, allDates = false, businessProfile = emptyBusinessProfile() }) {
  const hasMenuContent = (date) => date.menuSlots.length > 0 || date.additionalServices.length > 0 || date.menuSlots.some((slot) => (slot.additionalServices || []).length > 0 || (slot.menuImages || []).length > 0);
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
  setPdfAttachment(res, [allDates ? 'All-Menus' : 'Menu', eventClientName(event), event.name || event.id, suffix]);
  doc.pipe(res);
  let pageNo = 1;
  dates.forEach((date, index) => {
    doc.addPage();
    pageNo = drawMenuPage({ doc, db, event, date, fonts, pageLabel: allDates ? `Day ${index + 1} of ${dates.length}` : 'Single day menu', businessProfile, pageNo });
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

function generateUpcomingMenusPdf({ res, db, events, days = 3, businessProfile = emptyBusinessProfile() }) {
  const hasMenuContent = (date) => date.menuSlots.length > 0 || date.additionalServices.length > 0 || date.menuSlots.some((slot) => (slot.additionalServices || []).length > 0 || (slot.menuImages || []).length > 0);
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
    pageNo = drawMenuPage({ doc, db, event: page.event, date: page.date, fonts, pageLabel: `Upcoming ${index + 1} of ${pages.length}`, businessProfile, pageNo });
    pageNo += 1;
  });
  for (const attachment of menuImageAttachments(pages.map((page) => page.date))) {
    doc.addPage();
    drawMenuImagePage({ doc, attachment, fonts, businessProfile, pageNo });
    pageNo += 1;
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
    doc.fillColor('#4b5563').font(fonts.regular).fontSize(8)
      .text(`${businessProfile.businessName || 'CaterPro'} | Page ${pageNo}`, 360, 27, { width: 217, align: 'right' });
    doc.moveTo(pageX, 50).lineTo(pageX + pageW, 50).strokeColor('#9ca3af').lineWidth(0.7).stroke();
    doc.fillColor('#111827').font(fonts.bold).fontSize(10).text(event.primaryClient || event.name || 'Requirement List', pageX, 64, { width: 245 });
    doc.fillColor('#374151').font(fonts.regular).fontSize(8)
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
    drawSingleLineText(doc, repairMojibake(item.name || item.itemId), x + 10, y + 6, width - 74, fonts, { fontSize: 9.2, height: 14, color: '#111827' });
    drawSingleLineText(doc, repairMojibake(qtyText), x + width - 60, y + 6, 50, fonts, { fontSize: 8.4, height: 14, color: '#111827', align: 'right' });
  }

  function drawFooter(pageNo = 1) {
    doc.moveTo(pageX, 790).lineTo(pageX + pageW, 790).strokeColor('#d1d5db').lineWidth(0.5).stroke();
    doc.fillColor('#6b7280').font(fonts.regular).fontSize(7).text(businessProfile.businessName || 'CaterPro', pageX, 798, { width: 220, lineBreak: false });
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

function generateMenuCatalogPdf({ res, db, language = 'both', filters = {} }) {
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

  const items = asArray(db.universal?.menuItems)
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
  const itemFontSize = 10;
  const itemLineGap = 0.8;
  let col = 0;
  let y = topY;
  let columnTopY = topY;
  let pageNo = 0;

  function addPage() {
    doc.addPage({ size: 'A4', layout: 'portrait', margin });
    pageNo += 1;
    doc.fillColor('#111827').font(fonts.bold).fontSize(15).text('Menu Catalog', margin, 10, { width: 160, lineBreak: false });
    doc.fillColor('#6b7280').font(fonts.regular).fontSize(7.2).text(
      `${normalizedLanguage === 'both' ? 'Kannada + English' : normalizedLanguage} - ${items.length} items - CaterPro - Page ${pageNo}`,
      page.width - 270,
      15,
      { width: 248, align: 'right', lineBreak: false },
    );
    doc.moveTo(margin, 32).lineTo(page.width - margin, 32).strokeColor('#d1d5db').lineWidth(0.5).stroke();
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
    userOwned: ['events', 'clients', 'employees', 'attendance', 'additionalServices', 'customMenus', 'requirementLists', 'businessProfile', 'payments', 'manualInvoices'],
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

app.post('/api/admin/users', (req, res) => {
  const db = readDb();
  const admin = requireAdminUser(req, res, db);
  if (!admin) return;
  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');
  const name = String(req.body.name || '').trim() || email;
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
  const user = { id, name, email, password };
  db.users.push(user);
  db.userData[id] = ensureUserDataShape(emptyUserData());
  writeDb(db);
  res.status(201).json({
    message: 'User inserted',
    user: { id: user.id, name: user.name, email: user.email },
  });
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
  res.json({ universal: db.universal, userData: db.userData[user.id] });
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
      menuItems: db.universal.menuItems.length,
      rawMaterials: db.universal.rawMaterials.length,
      produceItems: db.universal.produceItems.length,
      vesselItems: db.universal.vesselItems.length,
    },
  });
});

app.get('/api/business-profile', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  res.json(db.userData[user.id].businessProfile);
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
  const month = String(req.query.month || new Date().toISOString().slice(0, 7));
  return generateMonthlyReportPdf({
    res,
    events: db.userData[user.id].events,
    manualInvoices: db.userData[user.id].manualInvoices,
    monthKey: month,
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
  ensureUniversal(db);
  res.json(db.universal.menuItems);
});

function handleMenuCatalogPdf(req, res) {
  const db = readDb();
  ensureUniversal(db);
  return generateMenuCatalogPdf({
    res,
    db,
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
  const item = { ...(existing || {}), ...req.body, id: req.body.id || req.params.id };
  if (item.id !== req.params.id) {
    db.universal.menuItems = db.universal.menuItems.filter((entry) => entry.id !== req.params.id);
  }
  upsertById(db.universal.menuItems, item);
  writeDb(db);
  res.status(existing ? 200 : 201).json(item);
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
  const item = { ...existing, ...req.body, id: req.body.id || req.params.id };
  if (item.id !== req.params.id) {
    db.universal.rawMaterials = db.universal.rawMaterials.filter((entry) => entry.id !== req.params.id);
  }
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
  const item = { ...existing, ...req.body, id: req.body.id || req.params.id };
  if (item.id !== req.params.id) {
    db.universal.produceItems = db.universal.produceItems.filter((entry) => entry.id !== req.params.id);
  }
  upsertById(db.universal.produceItems, item);
  writeDb(db);
  res.json(item);
});

app.get('/api/vessel-items', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  writeDb(db);
  res.json(db.universal.vesselItems);
});

app.post('/api/vessel-items', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  const item = { id: req.body.id || makeId('ves'), name: req.body.name || '', category: req.body.category || '', unit: req.body.unit || '' };
  upsertById(db.universal.vesselItems, item);
  writeDb(db);
  res.status(201).json(item);
});

app.put('/api/vessel-items/:id', (req, res) => {
  const db = readDb();
  ensureUniversal(db);
  const existing = db.universal.vesselItems.find((item) => item.id === req.params.id);
  if (!existing) return res.status(404).json({ message: 'Vessel/utensil item not found' });
  const item = { ...existing, ...req.body, id: req.body.id || req.params.id };
  if (item.id !== req.params.id) {
    db.universal.vesselItems = db.universal.vesselItems.filter((entry) => entry.id !== req.params.id);
  }
  upsertById(db.universal.vesselItems, item);
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
    return generateMenuPdf({ res, db, event, dateId: req.query.dateId || event.dates[0]?.id || event.dates[0]?.date, businessProfile: db.userData[user.id].businessProfile });
  }
  if (req.params.type === 'all-menus') {
    return generateMenuPdf({ res, db, event, allDates: true, businessProfile: db.userData[user.id].businessProfile });
  }
  if (!['quotation', 'invoice'].includes(req.params.type)) return res.status(400).json({ message: 'Document type must be quotation, invoice, menu, or all-menus' });
  return generateEventPdf({ res, db, event, type: req.params.type, businessProfile: db.userData[user.id].businessProfile, clients: db.userData[user.id].clients || [] });
});

app.get('/api/documents/upcoming-menus', (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  const days = Math.max(1, Math.min(14, Number(req.query.days || 3)));
  return generateUpcomingMenusPdf({ res, db, events: db.userData[user.id].events, days, businessProfile: db.userData[user.id].businessProfile });
});

app.get('/api/storage/status', async (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  let postgres = { enabled: Boolean(pgPool), connected: false, updatedAt: null };
  if (pgPool) {
    try {
      await ensurePostgresStateTable();
      const result = await pgPool.query('select updated_at from caterpro_state where id = $1', [pgStateId]);
      postgres = {
        enabled: true,
        connected: true,
        stateId: pgStateId,
        updatedAt: result.rows[0]?.updated_at || null,
      };
    } catch (error) {
      postgres = { enabled: true, connected: false, stateId: pgStateId, error: error.message };
    }
  }
  res.json({
    storage: pgPool ? 'postgresql' : 'db.json',
    postgres,
    counts: {
      users: db.users.length,
      events: db.userData[user.id].events.length,
      menuItems: db.universal.menuItems.length,
      rawMaterials: db.universal.rawMaterials.length,
      produceItems: db.universal.produceItems.length,
      vesselItems: db.universal.vesselItems.length,
    },
  });
});

app.get('/api/storage/tables', async (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  if (!pgPool) return res.status(400).json({ message: 'DATABASE_URL is not configured' });
  try {
    await syncRelationalTables(db);
    const tables = [
      'cp_users',
      'cp_business_profiles',
      'cp_clients',
      'cp_employees',
      'cp_events',
      'cp_event_dates',
      'cp_menu_slots',
      'cp_event_payments',
      'cp_event_assignments',
      'cp_attendance',
      'cp_additional_services',
      'cp_custom_menus',
      'cp_requirement_lists',
      'cp_manual_invoices',
      'cp_manual_invoice_items',
      'cp_menu_items',
      'cp_raw_materials',
      'cp_produce_items',
      'cp_vessel_items',
    ];
    const counts = {};
    for (const table of tables) {
      const result = await pgPool.query(`select count(*)::int as count from ${table} where state_id = $1`, [pgStateId]);
      counts[table] = result.rows[0].count;
    }
    res.json({ stateId: pgStateId, counts });
  } catch (error) {
    res.status(500).json({ message: 'Unable to inspect PostgreSQL tables', error: error.message });
  }
});

app.post('/api/storage/import-menu-items-from-db', async (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  if (!pgPool) return res.status(400).json({ message: 'DATABASE_URL is not configured' });
  try {
    const result = await pgPool.query(
      `select id, english, kannada, title, category, meals, veg, raw
       from cp_menu_items
       where state_id = $1
       order by id`,
      [pgStateId],
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'No menu items found in cp_menu_items' });
    }
    db.universal = db.universal || {};
    db.universal.menuItems = result.rows.map((row) => {
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
    await flushPostgresWrites();
    res.json({
      message: 'Menu items imported from PostgreSQL table',
      count: db.universal.menuItems.length,
    });
  } catch (error) {
    res.status(500).json({ message: 'Unable to import menu items from PostgreSQL table', error: error.message });
  }
});

app.post('/api/storage/push-local-to-postgres', async (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  if (!pgPool) return res.status(400).json({ message: 'DATABASE_URL is not configured' });
  try {
    await savePostgresDb(db);
    res.json({
      message: 'Current backend state pushed to PostgreSQL',
      stateId: pgStateId,
      counts: {
        events: db.userData[user.id].events.length,
        menuItems: db.universal.menuItems.length,
        rawMaterials: db.universal.rawMaterials.length,
        produceItems: db.universal.produceItems.length,
        vesselItems: db.universal.vesselItems.length,
      },
    });
  } catch (error) {
    res.status(500).json({ message: 'Unable to push to PostgreSQL', error: error.message });
  }
});

app.post('/api/storage/pull-postgres-to-local', async (req, res) => {
  const db = readDb();
  const user = requireUser(req, res, db);
  if (!user) return;
  if (!allowJsonStorage) {
    return res.status(410).json({
      message: 'Local db.json pull is disabled. CaterPro is configured for PostgreSQL-only storage.',
    });
  }
  if (!pgPool) return res.status(400).json({ message: 'DATABASE_URL is not configured' });
  try {
    const postgresDb = await loadPostgresDb();
    if (!postgresDb) return res.status(404).json({ message: 'No PostgreSQL state found' });
    postgresDb.universal = mergeProtectedUniversalCatalog(db.universal || {}, postgresDb.universal || {});
    writeDb(postgresDb);
    await flushPostgresWrites();
    const pulledUserData = postgresDb.userData[user.id] || emptyUserData();
    res.json({
      message: 'PostgreSQL state pulled into local db.json',
      stateId: pgStateId,
      counts: {
        events: pulledUserData.events.length,
        menuItems: postgresDb.universal.menuItems.length,
        rawMaterials: postgresDb.universal.rawMaterials.length,
        produceItems: postgresDb.universal.produceItems.length,
        vesselItems: postgresDb.universal.vesselItems.length,
      },
    });
  } catch (error) {
    res.status(500).json({ message: 'Unable to pull from PostgreSQL', error: error.message });
  }
});

app.use((req, res) => res.status(404).json({ message: 'Not found' }));

initializeStorage().then(() => {
  app.listen(port, '0.0.0.0', () => {
    console.log(`CaterPro API running on port ${port}`);
  });
}).catch((error) => {
  console.error('Unable to initialize CaterPro storage:', error);
  process.exit(1);
});
