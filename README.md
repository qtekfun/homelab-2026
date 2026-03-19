# homelab-2026

Personal homelab Docker stack running on Proxmox → Ubuntu VM.

## Infrastructure

- **Host:** Proxmox (Intel your-cpu, XX GB RAM, your-storage)
- **VM:** Ubuntu (Docker host)
- **Storage:** 2x 14.6TB NAS HDD (USB), 2x 3.6TB NVMe
- **Domain:** yourdomain.com (Cloudflare DNS, no proxy)

## Network Architecture
Internet
│
▼
Cloudflare DNS (DNS only, no proxy)
│
▼
Traefik (reverse proxy, TLS termination)
├── CrowdSec bouncer (IP blocking)
├── Authelia (2FA for protected services)
│
├── Public services (Authelia protected)
│   ├── Nextcloud (nxtc.yourdomain.com)
│   ├── Nextcloud Media (newm.yourdomain.com)
│   ├── Immich (photos.yourdomain.com)
│   ├── Guacamole (remote.yourdomain.com)
│   ├── Portainer (manager.yourdomain.com)
│   ├── Grafana (grafana.yourdomain.com)
│   ├── n8n (n8n.yourdomain.com) + public webhooks
│   └── ntfy (ntfy.yourdomain.com) + own auth
│
└── VPN only (WireGuard + Tailscale)
├── Proxmox (proxmox.yourdomain.com)
└── FritzBox (router.yourdomain.com)
WireGuard (wg.yourdomain.com:1820) ── 10.13.13.0/24
Tailscale ── <tailscale-ip>
## Services

| Service | Domain | Auth | Description |
|---------|--------|------|-------------|
| Traefik | proxy.yourdomain.com | Authelia | Reverse proxy |
| Authelia | auth.yourdomain.com | - | 2FA provider |
| CrowdSec | - | - | Intrusion detection |
| Nextcloud | nxtc.yourdomain.com | Nextcloud | Main cloud storage |
| Nextcloud Media | newm.yourdomain.com | Nextcloud | Media nextcloud |
| Immich | photos.yourdomain.com | Immich | Photo management |
| n8n | n8n.yourdomain.com | Authelia | Automation |
| Grafana | grafana.yourdomain.com | Authelia | Monitoring dashboards |
| Prometheus | - | internal | Metrics collection |
| Alertmanager | - | internal | Alert routing → ntfy |
| ntfy | ntfy.yourdomain.com | ntfy auth | Push notifications |
| Guacamole | remote.yourdomain.com | Authelia | Remote desktop |
| Portainer | manager.yourdomain.com | Authelia | Container management |
| Obsidian LiveSync | sync.yourdomain.com | CouchDB auth | Note sync |
| WireGuard | wg.yourdomain.com | - | VPN |
| ddclient | - | - | Dynamic DNS |
| Watchtower | - | - | Container update notifications |

## Deployment

### Prerequisites

- Docker + Docker Compose v2
- A `traefik` Docker network: `docker network create traefik`
- Cloudflare API token with DNS edit permissions

### Deploy a service

```bash
cd <service-directory>
cp .env.example .env
# Fill in .env with real values
docker compose --env-file .env up -d
Deploy order (first time)
Create traefik network: docker network create traefik
networking/traefik
networking/crowdsec
networking/authelia
All other services in any order
Environment Variables
Each service has a .env.example file with all required variables.
Copy to .env and fill in the values — .env files are gitignored.
Common variables
Variable
Description
PUID
User ID (typically 1000)
PGID
Group ID (typically 1000)
TZ
Timezone (e.g. Your/Timezone)
TRAEFIK_DOMAIN
Service subdomain
TRAEFIK_CERT_RESOLVER
Certificate resolver (cloudflare)
Secrets
Sensitive values (API keys, passwords, tokens) are stored in .env files only.
Never commit .env files — only .env.example with empty values.
Security
All services behind Traefik with automatic TLS (Let's Encrypt via Cloudflare DNS)
CrowdSec for intrusion detection and IP blocking
Authelia for 2FA on all exposed services
Docker hardening: no-new-privileges, cap_drop: ALL + minimal cap_add
Resource limits on all containers
Isolated Docker networks per service stack
Dependency updates managed by Renovate (weekly PRs)
Roadmap
[ ] Migrate from GitHub to self-hosted Forgejo
[ ] CI/CD pipeline: Renovate PR → merge → auto-deploy
[ ] n8n: migrate SQLite → PostgreSQL
[ ] Deploy Navidrome + Metube (music)
[ ] Deploy FreshRSS (news reader)
[ ] Deploy Calibre-Web (ebooks)
[ ] Centralize alertmanager credentials (remove hardcoded secrets)
[ ] Loki for container log aggregation
[ ] Splunk or alternative for security log analysis
