# OpenWA Installer + Auth Portal

Installer untuk OpenWA resmi (https://www.open-wa.org/) dengan portal login (user/pass + role) di depan dashboard.

## Install (Ubuntu 24)
```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/unas1990/open-wa-installer.git
cd open-wa-installer
sudo bash installer/install.sh
```

Installer akan:
- Install Node 22, Docker, PM2
- Clone OpenWA ke `/opt/openwa` (backend port 2786 internal)
- Setup portal di `/opt/openwa-portal` (public port, default 2785)
- Buat admin portal dari prompt

## Akses
- Portal login: `http://<IP-VPS>:<PUBLIC_PORT>`
- Setelah login, dashboard OpenWA tampil (proxy)
- Kelola user/role: `/users` (admin)
- OpenWA API key: `docker exec openwa-api cat /app/data/.api-key`

## Catatan
- NAT kamu: public 9812 -> internal portal port (default 2785).
- Data OpenWA persist di volume Docker. Data portal di `/opt/openwa-portal/data`.