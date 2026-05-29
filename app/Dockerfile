# ── Stage 1: Builder ──────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

# Build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --upgrade pip && \
    pip install --prefix=/install --no-cache-dir -r requirements.txt

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM python:3.12-slim AS runtime

LABEL maintainer="Gurwinder Singh" \
      org.opencontainers.image.title="devops-demo-api" \
      org.opencontainers.image.description="Production FastAPI service" \
      org.opencontainers.image.version="1.0.0"

# Python runtime optimizations
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Create non-root user
RUN addgroup --system app && \
    adduser --system --ingroup app app

WORKDIR /app

# Copy installed packages from builder stage
COPY --from=builder /install /usr/local

# Copy application source
COPY --chown=app:app . .

# Switch to non-root user
USER app

EXPOSE 8000

# Container Health Check
HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=20s \
            --retries=3 \
CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

# Start FastAPI
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000","--workers","2","--proxy-headers","--log-level","info"]