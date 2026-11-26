require('dotenv').config();
const express = require('express');
const session = require('express-session');
const { createProxyMiddleware } = require('http-proxy-middleware');
const path = require('path');
const auth = require('./auth');
const db = require('./db');
const { execSync } = require('child_process');

auth.ensureAdmin();

const app = express();
app.set('view engine','ejs');
app.set('views', path.join(__dirname,'..','views'));

app.use(session({
  secret: process.env.SESSION_SECRET || 'change-me',
  resave: false,
  saveUninitialized: false,
  cookie: { maxAge: 1000*60*60*8 }
}));

app.use((req,res,next)=>{
  if(req.session && req.session.userId){
    const u = db.prepare('SELECT id,username,role FROM users WHERE id=?').get(req.session.userId);
    req.session.user = u || null;
  }
  next();
});

const urlencoded = express.urlencoded({ extended: true });
const json = express.json();

// auth routes
app.get('/login',(req,res)=>res.render('login',{error:null}));
app.post('/login', urlencoded, (req,res)=>{
  const u=auth.getUser(req.body.username);
  if(!u || !auth.checkPassword(req.body.password,u.password_hash)){
    return res.render('login',{error:'Invalid credentials'});
  }
  req.session.userId=u.id;
  req.session.user={id:u.id,username:u.username,role:u.role};
  res.redirect('/');
});
app.post('/logout', (req,res)=>{req.session.destroy(()=>res.redirect('/login'));});

// change password
app.get('/password', auth.requireAuth, (req,res)=>res.render('password',{user:req.session.user,error:null}));
app.post('/password', auth.requireAuth, urlencoded, (req,res)=>{
  const u = db.prepare('SELECT * FROM users WHERE id=?').get(req.session.userId);
  if(!u || !auth.checkPassword(req.body.old || '', u.password_hash)){
    return res.render('password',{user:req.session.user,error:'Password lama salah'});
  }
  if(!req.body.new || req.body.new.length < 6){
    return res.render('password',{user:req.session.user,error:'Password baru minimal 6 karakter'});
  }
  auth.updatePassword(req.session.userId, req.body.new);
  res.redirect('/');
});

// user management
app.get('/users', auth.requireRole('admin'), (req,res)=>{
  res.render('users',{user:req.session.user, users:auth.listUsers(), roles:auth.ROLES});
});
app.post('/users/create', auth.requireRole('admin'), urlencoded, (req,res)=>{
  try { auth.createUser(req.body.username, req.body.password, req.body.role); } catch(e){}
  res.redirect('/users');
});
app.post('/users/:id/role', auth.requireRole('admin'), urlencoded, (req,res)=>{
  auth.updateUserRole(req.params.id, req.body.role);
  res.redirect('/users');
});
app.post('/users/:id/delete', auth.requireRole('admin'), (req,res)=>{
  if(String(req.params.id)!==String(req.session.user.id)) auth.deleteUser(req.params.id);
  res.redirect('/users');
});

// show OpenWA admin API key (admin only)
app.get('/api-key', auth.requireRole('admin'), (req,res)=>{
  let key = '';
  try {
    key = execSync('docker exec openwa-api cat /app/data/.api-key', { encoding: 'utf8', timeout: 5000 }).trim();
  } catch (e) {}
  res.render('apikey',{ user:req.session.user, key, error: !key });
});

// proxy to OpenWA backend
const backend = process.env.BACKEND_URL || 'http://127.0.0.1:2786';
const backendOrigin = new URL(backend).origin;
const proxy = createProxyMiddleware({
  target: backend,
  changeOrigin: true,
  ws: true,
  timeout: 0,
  proxyTimeout: 0,
  logLevel: 'silent',
  // Keep the browser Origin so OpenWA CORS/WS checks can allow the public origin.
  // Allowed origins are configured in OpenWA via CORS_ORIGINS.
});

app.use('/', auth.requireAuth, proxy);

const port = process.env.PORT || 2785;
const server = app.listen(port, ()=>console.log('OpenWA portal listening on', port));
server.on('upgrade', (req, socket, head) => {
  proxy.upgrade(req, socket, head);
});