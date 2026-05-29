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

function getUserFromAuth(req, db) {
  const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  const userId = Buffer.from(token, 'base64url').toString('utf8').split(':')[0];
  return db.users.find((user) => user.id === userId);
}

const openApiSpec = {
  openapi: '3.0.3',
  info: {
    title: 'CaterPro API',
    version: '0.1.0',
    description: 'CaterPro backend API. Menu items and raw materials are universal; all business data is stored per user.',
  },
  servers: [
    { url: 'http://127.0.0.1:8787', description: 'Local development' },
    { url: 'https://YOUR-RENDER-SERVICE.onrender.com', description: 'Render production' },
  ],
  tags: [
    { name: 'Health' },
    { name: 'Auth' },
    { name: 'Bootstrap' },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
      },
    },
    schemas: {
      LoginRequest: {
        type: 'object',
        required: ['email', 'password'],
        properties: {
          email: { type: 'string', example: 'admin@caterpro.in' },
          password: { type: 'string', example: 'password' },
        },
      },
      ForgotPasswordRequest: {
        type: 'object',
        required: ['email'],
        properties: {
          email: { type: 'string', example: 'admin@caterpro.in' },
        },
      },
      User: {
        type: 'object',
        properties: {
          id: { type: 'string', example: 'usr_demo_admin' },
          name: { type: 'string', example: 'Ravi Caterer' },
          email: { type: 'string', example: 'admin@caterpro.in' },
        },
      },
    },
  },
  paths: {
    '/health': {
      get: {
        tags: ['Health'],
        summary: 'Service health check',
        responses: {
          200: { description: 'API is running' },
        },
      },
    },
    '/api': {
      get: {
        tags: ['Health'],
        summary: 'API index',
        responses: {
          200: { description: 'Endpoint list' },
        },
      },
    },
    '/api/openapi.json': {
      get: {
        tags: ['Health'],
        summary: 'OpenAPI JSON',
        responses: {
          200: { description: 'OpenAPI document' },
        },
      },
    },
    '/api/auth/login': {
      post: {
        tags: ['Auth'],
        summary: 'Login',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/LoginRequest' },
            },
          },
        },
        responses: {
          200: { description: 'Authenticated session token' },
          401: { description: 'Invalid credentials' },
        },
      },
    },
    '/api/auth/forgot-password': {
      post: {
        tags: ['Auth'],
        summary: 'Request password reset',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/ForgotPasswordRequest' },
            },
          },
        },
        responses: {
          200: { description: 'Reset request accepted' },
        },
      },
    },
    '/api/bootstrap': {
      get: {
        tags: ['Bootstrap'],
        summary: 'Load universal and user-owned app data',
        security: [{ bearerAuth: [] }],
        responses: {
          200: { description: 'Bootstrap data' },
          401: { description: 'Unauthorized' },
        },
      },
    },
  },
};

const apiDocs = {
  name: 'CaterPro API',
  version: '0.1.0',
  swagger: '/api/docs',
  openapi: '/api/openapi.json',
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
    { method: 'GET', path: '/api/docs', auth: false, description: 'Swagger UI' },
    { method: 'GET', path: '/api/openapi.json', auth: false, description: 'OpenAPI JSON' },
    { method: 'POST', path: '/api/auth/login', auth: false, description: 'Login with email/password' },
    { method: 'POST', path: '/api/auth/forgot-password', auth: false, description: 'Request password reset' },
    { method: 'GET', path: '/api/bootstrap', auth: true, description: 'Return universal catalog data and current user-owned data' },
  ],
};

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'caterpro-api' });
});

app.get('/api', (req, res) => {
  res.json(apiDocs);
});

app.get('/api/openapi.json', (req, res) => {
  res.json(openApiSpec);
});

app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(openApiSpec));

app.post('/api/auth/login', (req, res) => {
  const db = readDb();
  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');
  const user = db.users.find((item) => item.email.toLowerCase() === email && item.password === password);
  if (!user) return res.status(401).json({ message: 'Invalid email or password' });

  const token = Buffer.from(`${user.id}:${crypto.randomUUID()}`).toString('base64url');
  db.userData[user.id] = db.userData[user.id] || { events: [], clients: [], employees: [], additionalServices: [], payments: [] };
  writeDb(db);
  return res.json({ token, user: { id: user.id, name: user.name, email: user.email } });
});

app.post('/api/auth/forgot-password', (req, res) => {
  res.json({ message: `Password reset requested for ${req.body.email || 'unknown email'}` });
});

app.get('/api/bootstrap', (req, res) => {
  const db = readDb();
  const user = getUserFromAuth(req, db);
  if (!user) return res.status(401).json({ message: 'Unauthorized' });
  return res.json({
    universal: db.universal,
    userData: db.userData[user.id] || {},
  });
});

app.use((req, res) => {
  res.status(404).json({ message: 'Not found' });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`CaterPro API running on port ${port}`);
});
