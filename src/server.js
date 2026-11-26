require('dotenv').config();
const express = require('express');
const session = require('express-session');
const SQLiteStore = require('connect-sqlite3')(session);
const path = require('path');
const auth = require('./auth');
const wa = require('./wa');

auth.ensureAdmin();

const app = express();
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, '..', 'views'));
app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(express.static(path.join(__dirname, '..', 'public')));
app.use(session({
  store: new SQLiteStore({ db: 'sessions.db', dir: './data' }),
  secret: process.env.SESSION_SECRET || 'change-me',
  resave: false,
  saveUninitialized: false,
  cookie: { maxAge: 1000 * 60 * 60 * 8 }
}));

// attach user
app.use((req, res, next) => {
  if (req.session && req.session.userId) {
    const u = require('./db').prepare('SELECT id,username,role FROM users WHERE id=?').get(req.session.userId);
    req.session.user = u || null;
  }
  next();
});

function ctx(req) { return { user: req.session.user, wa: wa.getState() }; }

// auth routes
app.get('/login', (req, res) => res.render('login', { error: null }));
app.post('/login', (req, res) => {
  const { username, password } = req.body;
  const u = auth.getUser(username);
  if (!u || !auth.checkPassword(password, u.password_hash)) {
    return res.render('login', { error: 'Invalid credentials' });
  }
  req.session.userId = u.id;
  req.session.user = { id: u.id, username: u.username, role: u.role };
  res.redirect('/');
});
app.post('/logout', (req, res) => { req.session.destroy(() => res.redirect('/login')); });

// dashboard
app.get('/', auth.requireAuth, (req, res) => res.render('dashboard', ctx(req)));

// send message
app.post('/send', auth.requireRole('operator'), async (req, res) => {
  try {
    await wa.sendMessage(req.body.to, req.body.text);
    res.redirect('/?sent=1');
  } catch (e) {
    res.status(500).send(e.message);
  }
});

// users management (admin)
app.get('/users', auth.requireRole('admin'), (req, res) => {
  res.render('users', { ...ctx(req), users: auth.listUsers(), roles: auth.ROLES });
});
app.post('/users/create', auth.requireRole('admin'), (req, res) => {
  try { auth.createUser(req.body.username, req.body.password, req.body.role); } catch (e) {}
  res.redirect('/users');
});
app.post('/users/:id/role', auth.requireRole('admin'), (req, res) => {
  auth.updateUserRole(req.params.id, req.body.role);
  res.redirect('/users');
});
app.post('/users/:id/delete', auth.requireRole('admin'), (req, res) => {
  if (String(req.params.id) !== String(req.session.user.id)) auth.deleteUser(req.params.id);
  res.redirect('/users');
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log('Open WA listening on', port);
  wa.init();
});