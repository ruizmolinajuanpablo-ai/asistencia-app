const express = require('express');
const os = require('os');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const QRCode = require('qrcode');
const db = require('./db');

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'asistencia-local-secret-cambiar';
const app = express();
app.use(express.json({ limit: '1mb' }));
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.header('Access-Control-Allow-Methods', 'GET,POST,PATCH,DELETE,OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});
app.use(express.static(path_public()));

function path_public() {
  return require('path').join(__dirname, 'public');
}

function lanIP() {
  const ifs = os.networkInterfaces();
  for (const name of Object.keys(ifs)) {
    for (const iface of ifs[name] || []) {
      if (iface.family === 'IPv4' && !iface.internal) return iface.address;
    }
  }
  return '127.0.0.1';
}

function serverUrl() {
  return `http://${lanIP()}:${PORT}`;
}

function authRequired(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Falta token' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ error: 'Sesión inválida' });
  }
}

function adminRequired(req, res, next) {
  if (req.user.role !== 'docente') return res.status(403).json({ error: 'Solo el docente' });
  next();
}

// ---------- Auth ----------
app.post('/api/auth/register', (req, res) => {
  const { name, email, password } = req.body || {};
  if (!name || !email || !password) return res.status(400).json({ error: 'Faltan datos' });
  if (password.length < 6) return res.status(400).json({ error: 'La contraseña debe tener 6+ caracteres' });
  try {
    const hash = bcrypt.hashSync(password, 10);
    const info = db.prepare('INSERT INTO users (name, email, password_hash, role) VALUES (?, ?, ?, ?)')
      .run(name.trim(), email.trim().toLowerCase(), hash, 'alumno');
    const user = { id: info.lastInsertRowid, name: name.trim(), email: email.trim().toLowerCase(), role: 'alumno' };
    const token = jwt.sign(user, JWT_SECRET, { expiresIn: '30d' });
    res.json({ token, user });
  } catch (e) {
    if (String(e.message).includes('UNIQUE')) return res.status(409).json({ error: 'El correo ya existe' });
    throw e;
  }
});

app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) return res.status(400).json({ error: 'Faltan datos' });
  const row = db.prepare('SELECT * FROM users WHERE email = ?').get(String(email).trim().toLowerCase());
  if (!row || !bcrypt.compareSync(password, row.password_hash)) {
    return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
  }
  const user = { id: row.id, name: row.name, email: row.email, role: row.role };
  const token = jwt.sign(user, JWT_SECRET, { expiresIn: '30d' });
  res.json({ token, user });
});

app.get('/api/me', authRequired, (req, res) => res.json({ user: req.user }));

// ---------- Datos propios (alumno) ----------
const OWN_TABLES = { attendance: 'attendance', activities: 'activities', exams: 'exams' };

app.get('/api/me/:table', authRequired, (req, res) => {
  const table = OWN_TABLES[req.params.table];
  if (!table) return res.status(404).json({ error: 'No existe' });
  const rows = db.prepare(`SELECT * FROM ${table} WHERE user_id = ? ORDER BY date DESC, id DESC`).all(req.user.id);
  res.json(rows);
});

app.post('/api/me/:table', authRequired, (req, res) => {
  const table = OWN_TABLES[req.params.table];
  if (!table) return res.status(404).json({ error: 'No existe' });
  const data = validateRow(table, req.body);
  if (data.error) return res.status(400).json(data);
  let info;
  if (table === 'attendance') {
    info = db.prepare(`INSERT INTO attendance (user_id, date, status, note) VALUES (?, ?, ?, ?)
      ON CONFLICT(user_id, date) DO UPDATE SET status = excluded.status, note = excluded.note`)
      .run(req.user.id, data.date, data.status, data.note);
  } else {
    info = db.prepare(`INSERT INTO ${table} (user_id, name, score, max_score, date, note) VALUES (?, ?, ?, ?, ?, ?)`)
      .run(req.user.id, data.name, data.score, data.max_score, data.date, data.note);
  }
  const id = table === 'attendance'
    ? db.prepare('SELECT id FROM attendance WHERE user_id = ? AND date = ?').get(req.user.id, data.date).id
    : info.lastInsertRowid;
  res.json(db.prepare(`SELECT * FROM ${table} WHERE id = ?`).get(id));
});

app.patch('/api/me/:table/:id', authRequired, (req, res) => {
  const table = OWN_TABLES[req.params.table];
  if (!table) return res.status(404).json({ error: 'No existe' });
  const existing = db.prepare(`SELECT * FROM ${table} WHERE id = ? AND user_id = ?`).get(req.params.id, req.user.id);
  if (!existing) return res.status(404).json({ error: 'No encontrado' });
  const data = validateRow(table, { ...existing, ...req.body });
  if (data.error) return res.status(400).json(data);
  if (table === 'attendance') {
    db.prepare('UPDATE attendance SET date = ?, status = ?, note = ? WHERE id = ?')
      .run(data.date, data.status, data.note, existing.id);
  } else {
    db.prepare(`UPDATE ${table} SET name = ?, score = ?, max_score = ?, date = ?, note = ? WHERE id = ?`)
      .run(data.name, data.score, data.max_score, data.date, data.note, existing.id);
  }
  res.json(db.prepare(`SELECT * FROM ${table} WHERE id = ?`).get(existing.id));
});

app.delete('/api/me/:table/:id', authRequired, (req, res) => {
  const table = OWN_TABLES[req.params.table];
  if (!table) return res.status(404).json({ error: 'No existe' });
  const info = db.prepare(`DELETE FROM ${table} WHERE id = ? AND user_id = ?`).run(req.params.id, req.user.id);
  if (!info.changes) return res.status(404).json({ error: 'No encontrado' });
  res.json({ ok: true });
});

