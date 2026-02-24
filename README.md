# Self-Hosted Readeck Deployment on Hetzner Cloud

Production-ready Readeck deployment for Ubuntu 22.04 on Hetzner Cloud using Docker Compose, PostgreSQL, and Nginx as a TLS reverse proxy.

## Project Overview

This repository provides an end-to-end blueprint to run Readeck in production with:

- Hetzner Cloud VM provisioning
- Dockerized Readeck stack
- PostgreSQL persistence
- Nginx reverse proxy and TLS termination
- Scheduled backups and recovery scripts
- Safe update workflow

## Tech Stack

- **Infrastructure**: Hetzner Cloud (Ubuntu 22.04)
- **Container Runtime**: Docker Engine + Docker Compose v2
- **Application**: Readeck (`codeberg.org/readeck/readeck` image)
- **Database**: PostgreSQL 16 (Alpine)
- **Reverse Proxy**: Nginx
- **Certificates**: Let's Encrypt (Certbot)
- **Ops**: Bash maintenance scripts (`backup`, `restore`, `update`)

## Repository Structure

```text
.
|-- .env.example
|-- .gitignore
|-- README.md
|-- docker-compose.yml
|-- docker/
|   `-- .dockerignore
|-- nginx/
|   `-- readeck.conf
`-- scripts/
    |-- backup.sh
    |-- restore.sh
    `-- update.sh
```

## 1. Create Hetzner Cloud Server

1. Create a new server in Hetzner Cloud Console:
   - Location: closest to your audience
   - Image: **Ubuntu 22.04**
   - Type: CX22 or larger
   - SSH key: add your public key
2. Assign and attach a floating IP (recommended for portability).
3. Point DNS:
   - `A  yourdomain.com -> <server-ip>`
   - `A  www.yourdomain.com -> <server-ip>` (optional)

## 2. Base Server Hardening

SSH into server:

```bash
ssh root@your_server_ip
```

Create non-root user and lock down SSH:

```bash
adduser deploy
usermod -aG sudo deploy
mkdir -p /home/deploy/.ssh
cp /root/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
```

Optional but recommended:

- Disable password auth in `/etc/ssh/sshd_config`
- Set `PermitRootLogin no`
- Restart SSH: `systemctl restart ssh`

Enable firewall:

```bash
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

## 3. Install Docker and Dependencies

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release nginx certbot python3-certbot-nginx

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

Re-login so docker group applies.

## 4. Clone and Configure Project

```bash
git clone https://github.com/your-username/self-hosted-readeck-deployment.git
cd self-hosted-readeck-deployment
cp .env.example .env
```

Edit `.env`:

- Set `READECK_SERVER_BASE_URL=https://yourdomain.com`
- Replace all secret placeholders
- Keep `POSTGRES_*` credentials strong and unique

Generate secrets quickly:

```bash
openssl rand -base64 32
```

## 5. Start Readeck Stack

```bash
docker compose pull
docker compose up -d
```

Check health:

```bash
docker compose ps
docker compose logs -f readeck
```

## 6. Configure Nginx Reverse Proxy

Copy config:

```bash
sudo cp nginx/readeck.conf /etc/nginx/sites-available/readeck.conf
sudo ln -s /etc/nginx/sites-available/readeck.conf /etc/nginx/sites-enabled/readeck.conf
sudo nginx -t
sudo systemctl reload nginx
```

Issue TLS cert:

```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

Certbot auto-renew timer is installed by default. Verify:

```bash
systemctl list-timers | grep certbot
```

## 7. Backups and Recovery

Make scripts executable:

```bash
chmod +x scripts/*.sh
```

Manual backup:

```bash
./scripts/backup.sh
```

Restore backup:

```bash
./scripts/restore.sh backups/<timestamp>/
```

Recommended cron job (daily 03:30):

```cron
30 3 * * * cd /opt/self-hosted-readeck-deployment && ./scripts/backup.sh >> /var/log/readeck-backup.log 2>&1
```

## 8. Safe Updates

```bash
./scripts/update.sh
```

What update script does:

1. Creates pre-update backup
2. Pulls latest container images
3. Recreates containers with current config
4. Runs prune on unused images

## Security Notes

- Expose only ports **80/443** publicly
- Keep `.env` out of git
- Use long, random secrets
- Restrict SSH with keys only
- Keep Ubuntu packages, Docker images, and Nginx updated
- Backup off-server (S3/object storage or second host)
- Consider fail2ban and Cloudflare/WAF for public deployments

## Readeck Configuration Notes

This setup uses Readeck environment variables commonly documented in Readeck deployment docs and official image examples, including:

- `READECK_SERVER_*` (host/base URL/prefix/trust)
- `READECK_DATABASE_*`
- `READECK_MAIL_*`
- `READECK_ALLOWED_HOSTS`, `READECK_TRUSTED_PROXIES`
- `READECK_LOG_LEVEL`, `READECK_SECRET_KEY`

Always verify against latest upstream docs before production rollout:

- https://readeck.org/en/docs
- https://codeberg.org/readeck/readeck

## Portfolio Notes

This repository is intentionally structured as a deployable DevOps showcase:

- Infra-aware documentation
- Reproducible container orchestration
- Operations scripts for lifecycle management
- Security and reliability controls expected in production

## License

MIT (or your preferred license)
