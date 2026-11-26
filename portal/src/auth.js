const bcrypt = require('bcryptjs');
const db = require('./db');
const ROLES = ['admin', 'operator', 'viewer'];
const RANK = { viewer: 1, operator: 2, admin: 3 };
function hashPassword(p){return bcrypt.hashSync(p,10);}
function checkPassword(p,h){return bcrypt.compareSync(p,h);}
function getUser(username){return db.prepare('SELECT * FROM users WHERE username=?').get(username);}
function createUser(username,password,role='viewer'){
  if(!ROLES.includes(role)) throw new Error('bad role');
  return db.prepare('INSERT INTO users (username,password_hash,role) VALUES (?,?,?)').run(username,hashPassword(password),role);
}
function updateUserRole(id,role){ if(!ROLES.includes(role)) throw new Error('bad role'); db.prepare('UPDATE users SET role=? WHERE id=?').run(role,id); }
function deleteUser(id){ db.prepare('DELETE FROM users WHERE id=?').run(id); }
function listUsers(){ return db.prepare('SELECT id,username,role,created_at FROM users ORDER BY id').all(); }
function ensureAdmin(){
  const count = db.prepare('SELECT COUNT(*) c FROM users').get().c;
  if(count===0){
    const u=process.env.ADMIN_USER||'admin';
    const p=process.env.ADMIN_PASS||'change-me';
    createUser(u,p,'admin');
    console.log('Created default portal admin:',u);
  }
}
function requireAuth(req,res,next){
  if(!req.session || !req.session.user) return res.redirect('/login');
  next();
}
function requireRole(min){
  return (req,res,next)=>{
    if(!req.session||!req.session.user) return res.redirect('/login');
    if(RANK[req.session.user.role]<RANK[min]) return res.status(403).send('Forbidden');
    next();
  };
}
module.exports={ROLES,hashPassword,checkPassword,getUser,createUser,updateUserRole,deleteUser,listUsers,ensureAdmin,requireAuth,requireRole};