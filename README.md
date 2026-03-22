# 🏠 homelab-2026

> Self-hosted Docker stack on Proxmox · Managed via Forgejo CI/CD · Automatic TLS · 2FA on everything

---

## 📐 Architecture

```
Internet
    │
    ▼
Cloudflare DNS  (DNS-only, no proxy)
    │
    ▼
Traefik v3  (reverse proxy · TLS termination)
    ├── CrowdSec bouncer  (IP blocking)
    └── Authelia  (2FA / SSO)
         │
         ├── 🌐 Public services (Authelia-protected)
         │   ├── Nextcloud · Immich · Vaultwarden
         │   ├── n8n · Grafana · Guacamole · Portainer
         │   └── ntfy · Forgejo · Excalidraw
         │
         └── 🔒 VPN-only
             ├── Homepage dashboard
             ├── Proxmox UI
             └── Router UI

WireGuard ── 10.x.x.0/24
Tailscale  ── overlay network
```

---

## 🧩 Services

### 🔐 Networking & Security

| Service | Description | Auth |
|---------|-------------|------|
| [Traefik](https://traefik.io) | Reverse proxy, automatic TLS via Cloudflare DNS challenge | — |
| [Authelia](https://www.authelia.com) | 2FA / SSO provider for all exposed services | — |
| [CrowdSec](https://www.crowdsec.net) | Intrusion detection + Traefik bouncer for IP blocking | — |
| [WireGuard](https://www.wireguard.com) | VPN server | — |
| [ddclient](https://ddclient.net) | Dynamic DNS updater | — |

### ☁️ Storage & Files

| Service | Description | Auth |
|---------|-------------|------|
| [Nextcloud](https://nextcloud.com) | Primary cloud storage & collaboration | Nextcloud |
| Nextcloud Media | Secondary Nextcloud instance for media | Nextcloud |
| [Immich](https://immich.app) | Self-hosted photo & video library with ML | Immich |
| [Vaultwarden](https://github.com/dani-garcia/vaultwarden) | Bitwarden-compatible password manager | Vaultwarden |

### 🤖 Automation & Dev

| Service | Description | Auth |
|---------|-------------|------|
| [n8n](https://n8n.io) | Low-code workflow automation | Authelia |
| [Forgejo](https://forgejo.org) | Self-hosted Git forge | Forgejo |
| Forgejo Runner | CI/CD pipeline executor | — |
| [Renovate](https://docs.renovatebot.com) | Automated dependency updates | — |

### 📊 Monitoring

| Service | Description | Auth |
|---------|-------------|------|
| [Grafana](https://grafana.com) | Dashboards & visualization | Authelia |
| [Prometheus](https://prometheus.io) | Metrics collection & storage | — |
| [Alertmanager](https://prometheus.io/docs/alerting/alertmanager/) | Alert routing → ntfy | — |
| [cAdvisor](https://github.com/google/cadvisor) | Container metrics | — |
| Node Exporter | Host system metrics | — |
| [ntfy](https://ntfy.sh) | Push notification broker | ntfy auth |

### 🖥️ Management

| Service | Description | Auth |
|---------|-------------|------|
| [Portainer](https://www.portainer.io) | Docker management UI | Authelia |
| [Guacamole](https://guacamole.apache.org) | Clientless remote desktop gateway | Authelia |
| [Homepage](https://gethomepage.dev) | Service dashboard | Local/VPN only |
| [Excalidraw](https://excalidraw.com) | Self-hosted whiteboard | Authelia |
| [Watchtower](https://containrrr.dev/watchtower) | Container image auto-updater | — |

---

## ⚙️ CI/CD

Powered by **Forgejo Actions** with three pipelines:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `deploy.yml` | Push to `master` | Detects changed services, SSH-deploys only those |
| `renovate.yml` | Weekly (Sat 8AM) | Opens PRs to update pinned Docker image versions |
| `security-scan.yml` | Push + weekly (Sun 4AM) | Runs Gitleaks (secrets) + Grype (CVEs) |

Auto-merge is enabled for minor/patch updates. Major updates and security-critical services (`traefik`, `authelia`, `crowdsec`) require manual review.

---

## 🚀 Getting Started

### Prerequisites

- Docker + Docker Compose v2
- A domain with Cloudflare DNS
- Cloudflare API token with DNS edit permissions

### Create the shared Traefik network

```bash
docker network create traefik
```

### Deploy a service

```bash
cd <service-directory>
cp .env.example .env
# Fill in .env with real values
docker compose up -d
```

### First-time deploy order

```
1. networking/traefik
2. networking/crowdsec
3. networking/authelia
4. Everything else (any order)
```

### Alertmanager config

Alertmanager doesn't support env var substitution natively. Generate the config before starting:

```bash
export $(grep -v '^#' monitoring/.env | xargs)
envsubst < monitoring/alertmanager/alertmanager.yml.tmpl > monitoring/alertmanager/alertmanager.yml
```

---

## 📁 Storage Layout

| Mount | Purpose |
|-------|---------|
| `/` | Root filesystem, Docker volumes |
| `/mnt/immich` | Immich original photos |
| `/mnt/immich-thumbs` | Immich thumbnails & previews |
| `/mnt/media` | Shared media files |
| `/mnt/small-nxtc` | Nextcloud Media instance data |
| `/mnt/forgejo` | Forgejo repositories |

---

## 🔧 Configuration Patterns

Every service follows the same conventions:

- **Independent compose files** — each service has its own `compose.yml`, deployed separately
- **Pinned image versions** — all images locked to specific tags with `# renovate: datasource=docker` for auto-updates
- **`.env` for secrets** — never committed; `.env.example` provided as template
- **Security hardening** — `no-new-privileges:true`, `cap_drop: ALL`, minimal `cap_add`
- **Resource limits** — CPU and memory limits on every container
- **Healthchecks** — 30s interval, 5s timeout, 3 retries on all services
- **Traefik labels** — standardized label pattern for routing, TLS, and middleware

### Common `.env` variables

| Variable | Description |
|----------|-------------|
| `PUID` / `PGID` | User/group ID (typically `1000`) |
| `TZ` | Timezone (e.g. `Europe/Madrid`) |
| `TRAEFIK_DOMAIN` | Service subdomain |
| `TRAEFIK_ROUTER_NAME` | Unique router name for Traefik |
| `TRAEFIK_CERT_RESOLVER` | Certificate resolver (`cloudflare`) |
