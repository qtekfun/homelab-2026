# homelab-2026

Personal homelab Docker stack running on Proxmox → Ubuntu VM.

## Infrastructure

- **Host:** Proxmox (Intel i5-10500T, 62GB RAM, 2TB SSD)
- **VM:** Ubuntu (Docker host)
- **Storage:** 2x 14.6TB NAS HDD (USB), 2x 3.6TB NVMe
- **Domain:** qtekfun.net (Cloudflare DNS, no proxy)

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
│   ├── Nextcloud (nxtc.qtekfun.net)
│   ├── Nextcloud Media (newm.qtekfun.net)
│   ├── Immich (photos.qtekfun.net)
│   ├── Guacamole (remote.qtekfun.net)
│   ├── Portainer (manager.qtekfun.net)
│   ├── Grafana (grafana.qtekfun.net)
│   ├── n8n (n8n.qtekfun.net) + public webhooks
│   └── ntfy (ntfy.qtekfun.net) + own auth
│
└── VPN only (WireGuard + Tailscale)
├── Proxmox (proxmox.qtekfun.net)
└── FritzBox (router.qtekfun.net)
WireGuard (wg.qtekfun.net:1820) ── 10.13.13.0/24
Tailscale ── 100.106.248.74
## Services

| Service | Domain | Auth | Description |
|---------|--------|------|-------------|
| Traefik | proxy.qtekfun.net | Authelia | Reverse proxy |
| Authelia | auth.qtekfun.net | - | 2FA provider |
| CrowdSec | - | - | Intrusion detection |
| Nextcloud | nxtc.qtekfun.net | Nextcloud | Main cloud storage |
| Nextcloud Media | newm.qtekfun.net | Nextcloud | Media nextcloud |
| Immich | photos.qtekfun.net | Immich | Photo management |
| n8n | n8n.qtekfun.net | Authelia | Automation |
| Grafana | grafana.qtekfun.net | Authelia | Monitoring dashboards |
| Prometheus | - | internal | Metrics collection |
| Alertmanager | - | internal | Alert routing → ntfy |
| ntfy | ntfy.qtekfun.net | ntfy auth | Push notifications |
| Guacamole | remote.qtekfun.net | Authelia | Remote desktop |
| Portainer | manager.qtekfun.net | Authelia | Container management |
| Obsidian LiveSync | sync.qtekfun.net | CouchDB auth | Note sync |
| WireGuard | wg.qtekfun.net | - | VPN |
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
Timezone (e.g. Europe/Madrid)
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

## Known Issues & Technical Debt

- **fbonalair/traefik-crowdsec-bouncer** — this image is abandoned (last release 2022). Migration to `ghcr.io/thespad/traefik-crowdsec-bouncer` is planned.
- **alertmanager.yml** — ntfy credentials are hardcoded. Migration to envsubst or Docker secrets is pending.
- **n8n** — currently using SQLite. Migration to PostgreSQL is planned.
- **Collation warning** — n8n PostgreSQL container has a collation version mismatch (2.36 vs 2.41). Run `ALTER DATABASE n8n REFRESH COLLATION VERSION` to fix.

## Version Pinning Status

| Service | Pinned | Notes |
|---------|--------|-------|
| Traefik | ✅ v3.6.10 | |
| Authelia | ✅ v4.39.16 | |
| CrowdSec | ✅ v1.7.6 | |
| CrowdSec Bouncer | ❌ latest | Abandoned image, migration pending |
| WireGuard | ✅ 1.0.20250521-r1-ls105 | |
| Nextcloud | ✅ 32.0.6-ls416 | |
| Nextcloud Media | ✅ 32.0.6-ls416 | |
| Immich | ⚠️ release | Per immich recommendation |
| n8n | ✅ 2.12.2 | |
| Grafana | ✅ 12.4.1 | |
| Prometheus | ✅ v3.10.0 | |
| Alertmanager | ✅ v0.31.1 | |
| cAdvisor | ✅ v0.55.1 | |
| Node Exporter | ✅ v1.10.2 | |
| ntfy | ✅ v2.19.2 | |
| Portainer | ✅ 2.39.0 | |
| Guacamole | ✅ 1.6.0 | |
| Obsidian (CouchDB) | ✅ 3.5.1 | |
| Watchtower | ✅ 1.14.2 | |
| ddclient | ✅ v4.0.0-ls219 | |

## Alertmanager Credentials

Alertmanager does not support environment variable substitution natively. The solution uses `envsubst` on the host to generate the config file before starting the container.

### Setup

The template file is committed to the repo:
```
monitoring/alertmanager/alertmanager.yml.tmpl
```

The generated file is gitignored:
```
monitoring/alertmanager/alertmanager.yml
```

### Generate config (required after cloning or changing credentials)
```bash
export $(grep -v '^#' monitoring/.env | xargs)
envsubst < monitoring/alertmanager/alertmanager.yml.tmpl > monitoring/alertmanager/alertmanager.yml
```

### Variables required in monitoring/.env
```
NTFY_DOMAIN=ntfy.qtekfun.net
NTFY_USER=
NTFY_PASSWORD=
NTFY_ALERT_TOPIC=alerts-monitoring
```
