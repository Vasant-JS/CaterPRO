const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const dbPath = path.join(__dirname, 'db.json');
const port = Number(process.env.PORT || 8787);

function readDb() {
  return JSON.parse(fs.readFileSync(dbPath, 'utf8'));
}

function writeDb(db) {
  fs.writeFileSync(dbPath, `${JSON.stringify(db, null, 2)}\n`);
}

function send(res, status, data) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  });
  res.end(JSON.stringify(data));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > 1_000_000) req.destroy();
    });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (error) {
        reject(error);
      }
    });
  });
}

function getUserFromAuth(req, db) {
  const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  const userId = Buffer.from(token, 'base64url').toString('utf8').split(':')[0];
  return db.users.find((user) => user.id === userId);
}

async function route(req, res) {
  if (req.method === 'OPTIONS') return send(res, 204, {});

  const url = new URL(req.url, `http://${req.headers.host}`);
  const db = readDb();

  if (req.method === 'GET' && url.pathname === '/health') {
    return send(res, 200, { ok: true, service: 'caterpro-api' });
  }

  if (req.method === 'GET' && (url.pathname === '/api' || url.pathname === '/api/docs')) {
    return send(res, 200, apiDocs);
  }

  if (req.method === 'POST' && url.pathname === '/api/auth/login') {
    const body = await readBody(req);
    const email = String(body.email || '').trim().toLowerCase();
    const password = String(body.password || '');
    const user = db.users.find((item) => item.email.toLowerCase() === email && item.password === password);
    if (!user) return send(res, 401, { message: 'Invalid email or password' });

    const token = Buffer.from(`${user.id}:${crypto.randomUUID()}`).toString('base64url');
    db.userData[user.id] = db.userData[user.id] || { events: [], clients: [], employees: [], additionalServices: [], payments: [] };
    writeDb(db);
    return send(res, 200, { token, user: { id: user.id, name: user.name, email: user.email } });
  }

  if (req.method === 'POST' && url.pathname === '/api/auth/forgot-password') {
    const body = await readBody(req);
    return send(res, 200, { message: `Password reset requested for ${body.email || 'unknown email'}` });
  }

  if (req.method === 'GET' && url.pathname === '/api/bootstrap') {
    const user = getUserFromAuth(req, db);
    if (!user) return send(res, 401, { message: 'Unauthorized' });
    return send(res, 200, {
      universal: db.universal,
      userData: db.userData[user.id] || {},
    });
  }

  return send(res, 404, { message: 'Not found' });
}

const apiDocs = {
  name: 'CaterPro API',
  version: '0.1.0',
  notes: [
    'menuItems and rawMaterials are universal shared catalogs',
    'events, clients, employees, additionalServices, and payments are stored under userData.{userId}',
    'send Authorization: Bearer <token> for protected APIs',
  ],
  demoUser: {
    email: 'admin@caterpro.in',
    password: 'password',
  },
  endpoints: [
    { method: 'GET', path: '/health', auth: false, description: 'Service health check' },
    { method: 'GET', path: '/api', auth: false, description: 'API index and endpoint list' },
    { method: 'GET', path: '/api/docs', auth: false, description: 'API index and endpoint list' },
    { method: 'POST', path: '/api/auth/login', auth: false, description: 'Login with email/password', body: { email: 'admin@caterpro.in', password: 'password' } },
    { method: 'POST', path: '/api/auth/forgot-password', auth: false, description: 'Request password reset', body: { email: 'admin@caterpro.in' } },
    { method: 'GET', path: '/api/bootstrap', auth: true, description: 'Return universal catalog data and current user-owned data' },
  ],
};

http
  .createServer((req, res) => {
    route(req, res).catch((error) => send(res, 500, { message: error.message }));
  })
  .listen(port, '0.0.0.0', () => {
    console.log(`CaterPro API running on port ${port}`);
  });
