# OpenWA Installer

Installer untuk **OpenWA** (official) dari https://www.open-wa.org/ (rmyndharis/OpenWA) di VPS Ubuntu 24.

## Install
```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/unas1990/open-wa-installer.git
cd open-wa-installer
sudo bash installer/install.sh
```

Installer akan:
- Install Docker + Compose
- Clone OpenWA ke `/opt/openwa`
- Jalankan single-container (SQLite) dengan dashboard di satu port
- Tampilkan Admin API key

## Akses
- Dashboard/API: `http://<IP-VPS>:<PORT>` (default 2785)
- Admin API key: `docker exec openwa-api cat /app/data/.api-key`

## Catatan
- Default bind host 0.0.0.0 agar bisa diakses via IP public/NAT.
- Data persist di volume Docker `openwa_openwa-data`.
- Untuk production (Postgres/Redis/MinIO), gunakan profile compose resmi OpenWA.