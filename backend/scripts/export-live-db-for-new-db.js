const fs = require('fs');
const path = require('path');

function loadEnv() {
  const envPath = path.join(__dirname, '..', '.env');
  const result = {};
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#') || !trimmed.includes('=')) continue;
    const index = trimmed.indexOf('=');
    const key = trimmed.slice(0, index).trim();
    let value = trimmed.slice(index + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    result[key] = value;
  }
  return result;
}

const tables = [
  {
    name: 'caterpro_state',
    conflict: ['id'],
    filter: (stateId) => `id=eq.${encodeURIComponent(stateId)}`,
  },
  { name: 'cp_users', conflict: ['state_id', 'id'] },
  { name: 'cp_business_profiles', conflict: ['state_id', 'user_id'] },
  { name: 'cp_clients', conflict: ['state_id', 'user_id', 'id'] },
  { name: 'cp_employees', conflict: ['state_id', 'user_id', 'id'] },
  { name: 'cp_events', conflict: ['state_id', 'user_id', 'id'] },
  { name: 'cp_event_dates', conflict: ['state_id', 'user_id', 'event_id', 'id'] },
  { name: 'cp_menu_slots', conflict: ['state_id', 'user_id', 'event_id', 'date_id', 'id'] },
  { name: 'cp_event_payments', conflict: ['state_id', 'user_id', 'event_id', 'id'] },
  { name: 'cp_event_assignments', conflict: ['state_id', 'user_id', 'event_id', 'employee_id'] },
  { name: 'cp_attendance', conflict: ['state_id', 'user_id', 'event_id', 'employee_id', 'attendance_date'] },
  { name: 'cp_additional_services', conflict: ['state_id', 'user_id', 'id'] },
  { name: 'cp_custom_menus', conflict: ['state_id', 'user_id', 'id'] },
  { name: 'cp_requirement_lists', conflict: ['state_id', 'user_id', 'id'] },
  { name: 'cp_manual_invoices', conflict: ['state_id', 'user_id', 'id'] },
  { name: 'cp_manual_invoice_items', conflict: ['state_id', 'user_id', 'invoice_id', 'id'] },
  { name: 'cp_menu_items', conflict: ['state_id', 'id'] },
  { name: 'cp_user_menu_items', conflict: ['state_id', 'user_id', 'id'] },
  { name: 'cp_raw_materials', conflict: ['state_id', 'id'] },
  { name: 'cp_user_raw_materials', conflict: ['state_id', 'user_id', 'id'] },
  { name: 'cp_produce_items', conflict: ['state_id', 'id'] },
  { name: 'cp_user_produce_items', conflict: ['state_id', 'user_id', 'id'] },
  { name: 'cp_vessel_items', conflict: ['state_id', 'id'] },
  { name: 'cp_user_vessel_items', conflict: ['state_id', 'user_id', 'id'] },
];

function tableFilter(table, stateId) {
  if (table.filter) return table.filter(stateId);
  return `state_id=eq.${encodeURIComponent(stateId)}`;
}

async function supabaseGet(baseUrl, key, pathSuffix, extraHeaders = {}) {
  const response = await fetch(`${baseUrl}/rest/v1/${pathSuffix}`, {
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      ...extraHeaders,
    },
  });
  const text = await response.text();
  let data = text;
  try {
    data = JSON.parse(text);
  } catch (_) {}
  if (!response.ok) {
    throw new Error(`${pathSuffix}: ${response.status} ${JSON.stringify(data)}`);
  }
  return { data, contentRange: response.headers.get('content-range') };
}

async function fetchTableRows(baseUrl, key, table, stateId) {
  const pageSize = 1000;
  const rows = [];
  for (let from = 0; ; from += pageSize) {
    const to = from + pageSize - 1;
    const result = await supabaseGet(
      baseUrl,
      key,
      `${table.name}?select=*&${tableFilter(table, stateId)}&order=${table.conflict[0]}.asc`,
      {
        Prefer: 'count=exact',
        Range: `${from}-${to}`,
      },
    );
    const page = Array.isArray(result.data) ? result.data : [];
    rows.push(...page);
    if (page.length < pageSize) break;
  }
  return rows;
}

