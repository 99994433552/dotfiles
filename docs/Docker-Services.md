# Docker Compose Services

Docker Compose configurations for server services. These are automatically symlinked to `~/docker-compose/` when using the `server` profile.

## Services

### Media Stack (`media/`)

Media server services including:
- **Navidrome** - Music streaming server
- **Cloudflare Tunnel** - Secure proxy for exposing services

**Domains:**
- `navidrome.example.com` → Navidrome (container, port 4533)
- `jellyfin.example.com` → Jellyfin (host, port 8096, running locally via brew)
- `econumix.example.com` → Econumix (host, port 8501)
- `spotyist.example.com` → Spotyist (container, port 8000)

## Setup on New Server

### 1. Install dotfiles

```bash
cd ~/.dotfiles
./install
```

### 2. Set server profile

```bash
echo "server" > ~/.dotfiles-profile
```

### 3. Configure Cloudflare Tunnel

Create `.env` file with your tunnel token:

```bash
cd ~/docker-compose/media
cp .env.example .env
```

Edit `.env` and add your Cloudflare Tunnel token:
```bash
TUNNEL_TOKEN=your_actual_token_here
```

**How to get tunnel token:**
1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to: Access > Tunnels > [Your Tunnel]
3. Click "Configure" > Copy the token from the install command

### 4. Configure Navidrome paths

Edit `compose.yml` and update volume paths:
```yaml
volumes:
  - "/path/to/.config/navidrome:/data"
  - "/path/to/music/library:/music:rw"
```

### 5. Start services

```bash
cd ~/docker-compose/media
docker compose up -d
```

### 6. Verify services

```bash
# Check running containers
docker ps

# View logs
docker compose logs -f

# Test endpoints
curl http://localhost:4533  # Navidrome
```

## Managing Services

### Start/Stop

```bash
cd ~/docker-compose/media

# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart specific service
docker compose restart navidrome

# View logs
docker compose logs -f navidrome
```

### Update Images

```bash
cd ~/docker-compose/media

# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d --force-recreate
```

## Cloudflare Tunnel Configuration

The tunnel runs as the `cloudflared-tunnel` container inside the media stack, started with `tunnel run --token`. Ingress is therefore managed remotely in the Cloudflare dashboard, not in a local file. The host `~/.cloudflared/config.yml` is a leftover from an earlier host-run setup and is not used — the old `homebrew.mxcl.cloudflared` launchd daemon has been removed.

Container services must resolve on `media-network`, so their target is the container name (e.g. `http://navidrome:4533`). Host services use `http://host.docker.internal:<port>`.

**Current ingress rules:**
- `jellyfin.example.com` → `http://host.docker.internal:8096`
- `navidrome.example.com` → `http://navidrome:4533`
- `econumix.example.com` → `http://host.docker.internal:8501`
- `spotyist.example.com` → `http://spotyist:8000`

To modify ingress rules:
1. Go to Cloudflare Zero Trust Dashboard
2. Navigate to: Networks > Tunnels > [Your Tunnel] > Public Hostname
3. Add/edit routes as needed

## Troubleshooting

### Tunnel connection errors

```bash
# Check tunnel logs
docker compose logs tunnel

# Verify token is set
docker compose config | grep TUNNEL_TOKEN
```

### Navidrome not accessible

```bash
# Check if container is running
docker ps | grep navidrome

# Check Navidrome logs
docker compose logs navidrome

# Verify port is listening
lsof -i :4533
```

### Music library not visible

Ensure volume paths are correct and accessible:
```bash
# Check if music directory exists
ls -la /Volumes/archive/music/Library

# Check permissions
id  # Note your UID (should match user: 1000:1000 in compose.yml)
```

## Security Notes

- Never commit `.env` files to git (already in `.gitignore`)
- Tunnel token provides full access to your Cloudflare tunnel
- Keep credentials secure and rotate regularly
- Use read-only mounts where possible (`:ro` flag)

## Adding New Services

To add new services to the media stack:

1. Edit `compose.yml` and add service definition
2. Update this README with service details
3. Add any required environment variables to `.env.example`
4. Update ingress rules in Cloudflare dashboard if exposing publicly

Example:
```yaml
services:
  new-service:
    image: example/service:latest
    container_name: new-service
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - CONFIG_VAR=${CONFIG_VAR}
```
