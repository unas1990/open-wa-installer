#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo bash installer/install.sh"
  exit 1
fi

APP_DIR="/opt/open-wa"
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"

apt-get update
apt-get install -y curl git whiptail ca-certificates gnupg

# Node 20
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

# Chromium for whatsapp-web.js
apt-get install -y chromium chromium-sandbox fonts-liberation libnss3 libatk-bridge2.0-0 libxkbcommon0 libgtk-3-0 2>/dev/null || true

# PM2
npm install -g pm2

# copy app
mkdir -p "$APP_DIR"
rsync -a --exclude node_modules --exclude .git "$SRC_DIR"/ "$APP_DIR"/ 2>/dev/null || cp -r "$SRC_DIR"/* "$APP_DIR"/

cd "$APP_DIR"
if [ ! -f .env ]; then
  ADMIN_USER=$(whiptail --inputbox "Admin username" 8 40 admin 3>&1 1>&2 2>&3)
  ADMIN_PASS=$(whiptail --passwordbox "Admin password" 8 40 3>&1 1>&2 2>&3)
  PORT=$(whiptail --inputbox "App port" 8 40 3000 3>&1 1>&2 2>&3)
  SECRET=$(openssl rand -hex 32)
  cat > .env <<EOF
PORT=$PORT
SESSION_SECRET=$SECRET
DB_PATH=$APP_DIR/data/app.db
WA_CLIENT_ID=openwa
ADMIN_USER=$ADMIN_USER
ADMIN_PASS=$ADMIN_PASS
NODE_ENV=production
EOF
fi

mkdir -p data
npm install --omit=dev

# firewall
if command -v ufw >/dev/null; then
  ufw allow "${PORT:-3000}/tcp" || true
fi

pm2 delete open-wa 2>/dev/null || true
pm2 start src/server.js --name open-wa --cwd "$APP_DIR"
pm2 save
pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true

echo "Installed. Open http://<server-ip>:${PORT:-3000}"