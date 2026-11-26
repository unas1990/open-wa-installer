#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo bash installer/install.sh"
  exit 1
fi

APP_DIR="/opt/openwa"
REPO_URL="https://github.com/rmyndharis/OpenWA.git"

apt-get update
apt-get install -y ca-certificates curl gnupg git whiptail

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
if [ ! -d "$APP_DIR/.git" ]; then
  rm -rf "$APP_DIR"
  git clone "$REPO_URL" "$APP_DIR"
else
  cd "$APP_DIR" && git pull --ff-only
fi

cd "$APP_DIR"

PORT=$(whiptail --inputbox "Public port for OpenWA" 8 40 2785 3>&1 1>&2 2>&3)

# .env
if [ ! -f .env ]; then
  cat > .env <<EOF
BIND_HOST=0.0.0.0
API_PORT=$PORT
NODE_ENV=production
TZ=UTC
EOF
else
  # ensure bind host external
  grep -q '^BIND_HOST=' .env && sed -i "s|^BIND_HOST=.*|BIND_HOST=0.0.0.0|" .env || echo 'BIND_HOST=0.0.0.0' >> .env
  grep -q '^API_PORT=' .env && sed -i "s|^API_PORT=.*|API_PORT=$PORT|" .env || echo "API_PORT=$PORT" >> .env
fi

docker compose -f docker-compose.dev.yml up -d --build

echo "Waiting for OpenWA to become healthy..."
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
echo "OpenWA installed."
echo "Dashboard/API: http://<server-ip>:$PORT"
echo "Swagger:       http://<server-ip>:$PORT/api/docs (if enabled)"
if [ -n "$API_KEY" ]; then
  echo "Admin API key: $API_KEY"
else
  echo "Admin API key: docker exec openwa-api cat /app/data/.api-key"
fi
echo ""
echo "Logs: docker logs -f openwa-api"