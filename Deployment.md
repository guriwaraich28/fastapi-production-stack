# Deployment Guide

This document describes how to deploy the FastAPI Production Stack on an Ubuntu VPS (AWS EC2 used in this project).


---

## Architecture

![Architecture](./docs/architecture.png)

The application stack consists of:

* FastAPI
* PostgreSQL
* Redis
* NGINX Reverse Proxy
* Prometheus
* Grafana
* Node Exporter
* PostgreSQL Exporter

Deployment is fully automated through GitHub Actions.

---

# Prerequisites

## VPS Requirements

Minimum recommended specifications:

| Resource | Recommended      |
| -------- | ---------------- |
| CPU      | 2 vCPU           |
| RAM      | 2 GB             |
| Storage  | 20 GB SSD        |
| OS       | Ubuntu 22.04 LTS |

This project was tested on:

* AWS EC2
* Ubuntu 22.04

---

# Step 1: Launch EC2 Instance

Create an EC2 instance.

Recommended:

* Ubuntu 22.04 LTS
* t2.small or t3.small
* Security Group configured with:

| Port | Protocol | Purpose    |
| ---- | -------- | ---------- |
| 22   | TCP      | SSH        |
| 80   | TCP      | HTTP       |
| 443  | TCP      | HTTPS      |
| 3000 | TCP      | Grafana    |
| 9090 | TCP      | Prometheus |

---

# Step 2: Connect to Server

```bash
ssh -i my-key.pem ubuntu@SERVER_IP
```

Verify connection:

```bash
hostname
```

---

# Step 3: Clone Repository

```bash
git clone https://github.com/<your-username>/fastapi-production-stack.git

cd fastapi-production-stack
```

---

# Step 4: Configure Environment Variables

Copy template:

```bash
cp .env.example .env
```

Edit values:

```bash
nano .env
```

Example:

```env
POSTGRES_DB=appdb
POSTGRES_USER=appuser
POSTGRES_PASSWORD=securepassword

REDIS_PASSWORD=redispassword

APP_ENV=production

GRAFANA_PASSWORD=admin123
```

---

# Step 5: Initial Server Setup

Run server hardening script:

```bash
sudo bash scripts/server-setup.sh \
--user deployer \
--pubkey "YOUR_PUBLIC_SSH_KEY"
```

This performs:

* System updates
* Deploy user creation
* SSH hardening
* Docker installation
* Docker Compose installation
* UFW firewall setup
* Fail2Ban setup
* Backup cron jobs

---

# Step 6: Configure SSL

## Option A — Let's Encrypt

```bash
sudo bash scripts/setup-ssl.sh \
--domain api.example.com \
--email admin@example.com
```

This will:

* Request Let's Encrypt certificate
* Configure NGINX certificates
* Enable HTTPS

---

## Option B — Self Signed

If no domain is available:

```bash
sudo bash scripts/setup-ssl.sh --self-signed
```

This generates:

```text
nginx/certs/fullchain.pem
nginx/certs/privkey.pem
```

Note:

Browsers will show certificate warnings when using self-signed certificates.

---

# Step 7: Start Core Application Stack

Deploy application services:

```bash
docker compose up -d
```

Services started:

* PostgreSQL
* Redis
* FastAPI
* NGINX

Verify:

```bash
docker compose ps
```

Expected:

```text
postgres      healthy
redis         healthy
fastapi-api   healthy
nginx-proxy   running
```

---

# Step 8: Verify Health Endpoint

Run:

```bash
curl http://localhost/health
```

Expected:

```json
{
  "status": "healthy"
}
```

---

# Step 9: Deploy Monitoring Stack

Start monitoring services:

```bash
docker compose \
-f docker-compose.yml \
-f docker-compose.monitoring.yml \
up -d
```

Services started:

* Prometheus
* Grafana
* Node Exporter
* PostgreSQL Exporter

Verify:

```bash
docker ps
```

Expected containers:

```text
prometheus
grafana
node-exporter
postgres-exporter
```

---

# Step 10: Configure Grafana

Open:

```text
http://SERVER_IP:3000
```

Default credentials:

```text
Username: admin
Password: <GRAFANA_PASSWORD>
```

---

## Add Prometheus Data Source

Navigate:

```text
Connections
→ Data Sources
→ Add Data Source
→ Prometheus
```

Prometheus URL:

```text
http://prometheus:9090
```

Click:

```text
Save & Test
```

Expected:

```text
Datasource is working
```

---

## Import Dashboard

Recommended Dashboard ID:

```text
1860
```

Node Exporter Full Dashboard.

Provides:

* CPU usage
* RAM usage
* Disk utilization
* Network metrics

---

# Prometheus Verification

Open:

```text
http://SERVER_IP:9090
```

Navigate:

```text
Status
→ Targets
```

Expected targets:

```text
prometheus
node-exporter
postgres-exporter
```

Status:

```text
UP
```

---

# GitHub Actions CI/CD Setup

Repository Secrets:

| Secret      | Description                     |
| ----------- | ------------------------------- |
| VPS_HOST    | EC2 Public IP                   |
| VPS_USER    | SSH User                        |
| VPS_PORT    | SSH Port                        |
| VPS_SSH_KEY | Private SSH Key                 |
| GHCR_PAT    | GitHub Container Registry Token |

---

# CI/CD Workflow

Every push to main triggers:

```text
Developer Push
        ↓
GitHub Actions
        ↓
Lint & Tests
        ↓
Docker Build
        ↓
Push Image to GHCR
        ↓
SSH Into EC2
        ↓
Deploy Containers
        ↓
Health Verification
```

---

# Backup Strategy

Automated via:

```bash
scripts/backup.sh
```

Components:

### PostgreSQL

```bash
pg_dump
```

Compressed:

```text
postgres/pg_TIMESTAMP.sql.gz
```

### Redis

```bash
BGSAVE
```

Stored as:

```text
redis_TIMESTAMP.rdb
```

---

# Backup Retention

Default:

```text
7 Days
```

Configurable via:

```env
RETENTION_DAYS=7
```

---

# Scheduled Tasks

Configured through cron.

View:

```bash
crontab -l
```

Example:

```cron
0 2 * * * backup.sh
0 3 * * * certbot renew
```

---

# Security Measures

Implemented controls:

### UFW Firewall

Allowed:

```text
22
80
443
```

### Fail2Ban

Protects:

* SSH
* NGINX Authentication

### SSH Hardening

* Root Login Disabled
* Password Authentication Disabled
* Key Authentication Only

### Docker Security

```text
no-new-privileges
```

enabled on containers.

---

# Troubleshooting

## Containers Not Starting

Check:

```bash
docker compose logs
```

---

## Application Health Check Failing

Check:

```bash
docker logs fastapi-api
```

Verify:

```bash
curl http://localhost/health
```

---

## Database Connection Issues

Check:

```bash
docker logs postgres
```

Verify:

```bash
docker exec -it postgres psql -U appuser
```

---

## Monitoring Not Working

Verify:

```bash
docker ps
```

Check Prometheus:

```bash
curl http://localhost:9090
```

Check Grafana:

```bash
curl http://localhost:3000
```

---

# Deployment Validation Checklist

* [x] FastAPI Running
* [x] PostgreSQL Running
* [x] Redis Running
* [x] NGINX Running
* [x] Health Endpoint Working
* [x] CI/CD Pipeline Passing
* [x] Monitoring Stack Running
* [x] Automated Backups Configured
* [x] Firewall Configured
* [x] Fail2Ban Configured
* [x] SSL Strategy Implemented

---

# Author

Gurwinder Singh Waraich

GitHub:
https://github.com/guriwaraich28
