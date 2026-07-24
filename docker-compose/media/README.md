# Media Server Docker Compose

Docker Compose stack for media server with Navidrome, qBittorrent, Spotyist, and Cloudflare Tunnel.

## Services

- **Navidrome**: Music streaming server
- **qBittorrent**: Torrent client with web UI
- **Spotyist**: Spotify library cleanup web app (self-hosted, served via the tunnel)
- **Cloudflare Tunnel**: Secure remote access for Navidrome and Spotyist

## Quick Start

### 1. Setup Environment

```bash
# Copy example environment file
cp .env.example .env

# Get your user/group IDs
id -u  # Use this for QBIT_PUID
id -g  # Use this for QBIT_PGID

# Edit .env with your values
vim .env
```

### 2. Create Required Directories

```bash
# qBittorrent config directory
mkdir -p /Users/<username>/.config/qbittorrent

# Ensure downloads directory exists
# QBIT_DOWNLOADS_PATH should point to /Volumes/archive/mediaserver
```

### 3. Start Services

```bash
# Start all services
docker compose up -d

# Or start specific service
docker compose up -d qbittorrent
docker compose up -d navidrome
```

## Accessing Services

### Navidrome

- **Local**: http://localhost:4533
- **Remote**: Through Cloudflare Tunnel (configured in tunnel settings)

### qBittorrent

qBittorrent is configured for **localhost-only access** for security.

#### Option 1: SSH Tunnel (Recommended)

```bash
# Create SSH tunnel
ssh -L 8080:localhost:8080 <username>@<server-ip>

# Keep terminal open and access in browser
http://localhost:8080
```

**For background tunnel**:
```bash
# Start tunnel in background
ssh -fN -L 8080:localhost:8080 <username>@<server-ip>

# Kill tunnel when done
pkill -f "ssh.*8080:localhost:8080"
```

**Default credentials**:
- Username: `admin`
- Password: `adminadmin`
- ⚠️ Change password on first login!

#### Option 2: Local Network Access

If you need direct access from local network, modify `compose.yml`:

```yaml
ports:
  - "8080:8080"  # Instead of 127.0.0.1:8080:8080
```

⚠️ **Warning**: Only use this if server is not exposed to internet.

## Configuration

### qBittorrent Settings

After first login:

1. **Change default password**: Settings → Web UI → Authentication
2. **Set download path**: Settings → Downloads → Default Save Path = `/downloads`
3. **Disable UPnP**: Settings → Connection → Uncheck "Use UPnP/NAT-PMP"

When adding torrents, you can select subdirectories within `/downloads` (mapped to `QBIT_DOWNLOADS_PATH`).

### Environment Variables

See `.env.example` for all available variables:

- `QBIT_PUID` / `QBIT_PGID`: User/Group IDs for file permissions
- `TIMEZONE`: Timezone (e.g., Europe/Kyiv)
- `QBIT_CONFIG_PATH`: Config storage location
- `QBIT_DOWNLOADS_PATH`: Downloads directory (should be /Volumes/archive/mediaserver)

### Spotyist

1. Clone the repo on the server and point the build at it:
   ```bash
   git clone git@github.com:yevhenii-nepsha/spotyist.git
   # set SPOTYIST_REPO_PATH in .env to the cloned path
   ```
2. Set `SPOTYIST_CLIENT_ID`, `SPOTYIST_SESSION_SECRET` (reuse the existing
   value so sessions survive), and `SPOTYIST_DOMAIN` in `.env`.
3. Build and start:
   ```bash
   docker compose build spotyist && docker compose up -d spotyist
   ```
4. In the Cloudflare Zero Trust dashboard, add a Public Hostname to the
   tunnel: `spotyist.<domain>` → `http://spotyist:8000`. The container has
   no published port — the tunnel reaches it over `media-network`.
5. Ensure the Spotify app has the redirect URI
   `https://spotyist.<domain>/api/auth/callback`.

## Security Features

- **Localhost binding**: qBittorrent Web UI only accessible via localhost
- **Isolated network**: All services in dedicated Docker network
- **No privilege escalation**: `no-new-privileges` security option enabled
- **Health checks**: Automatic container health monitoring

## Useful Commands

```bash
# View logs
docker compose logs -f qbittorrent
docker compose logs -f navidrome

# Restart service
docker compose restart qbittorrent

# Stop all services
docker compose down

# Update images
docker compose pull
docker compose up -d
```

## Troubleshooting

### qBittorrent permission issues

Ensure PUID/PGID match the owner of download directory:

```bash
ls -ln /Volumes/archive/mediaserver
# Check UID/GID and update .env accordingly
```

### Can't access qBittorrent

Check if container is running:
```bash
docker ps | grep qbittorrent
docker compose logs qbittorrent
```

### SSH tunnel connection refused

Ensure qBittorrent is running on server:
```bash
ssh <username>@<server-ip> "docker ps | grep qbittorrent"
```
