# PharmaTransport Deployment Guide

## Prerequisites

- Ruby 3.2+
- PostgreSQL 14+ (production)
- Redis 6+ (for caching and Action Cable)
- Node.js 18+ (for asset compilation)

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection | `postgres://user:pass@host:5432/pharma_prod` |
| `RAILS_ENV` | Environment | `production` |
| `SECRET_KEY_BASE` | Rails secret (generate with `rails secret`) | `abc123...` |
| `PHARMA_API_TOKEN` | API authentication token | `secure-token-here` |
| `REDIS_URL` | Redis connection | `redis://localhost:6379/1` |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_HOST` | - | Application hostname |
| `RAILS_LOG_LEVEL` | `info` | Log level |
| `WEB_CONCURRENCY` | 2 | Puma workers |
| `RAILS_MAX_THREADS` | 5 | Threads per worker |
| `DATABASE_POOL` | 5 | DB connection pool |
| `RAILS_SERVE_STATIC_FILES` | false | Serve static files |
| `DISABLE_SSL` | - | Disable forced SSL |

### Email (SMTP)

| Variable | Description |
|----------|-------------|
| `SMTP_ADDRESS` | SMTP server |
| `SMTP_PORT` | SMTP port (587) |
| `SMTP_DOMAIN` | SMTP domain |
| `SMTP_USERNAME` | SMTP username |
| `SMTP_PASSWORD` | SMTP password |
| `ALERT_EMAIL` | Alert recipient |

### AI Integration

| Variable | Description |
|----------|-------------|
| `OPENAI_API_KEY` | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `AZURE_OPENAI_ENDPOINT` | Azure OpenAI endpoint |
| `AZURE_OPENAI_KEY` | Azure OpenAI key |

## Deployment Steps

### 1. Clone Repository

```bash
git clone <repo-url>
cd pharma-app
```

### 2. Install Dependencies

```bash
bundle install --deployment --without development test
```

### 3. Configure Environment

```bash
# Copy example env file
cp .env.example .env

# Edit with production values
vim .env
```

### 4. Database Setup

```bash
# Create database
RAILS_ENV=production rails db:create

# Run migrations
RAILS_ENV=production rails db:migrate

# Seed initial data (optional)
RAILS_ENV=production rails db:seed
```

### 5. Precompile Assets

```bash
RAILS_ENV=production rails assets:precompile
```

### 6. Start Server

```bash
RAILS_ENV=production bundle exec puma -C config/puma.rb
```

## Platform-Specific Guides

### Heroku

```bash
# Create app
heroku create pharma-transport

# Add PostgreSQL
heroku addons:create heroku-postgresql:standard-0

# Add Redis
heroku addons:create heroku-redis:premium-0

# Set environment variables
heroku config:set RAILS_ENV=production
heroku config:set SECRET_KEY_BASE=$(rails secret)
heroku config:set PHARMA_API_TOKEN=your-token

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate
```

### Docker

```dockerfile
# Dockerfile
FROM ruby:3.2-slim

RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev nodejs npm

WORKDIR /app

COPY Gemfile* ./
RUN bundle install --deployment --without development test

COPY . .

RUN RAILS_ENV=production SECRET_KEY_BASE=dummy rails assets:precompile

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgres://postgres:password@db:5432/pharma
      - REDIS_URL=redis://redis:6379/1
      - RAILS_ENV=production
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - PHARMA_API_TOKEN=${PHARMA_API_TOKEN}
    depends_on:
      - db
      - redis

  db:
    image: postgres:14
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=password

  redis:
    image: redis:6
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

### Kubernetes

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pharma-transport
spec:
  replicas: 3
  selector:
    matchLabels:
      app: pharma-transport
  template:
    metadata:
      labels:
        app: pharma-transport
    spec:
      containers:
      - name: web
        image: pharma-transport:latest
        ports:
        - containerPort: 3000
        env:
        - name: RAILS_ENV
          value: production
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: pharma-secrets
              key: database-url
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              name: pharma-secrets
              key: secret-key-base
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health/live
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
```

## SSL/TLS Configuration

### Let's Encrypt with Nginx

```nginx
server {
    listen 80;
    server_name pharma.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name pharma.example.com;

    ssl_certificate /etc/letsencrypt/live/pharma.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/pharma.example.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /cable {
        proxy_pass http://localhost:3000/cable;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

## Monitoring Setup

### Health Check Endpoints

| Endpoint | Purpose | Expected Response |
|----------|---------|-------------------|
| `/health` | Load balancer | `{"status":"ok"}` |
| `/health/ready` | K8s readiness | `{"ready":true}` |
| `/health/live` | K8s liveness | `{"alive":true}` |
| `/health/full` | Detailed status | Full system check |

### Recommended Monitoring

1. **Application Performance**
   - New Relic, DataDog, or Scout APM
   - Track response times, throughput, errors

2. **Infrastructure**
   - Prometheus + Grafana
   - Monitor CPU, memory, disk, network

3. **Logging**
   - ELK Stack (Elasticsearch, Logstash, Kibana)
   - Or CloudWatch Logs / Papertrail

4. **Alerting**
   - PagerDuty or OpsGenie
   - Alert on errors, slow responses, resource exhaustion

## Backup Strategy

### Database Backups

```bash
# Daily backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
pg_dump $DATABASE_URL | gzip > /backups/pharma_$DATE.sql.gz

# Keep last 30 days
find /backups -name "pharma_*.sql.gz" -mtime +30 -delete
```

### Redis Backup

```bash
# Enable RDB persistence in redis.conf
save 900 1
save 300 10
save 60 10000

# Copy RDB file to backup location
cp /var/lib/redis/dump.rdb /backups/redis_$(date +%Y%m%d).rdb
```

## Scaling Considerations

### Horizontal Scaling

1. **Web Servers**: Add more Puma workers/instances behind load balancer
2. **Database**: Use read replicas for read-heavy queries
3. **Cache**: Redis Cluster for high availability
4. **Background Jobs**: Sidekiq with multiple workers

### Vertical Scaling

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| Web Server | 1 CPU, 1GB RAM | 2 CPU, 4GB RAM |
| Database | 2 CPU, 4GB RAM | 4 CPU, 16GB RAM |
| Redis | 1 CPU, 1GB RAM | 2 CPU, 4GB RAM |

## Security Checklist

- [ ] SSL/TLS enabled for all connections
- [ ] Strong API tokens (32+ characters)
- [ ] Database credentials secured
- [ ] Redis password protected
- [ ] Firewall configured (only necessary ports open)
- [ ] Regular security updates
- [ ] Log monitoring for suspicious activity
- [ ] Rate limiting enabled
- [ ] CORS configured appropriately