function sqlIdent(value) {
  return `"${String(value).replace(/"/g, '""')}"`;
}

function sqlLiteral(value) {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : 'null';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'object') return `'${JSON.stringify(value).replace(/'/g, "''")}'::jsonb`;
  return `'${String(value).replace(/'/g, "''")}'`;
}

function collectColumns(rows) {
  const columns = [];
  const seen = new Set();
  for (const row of rows) {
    for (const column of Object.keys(row)) {
      if (seen.has(column)) continue;
      seen.add(column);
      columns.push(column);
    }
  }
  return columns;
}

function insertSqlForTable(table, rows) {
  if (!rows.length) return `-- ${table.name}: 0 rows\n`;
  const columns = collectColumns(rows);
  const valueRows = rows.map((row) => `  (${columns.map((column) => sqlLiteral(row[column])).join(', ')})`);
  const updateColumns = columns.filter((column) => !table.conflict.includes(column));
  const updateClause = updateColumns.length
    ? `do update set ${updateColumns
        .map((column) => `${sqlIdent(column)} = excluded.${sqlIdent(column)}`)
        .join(', ')}`
    : 'do nothing';
  return [
    `-- ${table.name}: ${rows.length} rows`,
    `insert into public.${sqlIdent(table.name)} (${columns.map(sqlIdent).join(', ')}) values`,
    valueRows.join(',\n'),
    `on conflict (${table.conflict.map(sqlIdent).join(', ')}) ${updateClause};`,
    '',
  ].join('\n');
}

function buildDataSql(dump) {
  const sections = [
    '-- CaterPro live DB data export',
    `-- Created at: ${dump.createdAt}`,
    `-- State ID: ${dump.stateId}`,
    '-- Safe to run on a prepared empty/new DB; existing matching primary keys are updated.',
    '',
    'begin;',
    '',
  ];
  for (const table of tables) {
    sections.push(insertSqlForTable(table, dump.tables[table.name] || []));
  }
  sections.push('commit;', '');
  return sections.join('\n');
}

async function main() {
  const env = loadEnv();
  const supabaseUrl = env.SUPABASE_URL;
  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY;
  const stateId = env.SUPABASE_STATE_ID || 'default';
  if (!supabaseUrl || !serviceKey) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required in backend/.env');
  }

  const exportedTables = {};
  const counts = {};
  for (const table of tables) {
    const rows = await fetchTableRows(supabaseUrl, serviceKey, table, stateId);
    exportedTables[table.name] = rows;
    counts[table.name] = rows.length;
  }

  const createdAt = new Date().toISOString();
  const stamp = createdAt.replace(/[:.]/g, '-');
  const outputDir = path.join(__dirname, '..', 'db-exports', `caterpro-live-db-${stamp}`);
  fs.mkdirSync(outputDir, { recursive: true });

  const dump = {
    createdAt,
    stateId,
    source: {
      supabaseUrl,
      tables: tables.map((table) => table.name),
    },
    counts,
    tables: exportedTables,
  };

  const schemaSql = fs.readFileSync(path.join(__dirname, '..', 'supabase-safe-schema-fix.sql'), 'utf8');
  const schemaPath = path.join(outputDir, '01_schema.sql');
  const jsonPath = path.join(outputDir, '02_full_data.json');
  const dataSqlPath = path.join(outputDir, '03_seed_data.sql');
  const bootstrapPath = path.join(outputDir, '00_bootstrap_schema_and_data.sql');
  fs.writeFileSync(schemaPath, schemaSql);
  fs.writeFileSync(jsonPath, JSON.stringify(dump, null, 2));
  fs.writeFileSync(dataSqlPath, buildDataSql(dump));
  fs.writeFileSync(bootstrapPath, `${schemaSql}\n\n${buildDataSql(dump)}`);

  console.log(JSON.stringify({ outputDir, schemaPath, jsonPath, dataSqlPath, bootstrapPath, counts }, null, 2));
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