// ---------- Admin (docente) ----------
app.get('/api/admin/students', authRequired, adminRequired, (req, res) => {
  const students = db.prepare(`SELECT id, name, email, created_at FROM users WHERE role = 'alumno' ORDER BY name`).all();
  res.json(students);
});

app.get('/api/admin/students/:id', authRequired, adminRequired, (req, res) => {
  const student = db.prepare(`SELECT id, name, email, created_at FROM users WHERE id = ? AND role = 'alumno'`).get(req.params.id);
  if (!student) return res.status(404).json({ error: 'Alumno no existe' });
  const attendance = db.prepare('SELECT * FROM attendance WHERE user_id = ? ORDER BY date DESC').all(student.id);
  const activities = db.prepare('SELECT * FROM activities WHERE user_id = ? ORDER BY date DESC, id DESC').all(student.id);
  const exams = db.prepare('SELECT * FROM exams WHERE user_id = ? ORDER BY date DESC, id DESC').all(student.id);
  res.json({ student, attendance, activities, exams });
});

app.post('/api/admin/students/:id/:table', authRequired, adminRequired, (req, res) => {
  const table = OWN_TABLES[req.params.table];
  if (!table) return res.status(404).json({ error: 'No existe' });
  const student = db.prepare(`SELECT id FROM users WHERE id = ? AND role = 'alumno'`).get(req.params.id);
  if (!student) return res.status(404).json({ error: 'Alumno no existe' });
  const data = validateRow(table, req.body);
  if (data.error) return res.status(400).json(data);
  let info;
  if (table === 'attendance') {
    db.prepare(`INSERT INTO attendance (user_id, date, status, note) VALUES (?, ?, ?, ?)
      ON CONFLICT(user_id, date) DO UPDATE SET status = excluded.status, note = excluded.note`)
      .run(student.id, data.date, data.status, data.note);
  } else {
    info = db.prepare(`INSERT INTO ${table} (user_id, name, score, max_score, date, note) VALUES (?, ?, ?, ?, ?, ?)`)
      .run(student.id, data.name, data.score, data.max_score, data.date, data.note);
  }
  res.json({ ok: true });
});

app.patch('/api/admin/:table/:id', authRequired, adminRequired, (req, res) => {
  const table = OWN_TABLES[req.params.table];
  if (!table) return res.status(404).json({ error: 'No existe' });
  const existing = db.prepare(`SELECT * FROM ${table} WHERE id = ?`).get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'No encontrado' });
  const data = validateRow(table, { ...existing, ...req.body });
  if (data.error) return res.status(400).json(data);
  if (table === 'attendance') {
    db.prepare('UPDATE attendance SET user_id = ?, date = ?, status = ?, note = ? WHERE id = ?')
      .run(existing.user_id, data.date, data.status, data.note, existing.id);
  } else {
    db.prepare(`UPDATE ${table} SET name = ?, score = ?, max_score = ?, date = ?, note = ? WHERE id = ?`)
      .run(data.name, data.score, data.max_score, data.date, data.note, existing.id);
  }
  res.json(db.prepare(`SELECT * FROM ${table} WHERE id = ?`).get(existing.id));
});

app.delete('/api/admin/:table/:id', authRequired, adminRequired, (req, res) => {
  const table = OWN_TABLES[req.params.table];
  if (!table) return res.status(404).json({ error: 'No existe' });
  const info = db.prepare(`DELETE FROM ${table} WHERE id = ?`).run(req.params.id);
  if (!info.changes) return res.status(404).json({ error: 'No encontrado' });
  res.json({ ok: true });
});

// ---------- Red y QR ----------
app.get('/api/network', (req, res) => {
  res.json({ ip: lanIP(), port: PORT, url: serverUrl() });
});

app.post('/api/qr', async (req, res) => {
  const { ssid, password, encryption } = req.body || {};
  if (!ssid) return res.status(400).json({ error: 'Falta el nombre de la red (SSID)' });
  const enc = encryption || 'WPA';
  const esc = (s) => String(s || '').replace(/([\\;,:"])/g, '\\$1');
  const wifi = `WIFI:S:${esc(ssid)};T:${enc};P:${esc(password)};;`;
  const payload = `${wifi}\nSERVER:${serverUrl()}`;
  try {
    const png = await QRCode.toDataURL(payload, { width: 400, margin: 2 });
    res.json({ payload, png, serverUrl: serverUrl() });
  } catch (e) {
    res.status(500).json({ error: 'No se pudo generar el QR' });
  }
});

function validateRow(table, body) {
  const b = body || {};
  if (table === 'attendance') {
    if (!b.date || !b.status) return { error: 'Faltan fecha o estado' };
    if (!['presente', 'ausente', 'tardanza', 'justificada'].includes(b.status)) return { error: 'Estado inválido' };
    return { date: String(b.date).slice(0, 10), status: b.status, note: String(b.note || '') };
  }
  const score = Number(b.score);
  const max_score = b.max_score === undefined ? 20 : Number(b.max_score);
  if (!b.name || !b.date || Number.isNaN(score) || Number.isNaN(max_score) || max_score <= 0 || score < 0 || score > max_score) {
    return { error: 'Datos inválidos (nombre, fecha, nota 0..máximo)' };
  }
  return { name: String(b.name).trim(), score, max_score, date: String(b.date).slice(0, 10), note: String(b.note || '') };
}

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Error del servidor' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('========================================');
  console.log(' Servidor de asistencia corriendo');
  console.log(' URL local:   ' + serverUrl());
  console.log(' Panel web:   ' + serverUrl() + '/');
  console.log(' Docente:     docente@escuela.local / docente123');
  console.log('========================================');
});
