#!/usr/bin/env bash
# scripts/setup-ssl.sh
# Usage:
#   ./scripts/setup-ssl.sh --domain api.example.com --email admin@example.com
#   ./scripts/setup-ssl.sh --self-signed   (no domain available)
set -euo pipefail

DOMAIN=""
EMAIL=""
SELF_SIGNED=false
CERT_DIR="./nginx/certs"

usage() {
  echo "Usage: $0 --domain <domain> --email <email>"
  echo "       $0 --self-signed"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --domain)      DOMAIN="$2";  shift 2 ;;
    --email)       EMAIL="$2";   shift 2 ;;
    --self-signed) SELF_SIGNED=true; shift ;;
    *) usage ;;
  esac
done

mkdir -p "$CERT_DIR"

if ! command -v openssl &>/dev/null; then
  apt-get update -q
  apt-get install -y openssl
fi

if $SELF_SIGNED; then
  echo "⚠️  Generating self-signed certificate (development / no-domain use)…"
  openssl req -x509 -nodes -days 365 \
    -newkey rsa:4096 \
    -keyout  "$CERT_DIR/privkey.pem" \
    -out     "$CERT_DIR/fullchain.pem" \
    -subj "/C=US/ST=Dev/L=Dev/O=DevOps Demo/CN=localhost"
  echo "✅ Self-signed certificate written to $CERT_DIR"
  echo ""
  echo "NOTE: Browsers will show a warning. For production, use --domain with a real domain."
  exit 0
fi

[[ -z "$DOMAIN" || -z "$EMAIL" ]] && usage

echo "🔐 Obtaining Let's Encrypt certificate for $DOMAIN…"

# Ensure certbot is available
if ! command -v certbot &>/dev/null; then
  apt-get update -q && apt-get install -y certbot
fi

# Stop NGINX temporarily so certbot can bind :80
docker compose stop nginx 2>/dev/null || true

certbot certonly --standalone \
  --non-interactive \
  --agree-tos \
  --email "$EMAIL" \
  -d "$DOMAIN"

# Copy certs to our volume path
cp /etc/letsencrypt/live/"$DOMAIN"/fullchain.pem "$CERT_DIR/fullchain.pem"
cp /etc/letsencrypt/live/"$DOMAIN"/privkey.pem   "$CERT_DIR/privkey.pem"

# Restart NGINX
docker compose up -d nginx

echo "✅ Let's Encrypt certificate installed for $DOMAIN"
echo ""
echo "Auto-renewal: add this cron job (runs twice daily):"
echo "  0 3 * * * certbot renew --quiet && docker compose exec nginx nginx -s reload"   