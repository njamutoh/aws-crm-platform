require('dotenv').config();
const express  = require('express');
const mysql    = require('mysql2/promise');
const bcrypt   = require('bcryptjs');
const jwt      = require('jsonwebtoken');
const cors     = require('cors');
const path     = require('path');

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ── DB pool ────────────────────────────────────────────────────
const pool = mysql.createPool({
  host:               process.env.DB_HOST     || 'localhost',
  port:               process.env.DB_PORT     || 3306,
  user:               process.env.DB_USER     || 'root',
  password:           process.env.DB_PASSWORD || '',
  database:           process.env.DB_NAME     || 'nexuscrm',
  waitForConnections: true,
  connectionLimit:    10,
});

async function initDb() {
  try {
    const fs   = require('fs');
    const path = require('path');
    const sql  = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
    const stmts = sql.split(';').map(s => s.trim()).filter(s => s.length > 0);
    const conn = await pool.getConnection();
    for (const stmt of stmts) {
      await conn.query(stmt);
    }
    conn.release();
    console.log('✅ MySQL connected and schema initialised');
  } catch (e) {
    console.error('❌ MySQL init error:', e.message);
  }
}
initDb();

// ── Auth middleware ────────────────────────────────────────────
function auth(req, res, next) {
  const token = (req.headers.authorization || '').split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token' });
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET || 'dev_secret');
    next();
  } catch {
    res.status(403).json({ error: 'Invalid token' });
  }
}

// ══════════════════════════════════════════════════════════════
// AUTH
// ══════════════════════════════════════════════════════════════

app.post('/api/auth/register', async (req, res) => {
  try {
    const { name, email, password } = req.body;
    if (!name || !email || !password)
      return res.status(400).json({ error: 'All fields required' });
    const [existing] = await pool.query('SELECT id FROM users WHERE email=?', [email]);
    if (existing.length) return res.status(409).json({ error: 'Email already registered' });
    const hash = await bcrypt.hash(password, 12);
    const [r]  = await pool.query(
      'INSERT INTO users (name,email,password_hash) VALUES (?,?,?)', [name, email, hash]
    );
    const token = jwt.sign({ id: r.insertId, name, email }, process.env.JWT_SECRET || 'dev_secret', { expiresIn: '24h' });
    res.status(201).json({ token, user: { id: r.insertId, name, email } });
  } catch (e) { res.status(500).json({ error: 'Registration failed' }); }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email and password required' });
    const [rows] = await pool.query('SELECT * FROM users WHERE email=?', [email]);
    if (!rows.length) return res.status(401).json({ error: 'Invalid credentials' });
    const user  = rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) return res.status(401).json({ error: 'Invalid credentials' });
    await pool.query('UPDATE users SET last_login=NOW() WHERE id=?', [user.id]);
    const token = jwt.sign({ id: user.id, name: user.name, email: user.email }, process.env.JWT_SECRET || 'dev_secret', { expiresIn: '24h' });
    res.json({ token, user: { id: user.id, name: user.name, email: user.email } });
  } catch (e) { res.status(500).json({ error: 'Login failed' }); }
});

// ══════════════════════════════════════════════════════════════
// DASHBOARD
// ══════════════════════════════════════════════════════════════

app.get('/api/dashboard/stats', auth, async (req, res) => {
  const uid = req.user.id;
  try {
    const [[contacts]] = await pool.query('SELECT COUNT(*) AS total FROM contacts WHERE user_id=?', [uid]);
    const [[deals]]    = await pool.query('SELECT COUNT(*) AS total FROM deals WHERE user_id=?', [uid]);
    const [[revenue]]  = await pool.query(`SELECT COALESCE(SUM(value),0) AS total FROM deals WHERE user_id=? AND stage='closed_won'`, [uid]);
    const [[pipeline]] = await pool.query(`SELECT COALESCE(SUM(value),0) AS total FROM deals WHERE user_id=? AND stage NOT IN ('closed_won','closed_lost')`, [uid]);
    res.json({ contacts: contacts.total, deals: deals.total, revenue: parseFloat(revenue.total), pipeline: parseFloat(pipeline.total) });
  } catch (e) { res.status(500).json({ error: 'Failed to load stats' }); }
});

app.get('/api/dashboard/pipeline', auth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT d.id,d.title,d.value,d.stage,d.probability,c.name AS contact_name,c.company
       FROM deals d JOIN contacts c ON c.id=d.contact_id
       WHERE d.user_id=? AND d.stage!='closed_lost' ORDER BY d.value DESC`,
      [req.user.id]
    );
    const stages   = ['lead','qualified','proposal','negotiation','closed_won'];
    const pipeline = Object.fromEntries(stages.map(s => [s, []]));
    rows.forEach(r => pipeline[r.stage]?.push(r));
    res.json(pipeline);
  } catch (e) { res.status(500).json({ error: 'Failed to load pipeline' }); }
});

app.get('/api/dashboard/activity', auth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT a.description,a.type,a.created_at,c.name AS contact_name
       FROM activities a LEFT JOIN contacts c ON c.id=a.contact_id
       WHERE a.user_id=? ORDER BY a.created_at DESC LIMIT 12`,
      [req.user.id]
    );
    res.json(rows);
  } catch (e) { res.status(500).json({ error: 'Failed to load activity' }); }
});

