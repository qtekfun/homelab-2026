# homelab-2026

Self-hosted Docker stack running on a Proxmox VM (Ubuntu), managed via Forgejo CI/CD.

## Infrastructure

- **Host**: Proxmox (your-cpu, XX GB RAM)
- **VM**: Ubuntu (homelab-server), Tailscale IP: <tailscale-ip>
- **Docker dir**: `/home/deploy/docker/`
- **Repo**: git.yourdomain.com/your-username/homelab-2026
- **Domain**: yourdomain.com (Cloudflare DNS, no proxy)

## Services

| Service | Domain | Auth |
|---------|--------|------|
| Traefik | - | - |
| Authelia | auth.yourdomain.com | - |
| CrowdSec | - | - |
| Nextcloud | nxtc.yourdomain.com | Nextcloud |
| Nextcloud Media | newm.yourdomain.com | Nextcloud |
| Immich | photos.yourdomain.com | Immich |
| n8n | n8n.yourdomain.com | Authelia |
| Grafana | grafana.yourdomain.com | Authelia |
| ntfy | ntfy.yourdomain.com | ntfy auth |
| Guacamole | remote.yourdomain.com | Authelia |
| Portainer | manager.yourdomain.com | Authelia |
| Vaultwarden | bw.yourdomain.com | Vaultwarden |
| Obsidian | sync.yourdomain.com | CouchDB |
| Forgejo | git.yourdomain.com | Forgejo |
| Homepage | dash.yourdomain.com | Local/VPN only |
| Excalidraw | draw.yourdomain.com | Authelia |
| WireGuard | wg.yourdomain.com:1820 | - |
| Watchtower | - | - |
| ddclient | - | - |

## CI/CD

- **Runner**: Forgejo Actions (homelab-runner)
- **Deploy**: Auto-deploy on push to master when compose.yml changes
- **Renovate**: Weekly dependency updates (Saturdays 8AM)
- **Security**: Gitleaks + Grype on push and weekly

## Alertmanager Credentials

Alertmanager does not support environment variable substitution natively. Generate the config before starting:

```bash
export $(grep -v '^#' monitoring/.env | xargs)
envsubst < monitoring/alertmanager/alertmanager.yml.tmpl > monitoring/alertmanager/alertmanager.yml
Storage
Mount
Purpose
/
Root, Docker volumes
/mnt/immich
Immich photos
/mnt/immich-thumbs
Immich thumbnails
/mnt/media
Media files
/mnt/small-nxtc
Nextcloud small instance
/mnt/forgejo
Forgejo data
