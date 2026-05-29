# Deployment Guide

## Overview

This document explains how to deploy the DevOps Demo API on a fresh Ubuntu 22.04 VPS using Docker, Docker Compose, NGINX, PostgreSQL, Redis, GitHub Actions, and optional monitoring components.

---

# Prerequisites

## VPS Requirements

Recommended specifications:

| Resource | Minimum          |
| -------- | ---------------- |
| CPU      | 2 vCPU           |
| Memory   | 2 GB RAM         |
| Storage  | 20 GB SSD        |
| OS       | Ubuntu 22.04 LTS |

---

# Step 1: Connect to the VPS

```bash
ssh root@YOUR_SERVER_IP
```

Verify connectivity:

```bash
uname -a
```

---

# Step 2: Run Server Bootstrap Script

The project includes a server hardening and provisioning script.

Execute:

```bash
sudo bash scripts/server-setup.sh \
--user deployer \
--pubkey "YOUR_PUBLIC_SSH_KEY"
```

The script automatically:

* Creates deployment user
* Configures SSH key authentication
* Disables root login
* Disables password authentication
* Installs Docker
* Installs Docker Compose
* Installs Fail2ban
* Installs UFW
* Installs Certbot
* Configures Docker log rotation
* Creates scheduled backup jobs

---

# Step 3: Log In as Deployment User

```bash
ssh deployer@YOUR_SERVER_IP
```

Verify Docker:

```bash
docker --version
docker compose version
```

---

# Step 4: Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/AI-DEVOPS-ASSIGNMENT.git

cd AI-DEVOPS-ASSIGNMENT
```

---

# Step 5: Configure Environment Variables

Create environment file:

```bash
cp .env.example .env
```

Example configuration:

```env
APP_ENV=production

POSTGRES_DB=appdb
POSTGRES_USER=appuser
POSTGRES_PASSWORD=strongpassword

REDIS_PASSWORD=strongredispassword

DOCKER_IMAGE=ghcr.io/YOUR_USERNAME/devops-demo-api
IMAGE_TAG=latest
```

---

# Step 6: Configure SSL

## Option A: Production Domain

```bash
bash scripts/setup-ssl.sh \
--domain api.example.com \
--email admin@example.com
```

This will:

* Generate Let's Encrypt certificates
* Install certificates into NGINX
* Enable HTTPS

---

## Option B: No Domain Available

```bash
bash scripts/setup-ssl.sh --self-signed
```

This creates self-signed certificates suitable for testing and assignment evaluation.

Note:

Browsers will display a security warning when using self-signed certificates.

---

# Step 7: Start Application

Build and start all services:

```bash
docker compose up --build -d
```

Services started:

* FastAPI
* PostgreSQL
* Redis
* NGINX

Verify:

```bash
docker ps
```

Expected containers:

```text
postgres
redis
api
nginx
```

---

# Step 8: Verify Application

## Root Endpoint

```bash
curl http://localhost
```

Expected:

```json
{
  "message": "DevOps Demo API is running"
}
```

---

## Health Check

```bash
curl http://localhost/health
```

Expected:

```json
{
  "status": "ok",
  "postgres": "ok",
  "redis": "ok"
}
```

---

## API Documentation

Open:

```text
http://SERVER_IP/docs
```

Swagger UI should be available.

---

# Step 9: Configure GitHub Actions

Navigate to:

GitHub Repository → Settings → Secrets and Variables → Actions

Create the following secrets:

```text
VPS_HOST
VPS_USER
VPS_SSH_KEY
GHCR_PAT
```

Optional:

```text
VPS_PORT
```

---

# Step 10: Configure GitHub Container Registry

The CI/CD pipeline pushes Docker images to GitHub Container Registry (GHCR).

Example image:

```text
ghcr.io/YOUR_USERNAME/devops-demo-api
```

Ensure:

* Packages are enabled
* GHCR Personal Access Token has package permissions

---

# Step 11: CI/CD Deployment Workflow

Deployment process:

```text
Developer Push
       │
       ▼
GitHub Actions
       │
       ▼
Lint Code
       │
       ▼
Run Tests
       │
       ▼
Build Docker Image
       │
       ▼
Push Image to GHCR
       │
       ▼
SSH Into VPS
       │
       ▼
Pull Latest Image
       │
       ▼
Restart API Container
       │
       ▼
Verify Health Endpoint
```

Deployment is triggered automatically when code is pushed to the main branch.

---

# Step 12: Enable Monitoring (Optional)

Start monitoring stack:

```bash
docker compose \
-f docker-compose.yml \
-f docker-compose.monitoring.yml \
up -d
```

---

## Grafana

URL:

```text
http://SERVER_IP:3000
```

Default credentials:

```text
admin
admin
```

---

## Prometheus

URL:

```text
http://SERVER_IP:9090
```

---

# Backup Strategy

Backups are automated using cron.

Manual execution:

```bash
bash scripts/backup.sh
```

Backs up:

* PostgreSQL database
* Redis snapshots

Backup retention:

```text
7 days
```

Backup location:

```text
/opt/backups/devops-demo
```

---

# Security Measures

The deployment includes:

## SSH Hardening

* SSH key authentication only
* Root login disabled
* Password authentication disabled

## Firewall

UFW rules:

```text
22/tcp
80/tcp
443/tcp
```

## Intrusion Prevention

Fail2ban enabled for:

* SSH protection
* NGINX authentication protection

## Container Security

* Non-root application container
* Internal Docker networks
* Restricted service exposure

---

# Log Management

## FastAPI

Application logs:

```bash
docker compose logs api
```

## NGINX

Reverse proxy logs:

```bash
docker compose logs nginx
```

## Docker

Log rotation configured:

```json
{
  "max-size": "10m",
  "max-file": "3"
}
```

---

# Troubleshooting

## Check Container Status

```bash
docker ps
```

---

## View Logs

```bash
docker compose logs -f
```

Specific service:

```bash
docker compose logs api
docker compose logs postgres
docker compose logs redis
docker compose logs nginx
```

---

## Restart Services

```bash
docker compose restart
```

Single service:

```bash
docker compose restart api
```

---

## Rebuild Application

```bash
docker compose up --build -d
```

---

# Disaster Recovery

## Restore PostgreSQL

```bash
gunzip < backup.sql.gz | psql -U appuser appdb
```

---

## Restore Redis

```bash
docker compose stop redis

cp dump.rdb /var/lib/docker/volumes/redis_data/_data/

docker compose start redis
```

---

# Conclusion

This deployment implements production-oriented DevOps practices including:

* Containerized application deployment
* Automated CI/CD
* Infrastructure automation
* Security hardening
* Backup and recovery
* Monitoring and observability
* SSL certificate management
* Health monitoring

The architecture is designed to be reproducible, secure, and suitable for real-world backend application deployments.
