const { Client, LocalAuth } = require('whatsapp-web.js');
const QRCode = require('qrcode');

let client = null;
let status = 'disconnected'; // disconnected, qr, ready
let qrDataUrl = null;
let info = null;

function init() {
  client = new Client({
    authStrategy: new LocalAuth({ clientId: process.env.WA_CLIENT_ID || 'openwa' }),
    puppeteer: { headless: true, executablePath: process.env.CHROME_PATH || '/usr/bin/chromium', args: ['--no-sandbox', '--disable-setuid-sandbox'] }
  });

  client.on('qr', async (qr) => {
    status = 'qr';
    try { qrDataUrl = await QRCode.toDataURL(qr); } catch (e) { qrDataUrl = null; }
  });
  client.on('ready', () => { status = 'ready'; qrDataUrl = null; info = client.info; });
  client.on('authenticated', () => { status = 'authenticated'; });
  client.on('auth_failure', () => { status = 'auth_failure'; });
  client.on('disconnected', () => { status = 'disconnected'; info = null; });

  client.initialize().catch(err => console.error('WA init error', err));
}

async function sendMessage(to, text) {
  if (!client || status !== 'ready') throw new Error('WA not ready');
  const chatId = to.includes('@') ? to : `${to}@c.us`;
  return client.sendMessage(chatId, text);
}

function getState() { return { status, qrDataUrl, info }; }

module.exports = { init, sendMessage, getState };