# DevOps Demo API

## Overview

This project demonstrates the deployment and productionization of a FastAPI-based backend application using Docker, PostgreSQL, Redis, NGINX, GitHub Actions CI/CD, automated backups, monitoring, SSL automation, and VPS hardening.

The goal of this project is to showcase real-world DevOps practices including containerization, infrastructure automation, deployment automation, monitoring, security, and operational reliability.

---

## Features

### Application Layer

* FastAPI REST API
* Swagger/OpenAPI documentation
* Health check endpoint
* PostgreSQL integration
* Redis caching

### Infrastructure

* Dockerized application
* Multi-stage Docker builds
* Docker Compose orchestration
* NGINX reverse proxy
* Environment variable management

### Security

* SSH hardening
* UFW firewall
* Fail2ban intrusion prevention
* Non-root Docker containers
* Docker log rotation

### Operations

* Automated PostgreSQL backups
* Redis snapshot backups
* Backup retention policy
* SSL certificate automation
* Health monitoring

### CI/CD

* GitHub Actions pipeline
* Automated image builds
* GitHub Container Registry (GHCR)
* Automated VPS deployment
* Deployment verification

### Monitoring (Bonus)

* Prometheus
* Grafana
* Node Exporter
* PostgreSQL Exporter

---

## Architecture

```text
                    Internet
                        │
                        ▼
                 Cloudflare (Optional)
                        │
                        ▼
                    NGINX
                        │
                        ▼
                   FastAPI API
                    │       │
                    ▼       ▼
                 Redis   PostgreSQL
                    │
                    ▼
         Prometheus + Grafana
```

---

## Technology Stack

### Backend

* FastAPI
* Python 3.12

### Database

* PostgreSQL 16

### Cache

* Redis 7

### Reverse Proxy

* NGINX

### Containerization

* Docker
* Docker Compose

### CI/CD

* GitHub Actions
* GitHub Container Registry (GHCR)

### Monitoring

* Prometheus
* Grafana
* Node Exporter
* PostgreSQL Exporter

### Security

* UFW
* Fail2ban
* Let's Encrypt

---

## Project Structure

```text
AI-DEVOPS-ASSIGNMENT
│
├── .github/
│   └── workflows/
│       └── deploy.yml
│
├── app/
│   ├── Dockerfile
│   ├── main.py
│   └── requirements.txt
│
├── nginx/
│   ├── nginx.conf
│   └── conf.d/
│       └── default.conf
│
├── postgres/
│   └── init.sql
│
├── monitoring/
│   ├── prometheus.yml
│   └── grafana/
│
├── scripts/
│   ├── backup.sh
│   ├── server-setup.sh
│   └── setup-ssl.sh
│
├── docker-compose.yml
├── docker-compose.monitoring.yml
├── .env.example
├── README.md
└── DEPLOYMENT.md
```

---

## Environment Variables

Example:

```env
APP_ENV=production

POSTGRES_DB=appdb
POSTGRES_USER=appuser
POSTGRES_PASSWORD=strongpassword

REDIS_PASSWORD=redispassword

DOCKER_IMAGE=ghcr.io/username/devops-demo-api
IMAGE_TAG=latest
```

---

## Running Locally

### Clone Repository

```bash
git clone <repository-url>
cd AI-DEVOPS-ASSIGNMENT
```

### Configure Environment

```bash
cp .env.example .env
```

Update values as required.

### Start Application

```bash
docker compose up --build -d
```

### Verify Containers

```bash
docker ps
```

### Access Services

FastAPI:

```text
http://localhost
```

Swagger UI:

```text
http://localhost/docs
```

Health Check:

```text
http://localhost/health
```

---

## Monitoring Setup

Start monitoring stack:

```bash
docker compose \
-f docker-compose.yml \
-f docker-compose.monitoring.yml \
up -d
```

Prometheus:

```text
http://localhost:9090
```

Grafana:

```text
http://localhost:3000
```

Default credentials:

```text
Username: admin
Password: admin
```

---

## CI/CD Pipeline

The GitHub Actions workflow performs:

1. Code checkout
2. Dependency installation
3. Linting with Ruff
4. Automated tests
5. Docker image build
6. Push image to GHCR
7. Deploy to VPS
8. Health verification

Deployment is triggered automatically on push to the main branch.

---

## Health Checks

The application exposes:

```http
GET /health
```

Checks:

* Application status
* PostgreSQL connectivity
* Redis connectivity

Returns:

```json
{
  "status": "ok",
  "postgres": "ok",
  "redis": "ok"
}
```

---

## Logging Strategy

### Application Logs

FastAPI logs:

* Request processing
* Cache hits
* Database operations
* Application startup/shutdown

### NGINX Logs

JSON formatted access logs:

* Request method
* URI
* Response status
* Request duration
* User agent

### Docker Log Rotation

Configured using:

```json
{
  "max-size": "10m",
  "max-file": "3"
}
```

to prevent excessive disk usage.

---

## Security Measures

### Server Security

* Dedicated deployment user
* SSH key authentication
* Root login disabled
* Password authentication disabled
* UFW firewall enabled
* Fail2ban protection

### Container Security

* Non-root application container
* Network segmentation
* Internal database access only
* No unnecessary exposed ports

### SSL Security

* Let's Encrypt support
* Automatic certificate renewal
* Self-signed certificate support for evaluation environments

---

## Backup Strategy

### PostgreSQL

Uses:

```bash
pg_dump
```

to create compressed backups.

### Redis

Uses:

```bash
BGSAVE
```

to create Redis snapshots.

### Retention Policy

* 7-day retention
* Automatic cleanup of old backups

### Scheduled Backups

```cron
0 2 * * * bash scripts/backup.sh
```

---

## SSL Strategy

### Production

Let's Encrypt certificates:

```bash
bash scripts/setup-ssl.sh \
--domain api.example.com \
--email admin@example.com
```

### No Domain Available

Generate self-signed certificates:

```bash
bash scripts/setup-ssl.sh --self-signed
```

This allows HTTPS testing even without a public domain.

---

## Cloudflare Integration (Optional)

Cloudflare can be placed in front of NGINX to provide:

* DNS management
* DDoS protection
* CDN caching
* WAF protection
* SSL enhancement

Recommended SSL mode:

```text
Full (Strict)
```

---

## Future Improvements

* Kubernetes deployment
* Blue-Green deployment strategy
* OpenTelemetry tracing
* AWS S3 backup storage
* Cloudflare Tunnel integration
* AI/LLM endpoint integration
* AlertManager notifications

---

## Assignment Requirements Covered

* Dockerized FastAPI application
* Docker Compose setup
* PostgreSQL integration
* Redis integration
* NGINX reverse proxy
* Environment variable management
* SSL setup
* Security hardening
* Health checks
* Logging strategy
* Backup strategy
* GitHub Actions CI/CD
* Automated deployment
* Monitoring stack
* Infrastructure automation

This project demonstrates a production-oriented DevOps workflow suitable for modern backend application deployments.