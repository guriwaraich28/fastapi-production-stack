#!/usr/bin/env bash
# scripts/server-setup.sh — Run ONCE on a fresh Ubuntu 22.04 VPS
# Usage: sudo bash scripts/server-setup.sh --user deployer --pubkey "ssh-ed25519 AAAA..."
set -euo pipefail

DEPLOY_USER=""
PUB_KEY=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --user)   DEPLOY_USER="$2"; shift 2 ;;
    --pubkey) PUB_KEY="$2";     shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

[[ -z "$DEPLOY_USER" || -z "$PUB_KEY" ]] && {
  echo "Usage: $0 --user <username> --pubkey \"<public key>\""
  exit 1
}

echo "🔧 Updating system packages…"
apt-get update -q && apt-get upgrade -y -q

echo "👤 Creating deploy user: $DEPLOY_USER"
id "$DEPLOY_USER" &>/dev/null || adduser --disabled-password --gecos "" "$DEPLOY_USER"

# Add SSH key
SSH_DIR="/home/$DEPLOY_USER/.ssh"
mkdir -p "$SSH_DIR"
touch "$SSH_DIR/authorized_keys"

grep -qxF "$PUB_KEY" "$SSH_DIR/authorized_keys" 2>/dev/null || \
echo "$PUB_KEY" >> "$SSH_DIR/authorized_keys"
chmod 700 "$SSH_DIR" && chmod 600 "$SSH_DIR/authorized_keys"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$SSH_DIR"

echo "🔒 Hardening SSH…"
cat > /etc/ssh/sshd_config.d/99-hardening.conf <<EOF
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
X11Forwarding no
EOF
systemctl reload sshd

echo "🔥 Setting up UFW firewall…"
apt-get install -y -q ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   comment 'SSH'
ufw allow 80/tcp   comment 'HTTP'
ufw allow 443/tcp  comment 'HTTPS'
ufw --force enable
echo "  UFW status:"
ufw status numbered

echo "🛡️  Installing fail2ban…"
apt-get install -y -q fail2ban
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = systemd

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s

[nginx-http-auth]
enabled  = true
EOF
systemctl enable --now fail2ban

echo "📥 Installing Git..."
apt-get install -y -q git

echo "🐳 Installing Docker…"
apt-get install -y -q curl
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
fi
usermod -aG sudo,docker "$DEPLOY_USER" 2>/dev/null || true

mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

systemctl restart docker

echo "📦 Installing Docker Compose plugin…"
apt-get install -y -q docker-compose-plugin

echo "🔐 Installing Certbot..."
apt-get install -y -q certbot

echo "⏰ Setting up cron jobs for deployer…"
CRON_FILE="/tmp/deployer_cron"
cat > "$CRON_FILE" <<EOF
# Daily backup at 2 AM
0 2 * * * cd ~/devops-demo && bash scripts/backup.sh >> /var/log/backup.log 2>&1

# Let's Encrypt auto-renewal
0 3 * * * certbot renew --quiet && docker compose -f ~/devops-demo/docker-compose.yml exec nginx nginx -s reload
EOF
crontab -u "$DEPLOY_USER" "$CRON_FILE"
rm "$CRON_FILE"

echo ""
echo "✅ Server hardening complete!"
echo ""
echo "Next steps:"
echo "  1. Log in as $DEPLOY_USER (not root) and verify access"
echo "  2. Clone your repo to ~/devops-demo"
echo "  3. Copy .env.example to .env and fill in secrets"
echo "  4. Run: bash scripts/setup-ssl.sh --domain <your-domain> --email <your-email>"
echo "  5. Run: docker compose up -d"