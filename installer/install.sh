#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo bash installer/install.sh"
  exit 1
fi

OPENWA_DIR="/opt/openwa"
PORTAL_DIR="/opt/openwa-portal"
REPO_URL="https://github.com/rmyndharis/OpenWA.git"

apt-get update
apt-get install -y ca-certificates curl gnupg git whiptail

# Node 22
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

# Docker
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker

# Clone OpenWA
if [ ! -d "$OPENWA_DIR/.git" ]; then
  rm -rf "$OPENWA_DIR"
  git clone "$REPO_URL" "$OPENWA_DIR"
else
  cd "$OPENWA_DIR" && git pull --ff-only
fi
cd "$OPENWA_DIR"

PUBLIC_PORT=$(whiptail --inputbox "Public portal port" 8 40 2785 3>&1 1>&2 2>&3)
BACKEND_PORT=2786

# OpenWA .env
if [ ! -f .env ]; then
  cat > .env <<EOF
BIND_HOST=127.0.0.1
API_PORT=$BACKEND_PORT
NODE_ENV=production
TZ=UTC
EOF
else
  grep -q '^BIND_HOST=' .env && sed -i "s|^BIND_HOST=.*|BIND_HOST=127.0.0.1|" .env || echo 'BIND_HOST=127.0.0.1' >> .env
  grep -q '^API_PORT=' .env && sed -i "s|^API_PORT=.*|API_PORT=$BACKEND_PORT|" .env || echo "API_PORT=$BACKEND_PORT" >> .env
fi

docker compose -f docker-compose.dev.yml up -d --build

# Portal setup
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PORTAL_DIR"
rsync -a --exclude node_modules --exclude .git "$SRC_DIR/portal/" "$PORTAL_DIR/" 2>/dev/null || cp -r "$SRC_DIR/portal"/* "$PORTAL_DIR"/
cd "$PORTAL_DIR"
if [ ! -f .env ]; then
  ADMIN_USER=$(whiptail --inputbox "Portal admin username" 8 40 admin 3>&1 1>&2 2>&3)
  ADMIN_PASS=$(whiptail --passwordbox "Portal admin password" 8 40 3>&1 1>&2 2>&3)
  SECRET=$(openssl rand -hex 32)
  cat > .env <<EOF
PORT=$PUBLIC_PORT
SESSION_SECRET=$SECRET
DB_PATH=$PORTAL_DIR/data/portal.db
BACKEND_URL=http://127.0.0.1:$BACKEND_PORT
ADMIN_USER=$ADMIN_USER
ADMIN_PASS=$ADMIN_PASS
NODE_ENV=production
EOF
fi
mkdir -p data
npm install --omit=dev

# PM2 for portal
npm install -g pm2 2>/dev/null || true
pm2 delete openwa-portal 2>/dev/null || true
pm2 start src/server.js --name openwa-portal --cwd "$PORTAL_DIR"
pm2 save
pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true

# firewall
if command -v ufw >/dev/null; then
  ufw allow "${PUBLIC_PORT}/tcp" || true
fi

echo "Waiting for OpenWA backend..."
for i in $(seq 1 60); do
  if docker exec openwa-api curl -sf http://localhost:2785/api/health/ready >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

API_KEY=""
if docker exec openwa-api test -f /app/data/.api-key 2>/dev/null; then
  API_KEY="$(docker exec openwa-api cat /app/data/.api-key)"
fi

echo ""
echo "Installed."
echo "Portal (login): http://<server-ip>:$PUBLIC_PORT"
echo "OpenWA backend:  http://127.0.0.1:$BACKEND_PORT (internal)"
if [ -n "$API_KEY" ]; then
  echo "OpenWA Admin API key: $API_KEY"
else
  echo "OpenWA Admin API key: docker exec openwa-api cat /app/data/.api-key"
fi
echo "Portal users: login -> /users (admin only)"