import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { pool } from './db.js';
import { sendContactEmail } from './mailer.js';

const app = express();
const PORT = process.env.PORT || 3001;

/* ── Middleware ─────────────────────────────────────────────────── */
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc:   ["'self'", "'unsafe-inline'", "fonts.googleapis.com"],
      fontSrc:    ["'self'", "fonts.gstatic.com"],
      scriptSrc:  ["'self'"],
      imgSrc:     ["'self'", "data:", "https:"],
    }
  }
}));
app.use(cors({ origin: process.env.FRONTEND_URL || '*' }));
app.use(express.json());
app.use(express.static('public'));

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Too many requests — please try again later.' }
});
app.use('/api', limiter);

/* ── GET /api/projects ──────────────────────────────────────────── */
app.get('/api/projects', async (req, res) => {
  try {
    const { featured, tag, limit = 20, offset = 0 } = req.query;
    let query  = 'SELECT * FROM projects WHERE published = true';
    const vals = [];

    if (featured !== undefined) {
      vals.push(featured === 'true');
      query += ` AND featured = $${vals.length}`;
    }
    if (tag) {
      vals.push(`%${tag}%`);
      query += ` AND tags::text ILIKE $${vals.length}`;
    }

    query += ` ORDER BY sort_order ASC, created_at DESC`;
    query += ` LIMIT $${vals.length + 1} OFFSET $${vals.length + 2}`;
    vals.push(parseInt(limit), parseInt(offset));

    const { rows } = await pool.query(query, vals);
    res.json({ data: rows, count: rows.length });
  } catch (err) {
    console.error('GET /api/projects', err.message);
    res.status(500).json({ error: 'Failed to fetch projects.' });
  }
});

/* ── GET /api/projects/:id ──────────────────────────────────────── */
app.get('/api/projects/:id', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT * FROM projects WHERE id = $1 AND published = true',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Project not found.' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch project.' });
  }
});

/* ── GET /api/experience ────────────────────────────────────────── */
app.get('/api/experience', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT * FROM experience ORDER BY sort_order ASC'
    );
    res.json({ data: rows });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch experience.' });
  }
});

/* ── POST /api/contact ──────────────────────────────────────────── */
const contactLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 5 });

app.post('/api/contact', contactLimiter, async (req, res) => {
  const { name, email, message } = req.body;

  if (!name || !email || !message)
    return res.status(400).json({ error: 'All fields are required.' });
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))
    return res.status(400).json({ error: 'Invalid email address.' });
  if (message.length < 10 || message.length > 2000)
    return res.status(400).json({ error: 'Message must be 10–2000 characters.' });

  try {
    await pool.query(
      'INSERT INTO contact_messages (name, email, message) VALUES ($1, $2, $3)',
      [name.trim(), email.trim(), message.trim()]
    );
    await sendContactEmail({ name, email, message });
    res.json({ success: true, message: 'Message received — I\'ll be in touch soon!' });
  } catch (err) {
    console.error('POST /api/contact', err.message);
    res.status(500).json({ error: 'Failed to send message. Please try again.' });
  }
});

/* ── Health check ───────────────────────────────────────────────── */
app.get('/api/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: 'connected', ts: new Date().toISOString() });
  } catch {
    res.status(503).json({ status: 'error', db: 'disconnected' });
  }
});

/* ── 404 catch-all ──────────────────────────────────────────────── */
app.use((_req, res) => res.status(404).json({ error: 'Route not found.' }));

app.listen(PORT, () => console.log(`🚀  API running on http://localhost:${PORT}`));
export default app;
