# Open WA Gateway

WhatsApp gateway + admin GUI (roles: admin/operator/viewer).

## OS recommendation (Proxmox VM, NAT via Mikrotik public IP)
- Use **Debian 12 (Bookworm) minimal** for stability/long support.
- Alternative: Ubuntu 24.04 LTS.
- VM: 2 vCPU, 4GB RAM, 40GB disk. Forward ports (app + 22) via Mikrotik NAT.

## Install
```bash
sudo bash installer/install.sh
```
Installer uses whiptail GUI prompts for admin creds and port.

## Roles
- admin: manage users/roles
- operator: send messages
- viewer: read-only dashboard

## Notes
- First run shows QR in dashboard; scan with WhatsApp.
- Data stored in /opt/open-wa/data.