// ══════════════════════════════════════════════════════════════
// CONTACTS
// ══════════════════════════════════════════════════════════════

app.get('/api/contacts', auth, async (req, res) => {
  try {
    const { search = '', status = '' } = req.query;
    let q = `SELECT c.*,COUNT(d.id) AS deal_count,COALESCE(SUM(d.value),0) AS total_value
             FROM contacts c LEFT JOIN deals d ON d.contact_id=c.id
             WHERE c.user_id=? AND (c.name LIKE ? OR c.email LIKE ? OR c.company LIKE ?)`;
    const p = [req.user.id, `%${search}%`, `%${search}%`, `%${search}%`];
    if (status) { q += ' AND c.status=?'; p.push(status); }
    q += ' GROUP BY c.id ORDER BY c.created_at DESC';
    const [rows] = await pool.query(q, p);
    res.json(rows);
  } catch (e) { res.status(500).json({ error: 'Failed to load contacts' }); }
});

app.post('/api/contacts', auth, async (req, res) => {
  try {
    const { name, email, company='', phone='', status='lead', notes='' } = req.body;
    if (!name || !email) return res.status(400).json({ error: 'Name and email required' });
    const [r]   = await pool.query('INSERT INTO contacts (user_id,name,email,company,phone,status,notes) VALUES (?,?,?,?,?,?,?)', [req.user.id, name, email, company, phone, status, notes]);
    const [[c]] = await pool.query('SELECT * FROM contacts WHERE id=?', [r.insertId]);
    res.status(201).json(c);
  } catch (e) { res.status(500).json({ error: 'Failed to create contact' }); }
});

app.put('/api/contacts/:id', auth, async (req, res) => {
  try {
    const { name, email, company, phone, status, notes } = req.body;
    await pool.query('UPDATE contacts SET name=?,email=?,company=?,phone=?,status=?,notes=?,updated_at=NOW() WHERE id=? AND user_id=?', [name, email, company, phone, status, notes, req.params.id, req.user.id]);
    const [[c]] = await pool.query('SELECT * FROM contacts WHERE id=?', [req.params.id]);
    res.json(c);
  } catch (e) { res.status(500).json({ error: 'Failed to update contact' }); }
});

app.delete('/api/contacts/:id', auth, async (req, res) => {
  try {
    await pool.query('DELETE FROM contacts WHERE id=? AND user_id=?', [req.params.id, req.user.id]);
    res.json({ message: 'Deleted' });
  } catch (e) { res.status(500).json({ error: 'Failed to delete contact' }); }
});

// ══════════════════════════════════════════════════════════════
// DEALS
// ══════════════════════════════════════════════════════════════

app.post('/api/deals', auth, async (req, res) => {
  try {
    const { contact_id, title, value=0, stage='lead', probability=10, close_date='', notes='' } = req.body;
    if (!contact_id || !title) return res.status(400).json({ error: 'Contact and title required' });
    const [r] = await pool.query('INSERT INTO deals (user_id,contact_id,title,value,stage,probability,close_date,notes) VALUES (?,?,?,?,?,?,?,?)', [req.user.id, contact_id, title, value, stage, probability, close_date || null, notes]);
    await pool.query('INSERT INTO activities (user_id,deal_id,contact_id,type,description) VALUES (?,?,?,?,?)', [req.user.id, r.insertId, contact_id, 'deal_created', `Deal "${title}" created`]);
    const [[deal]] = await pool.query('SELECT d.*,c.name AS contact_name FROM deals d JOIN contacts c ON c.id=d.contact_id WHERE d.id=?', [r.insertId]);
    res.status(201).json(deal);
  } catch (e) { res.status(500).json({ error: 'Failed to create deal' }); }
});

app.put('/api/deals/:id', auth, async (req, res) => {
  try {
    const { stage } = req.body;
    const [[old]]   = await pool.query('SELECT * FROM deals WHERE id=? AND user_id=?', [req.params.id, req.user.id]);
    if (!old) return res.status(404).json({ error: 'Not found' });
    await pool.query('UPDATE deals SET stage=?,updated_at=NOW() WHERE id=? AND user_id=?', [stage, req.params.id, req.user.id]);
    if (old.stage !== stage) {
      await pool.query('INSERT INTO activities (user_id,deal_id,contact_id,type,description) VALUES (?,?,?,?,?)', [req.user.id, req.params.id, old.contact_id, 'stage_changed', `"${old.title}" moved ${old.stage} → ${stage}`]);
    }
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: 'Failed to update deal' }); }
});

// ── Health check ───────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok', timestamp: new Date().toISOString() }));

// ── Pages ──────────────────────────────────────────────────────
app.get('/dashboard', (_req, res) => res.sendFile(path.join(__dirname, 'public', 'dashboard.html')));
app.get('*',          (_req, res) => res.sendFile(path.join(__dirname, 'public', 'index.html')));

// ── Start (export for tests) ───────────────────────────────────
const PORT = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(PORT, '0.0.0.0', () => console.log(`✅ CRM running on :${PORT}`));
}
module.exports = app;
