# PharmaTransport - Multi-State Cold Chain Monitoring Platform

A Rails application for monitoring pharmaceutical cold chain logistics across multiple states, sites, and trucks.

## Features

- **Multi-State Organization**: Regions → Sites → Trucks hierarchy
- **Real-Time Monitoring**: Temperature and power status tracking via API
- **Risk Scoring**: Automatic risk calculation based on excursions, variance, and trends
- **Route Optimization**: Plan and optimize delivery routes with risk-based rerouting
- **Analytics Dashboard**: Executive insights with KPIs, charts, and filtering by region/site
- **Alerts**: Email notifications for out-of-range conditions

## Development Setup

### Prerequisites

- Ruby 3.2+
- SQLite3 (development/test)
- Node.js (for asset compilation)

### Installation

```bash
git clone <repo-url>
cd pharma-app
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
```

### Running Tests

```bash
bin/rails test
```

## MVP Deploy

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgres://user:pass@host:5432/dbname` |
| `RAILS_ENV` | Environment | `production` |
| `SECRET_KEY_BASE` | Rails secret key | `rake secret` output |
| `PHARMA_API_TOKEN` | API authentication token | `your-secure-token-here` |
| `APP_HOST` | Application hostname | `pharma-app.example.com` |
| `REDIS_URL` | Redis URL for Action Cable | `redis://localhost:6379/1` |
| `ACTION_CABLE_URL` | WebSocket endpoint | `wss://pharma-app.example.com/cable` |
| `SMTP_ADDRESS` | SMTP server address | `smtp.sendgrid.net` |
| `SMTP_PORT` | SMTP port | `587` |
| `SMTP_DOMAIN` | SMTP domain | `example.com` |
| `SMTP_USERNAME` | SMTP username | `apikey` |
| `SMTP_PASSWORD` | SMTP password | `your-smtp-password` |
| `WEB_CONCURRENCY` | Puma worker count | `2` |
| `RAILS_MAX_THREADS` | Puma threads per worker | `5` |

### Optional Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RAILS_LOG_LEVEL` | Log level | `info` |
| `RAILS_SERVE_STATIC_FILES` | Serve static files | `false` |
| `DISABLE_SSL` | Disable forced SSL | (unset) |

### Database Setup (Production)

```bash
# Run migrations
RAILS_ENV=production bundle exec rails db:migrate

# Seed initial data (optional)
RAILS_ENV=production bundle exec rails db:seed
```

### Starting the Server

Using Procfile (Heroku/Render/Dokku):
```bash
# The Procfile handles:
# web: bundle exec puma -C config/puma.rb
# release: bundle exec rails db:migrate
```

Manual start:
```bash
RAILS_ENV=production bundle exec puma -C config/puma.rb
```

### Deployment Platforms

#### Heroku

```bash
heroku create pharma-app
heroku addons:create heroku-postgresql:mini
heroku addons:create heroku-redis:mini
heroku config:set RAILS_ENV=production
heroku config:set SECRET_KEY_BASE=$(rake secret)
heroku config:set PHARMA_API_TOKEN=your-secure-token
heroku config:set APP_HOST=pharma-app.herokuapp.com
git push heroku main
```

#### Render

1. Create a new Web Service connected to your repo
2. Set build command: `bundle install`
3. Set start command: `bundle exec puma -C config/puma.rb`
4. Add PostgreSQL and Redis services
5. Set environment variables in dashboard

#### Docker

```dockerfile
# Dockerfile example
FROM ruby:3.2
WORKDIR /app
COPY Gemfile* ./
RUN bundle install
COPY . .
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

## API Endpoints

### Authentication

All API endpoints require HTTP Token authentication:
```bash
curl -H "Authorization: Token token=\"your-api-token\"" https://app/api/v1/trucks
```

### Endpoints

- `GET /api/v1/trucks` - List trucks
- `GET /api/v1/trucks/:id` - Show truck
- `POST /api/v1/trucks/:truck_id/monitorings` - Create monitoring reading
- `GET /api/v1/trucks_by_risk` - Trucks ordered by risk score
- `GET /api/v1/regions` - List regions
- `GET /api/v1/sites` - List sites
- `GET /api/v1/routes` - List routes
- `GET /api/v1/analytics/summary` - Analytics summary
- `GET /api/v1/analytics/regions` - Analytics by region
- `GET /api/v1/analytics/sites` - Analytics by site

### Creating Monitoring Data

```bash
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{"monitoring": {"temperature": 5.5, "power_status": "on", "recorded_at": "2025-01-01T12:00:00Z"}}' \
  https://app/api/v1/trucks/1/monitorings
```

## Architecture

```
app/
├── controllers/
│   ├── api/v1/           # API controllers
│   ├── analytics_controller.rb
│   ├── regions_controller.rb
│   ├── routes_controller.rb
│   ├── sites_controller.rb
│   └── trucks_controller.rb
├── models/
│   ├── monitoring.rb     # Temperature readings
│   ├── region.rb         # State/region grouping
│   ├── route.rb          # Delivery routes
│   ├── site.rb           # Physical locations
│   ├── truck.rb          # Vehicles with temp thresholds
│   └── waypoint.rb       # Route stops
├── services/
│   ├── analytics_service.rb      # Analytics computations
│   ├── monitoring_broadcaster.rb # Real-time updates
│   ├── risk_scorer.rb            # Risk calculation
│   └── route_optimizer.rb        # Route optimization
└── views/
    ├── analytics/        # Executive dashboard
    ├── regions/
    ├── routes/
    ├── sites/
    └── trucks/
```

## License

Proprietary - All rights reserved.
