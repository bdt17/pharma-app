# Production Readiness Checklist

## Pre-Deployment

### Environment Configuration

- [ ] `RAILS_ENV=production` set
- [ ] `SECRET_KEY_BASE` generated and secured
- [ ] `DATABASE_URL` configured for PostgreSQL
- [ ] `REDIS_URL` configured for caching/Action Cable
- [ ] `PHARMA_API_TOKEN` set to strong, unique value
- [ ] All sensitive credentials stored securely (not in repo)

### Database

- [ ] PostgreSQL 14+ installed and running
- [ ] Database created with `rails db:create`
- [ ] All migrations run with `rails db:migrate`
- [ ] Database user has minimal required permissions
- [ ] Connection pooling configured (PgBouncer recommended)
- [ ] Backup strategy in place
- [ ] Point-in-time recovery enabled

### Caching & Real-time

- [ ] Redis 6+ installed and running
- [ ] Redis password configured
- [ ] Action Cable adapter set to Redis
- [ ] Cache store configured for Redis
- [ ] Redis persistence enabled (RDB/AOF)

### Security

- [ ] SSL/TLS certificates installed
- [ ] All traffic forced to HTTPS
- [ ] Firewall configured (only ports 80, 443 open)
- [ ] API token authentication working
- [ ] Rate limiting enabled
- [ ] CORS configured for allowed origins
- [ ] Security headers configured (CSP, HSTS, etc.)
- [ ] No debug mode in production
- [ ] Error pages don't expose stack traces

### Performance

- [ ] Assets precompiled (`rails assets:precompile`)
- [ ] Asset compression enabled
- [ ] Database indexes in place
- [ ] Query caching enabled
- [ ] N+1 queries identified and fixed
- [ ] Puma configured for production (workers, threads)
- [ ] Memory limits configured

### Monitoring & Logging

- [ ] Application monitoring configured (APM)
- [ ] Error tracking configured (Sentry, Rollbar, etc.)
- [ ] Log aggregation configured
- [ ] Health check endpoints verified
- [ ] Uptime monitoring configured
- [ ] Alert thresholds defined

### Backup & Recovery

- [ ] Database backup automation
- [ ] Backup retention policy defined
- [ ] Recovery procedure documented and tested
- [ ] Redis data persistence configured
- [ ] Disaster recovery plan in place

---

## Deployment Verification

### Smoke Tests

Run these tests immediately after deployment:

```bash
# Health check
curl https://your-domain.com/health
# Expected: {"status":"ok",...}

# Full health check
curl https://your-domain.com/health/full
# Expected: All checks "healthy"

# Readiness probe
curl https://your-domain.com/health/ready
# Expected: {"ready":true,...}

# API authentication
curl -H "Authorization: Bearer $API_TOKEN" \
  https://your-domain.com/api/v1/trucks
# Expected: 200 OK with trucks list

# Create telemetry reading
curl -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"telemetry_reading":{"temperature_c":5.0}}' \
  https://your-domain.com/api/v1/trucks/1/telemetry
# Expected: 201 Created

# WebSocket connection
# Test with browser or wscat
wscat -c wss://your-domain.com/cable
# Expected: Connection established
```

### Functional Tests

- [ ] User can view dashboard
- [ ] Telemetry data is being received
- [ ] Alerts trigger on temperature excursion
- [ ] WebSocket updates work in console
- [ ] API endpoints return correct data
- [ ] Compliance reports generate correctly
- [ ] AI analysis works (simulation mode if no API key)

### Performance Tests

- [ ] API response times < 200ms (p95)
- [ ] Page load times < 3s
- [ ] WebSocket latency < 100ms
- [ ] Database query times < 50ms
- [ ] No memory leaks under load
- [ ] Error rate < 0.1%

---

## Post-Deployment

### Monitoring Setup

- [ ] APM dashboards configured
- [ ] Error alerts configured
- [ ] Performance alerts configured
- [ ] Resource usage alerts configured
- [ ] Business metric dashboards created

### Documentation

- [ ] API documentation accessible
- [ ] Runbook for common issues created
- [ ] On-call rotation defined
- [ ] Escalation paths documented

### Security Audit

- [ ] Penetration testing scheduled
- [ ] Dependency vulnerability scan
- [ ] Access review completed
- [ ] Audit logging verified

---

## Feature-Specific Checks

### Core Monitoring

- [ ] Temperature readings stored correctly
- [ ] Out-of-range alerts trigger
- [ ] Email notifications working
- [ ] Historical data queryable

### Route Management

- [ ] Routes can be created/updated
- [ ] Waypoints can be managed
- [ ] Route optimization works
- [ ] Risk assessment calculates correctly

### Chain of Custody

- [ ] Events create hash chain
- [ ] Chain verification passes
- [ ] Signatures can be captured
- [ ] Audit trail complete

### Digital Twin

- [ ] Simulations can be created
- [ ] Scenarios run correctly
- [ ] Replay functionality works
- [ ] Events are logged

### Warehouse Integration

- [ ] Warehouses can be managed
- [ ] Check-in/check-out works
- [ ] Temperature readings recorded
- [ ] Handoff reports generate

### Compliance

- [ ] Compliance verification runs
- [ ] Reports generate (JSON/PDF)
- [ ] Deviation reports can be filed
- [ ] Audit trail exports work

### Portal

- [ ] Portal users can be created
- [ ] Shipment sharing works
- [ ] Public tracking works (no auth)
- [ ] Webhooks fire correctly

### AI Integration

- [ ] Providers can be configured
- [ ] Prompts can be managed
- [ ] Analysis endpoints work
- [ ] Insights are generated
- [ ] Simulation mode fallback works

### Batch Processing

- [ ] Batch telemetry ingestion works
- [ ] Rate limiting is enforced
- [ ] Data export works
- [ ] Cleanup jobs run correctly

---

## Rollback Plan

If deployment fails:

1. **Immediate**: Switch load balancer to previous version
2. **Database**:
   - If schema changed: `rails db:rollback`
   - If data corrupted: Restore from backup
3. **Cache**: Clear Redis if necessary: `rails runner "Rails.cache.clear"`
4. **Notify**: Alert team of rollback
5. **Investigate**: Review logs for root cause

---

## Compliance Requirements

### GDP (Good Distribution Practice)

- [ ] Temperature logging continuous
- [ ] Audit trail immutable
- [ ] Chain of custody maintained
- [ ] Deviation reporting available
- [ ] Digital signatures supported
- [ ] Reports exportable

### Data Retention

- [ ] Telemetry: 90 days default
- [ ] Audit logs: 365 days minimum
- [ ] Compliance records: Per regulation
- [ ] AI requests: 30 days default

### Privacy

- [ ] PII handling documented
- [ ] Data access logged
- [ ] Retention policies enforced
- [ ] Right to deletion supported

---

## Emergency Contacts

| Role | Contact |
|------|---------|
| On-Call Engineer | [Phone/Slack] |
| Database Admin | [Phone/Slack] |
| Security Team | [Phone/Slack] |
| Management | [Phone/Slack] |

---

## Version Information

| Component | Version |
|-----------|---------|
| Ruby | 3.2.x |
| Rails | 8.1.x |
| PostgreSQL | 14.x |
| Redis | 6.x |
| Node.js | 18.x |

---

**Checklist completed by:** ________________

**Date:** ________________

**Approved by:** ________________
