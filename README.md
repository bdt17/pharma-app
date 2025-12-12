# PharmaTransport - Multi-State Cold Chain Monitoring Platform

A Rails application for monitoring pharmaceutical cold chain logistics across multiple states, sites, and trucks.

## Documentation

| Document | Description |
|----------|-------------|
| [API Reference](docs/API_REFERENCE.md) | Complete API endpoint documentation |
| [Architecture](docs/ARCHITECTURE.md) | System design and data flow |
| [Deployment Guide](docs/DEPLOYMENT.md) | Production deployment instructions |
| [Production Checklist](docs/PRODUCTION_CHECKLIST.md) | Pre-deployment verification |
| [Changelog](docs/CHANGELOG.md) | Version history and changes |

## Features

### Core Platform
- **Multi-State Organization**: Regions → Sites → Trucks hierarchy
- **Real-Time Monitoring**: Temperature and power status tracking via API
- **Risk Scoring**: Automatic risk calculation based on excursions, variance, and trends
- **Route Optimization**: Plan and optimize delivery routes with risk-based rerouting
- **Analytics Dashboard**: Executive insights with KPIs, charts, and filtering by region/site
- **Alerts**: Email notifications for out-of-range conditions

### IoT & AI Features (Phase 3)
- **IoT Telemetry Ingestion**: GPS + temperature + humidity + speed from truck devices
- **Real-Time WebSocket Updates**: Live console with Action Cable broadcasting
- **Route Risk Assessment**: AI-like risk scoring with recommendations
- **Chain of Custody**: Tamper-evident shipment event tracking with hash chains
- **Live Operator Console**: Real-time fleet monitoring with alerts, telemetry, and route progress

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
| `ALERT_EMAIL` | Email for temperature excursion alerts | (unset) |

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
- `POST /api/v1/trucks/:truck_id/telemetry` - Create telemetry reading (IoT)
- `GET /api/v1/trucks/:truck_id/telemetry` - List telemetry readings
- `GET /api/v1/trucks/:truck_id/telemetry/latest` - Get latest telemetry
- `GET /api/v1/trucks_by_risk` - Trucks ordered by risk score
- `GET /api/v1/regions` - List regions
- `GET /api/v1/sites` - List sites
- `GET /api/v1/routes` - List routes
- `GET /api/v1/analytics/summary` - Analytics summary
- `GET /api/v1/analytics/regions` - Analytics by region
- `GET /api/v1/analytics/sites` - Analytics by site

### Telemetry API (IoT Ingestion)

The telemetry API accepts GPS and sensor data from IoT devices on trucks.

**Required fields**: At least one of:
- GPS: `latitude` and `longitude`
- Sensor: `temperature_c`, `humidity`, or `speed_kph`

**Optional fields**:
- `recorded_at` - ISO8601 timestamp (defaults to current time)
- `raw_payload` - JSON object for raw device data

```bash
# Create telemetry reading with GPS and temperature
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{
    "telemetry": {
      "latitude": 42.3601,
      "longitude": -71.0589,
      "temperature_c": 5.5,
      "humidity": 45.0,
      "speed_kph": 60.0,
      "recorded_at": "2025-01-01T12:00:00Z"
    }
  }' \
  https://app/api/v1/trucks/1/telemetry

# Get latest telemetry for a truck
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/trucks/1/telemetry/latest
```

### Track & Trace API (Chain of Custody)

The shipment events API provides tamper-evident chain of custody tracking.

**Event types**: `route_started`, `route_completed`, `stop_arrival`, `stop_departure`, `temperature_reading`, `temperature_excursion`, `door_opened`, `door_closed`, `geofence_enter`, `geofence_exit`, `signature_captured`, `delivery_confirmed`, `delivery_refused`, `incident_reported`, `manual_check`

```bash
# Log a shipment event
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{
    "event": {
      "event_type": "stop_arrival",
      "description": "Arrived at Cambridge facility",
      "latitude": 42.3736,
      "longitude": -71.1097,
      "temperature_c": 5.2,
      "recorded_by": "driver@example.com"
    }
  }' \
  https://app/api/v1/trucks/1/shipment_events

# Get chain of custody
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/trucks/1/shipment_events/chain_of_custody

# Verify chain integrity (tamper detection)
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/trucks/1/shipment_events/verify_chain

# Get route history
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/routes/1/history
```

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
│   ├── monitoring.rb         # Temperature readings
│   ├── region.rb             # State/region grouping
│   ├── route.rb              # Delivery routes
│   ├── shipment_event.rb     # Chain of custody events
│   ├── site.rb               # Physical locations
│   ├── telemetry_reading.rb  # IoT GPS/sensor data
│   ├── truck.rb              # Vehicles with temp thresholds
│   └── waypoint.rb           # Route stops
├── services/
│   ├── analytics_service.rb      # Analytics computations
│   ├── monitoring_broadcaster.rb # Real-time updates
│   ├── risk_scorer.rb            # Risk calculation
│   ├── route_optimizer.rb        # Route optimization
│   ├── route_risk_scorer.rb      # Route risk assessment
│   └── telemetry_broadcaster.rb  # Real-time telemetry
└── views/
    ├── analytics/        # Executive dashboard
    ├── regions/
    ├── routes/
    ├── sites/
    └── trucks/
```

## Risk Scoring

### Truck Risk Score

The `RiskScorer` service calculates a 0-100 risk score based on:

| Factor | Weight | Description |
|--------|--------|-------------|
| Excursion Count | 30% | Ratio of out-of-range readings |
| Severity | 25% | Maximum temperature deviation |
| Variance | 15% | Temperature instability (std deviation) |
| Trend | 20% | Temperature moving toward limits |
| Freshness | 10% | Recency of last reading |

Risk levels: `low` (0-30), `medium` (31-60), `high` (61-80), `critical` (81-100)

### Route Risk Assessment

The `RouteRiskScorer` provides AI-like recommendations:

```bash
# Get route risk assessment
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/routes/1/risk_assessment
```

Response includes:
- Overall risk score and level
- Factor breakdown (truck risk, cargo time, pending stops, environmental, historical)
- Action recommendations (PROCEED, MONITOR, EXPEDITE, IMMEDIATE_ACTION)
- Priority stops list

## WebSocket Real-Time Updates

Connect to Action Cable for live updates:

```javascript
// Subscribe to console updates
App.cable.subscriptions.create("ConsoleChannel", {
  received(data) {
    // data.type: 'telemetry', 'alert', or 'shipment_event'
    console.log(data);
  }
});

// Subscribe to specific truck
App.cable.subscriptions.create({ channel: "TruckChannel", truck_id: 1 }, {
  received(data) {
    console.log(data);
  }
});
```

## Security

- HTTP Token authentication for all API endpoints
- Security headers (X-Content-Type-Options, X-Frame-Options, X-XSS-Protection)
- Input validation with range checks on all numeric fields
- Rate limiting support (configure with Redis cache)
- Secure token comparison to prevent timing attacks

## Dynamic Route Optimization

The `DynamicRouteOptimizer` service provides intelligent route selection with scoring and tradeoff analysis.

### Inputs

- **Candidate Routes**: Routes with status 'planned'
- **Constraints**:
  - `max_risk` - Maximum acceptable risk score (0-100)
  - `max_hours` - Maximum transit time in hours
  - `max_cost` - Maximum cost budget
  - `prefer_carrier` - Preferred carrier name
  - `time_window_start/end` - Delivery window
  - `optimize_for` - Optimization mode: 'balanced', 'risk', 'time', or 'cost'

### Scoring Algorithm

Routes are scored on four factors with configurable weights:

| Mode | Risk | Time | Cost | Priority |
|------|------|------|------|----------|
| Balanced | 35% | 30% | 20% | 15% |
| Risk | 60% | 20% | 10% | 10% |
| Time | 20% | 60% | 10% | 10% |
| Cost | 20% | 20% | 50% | 10% |

Temperature sensitivity multipliers adjust risk scoring:
- Critical: 2.0x
- High: 1.5x
- Standard: 1.0x
- Low: 0.5x

### API Endpoints

```bash
# Get recommended route from all planned routes
curl -H "Authorization: Token token=\"your-api-token\"" \
  "https://app/api/v1/routes/recommend?optimize_for=risk&max_risk=70"

# Compare specific routes
curl -H "Authorization: Token token=\"your-api-token\"" \
  "https://app/api/v1/routes/compare?route_ids[]=1&route_ids[]=2&optimize_for=balanced"
```

### Response Structure

```json
{
  "optimization_mode": "balanced",
  "constraints": { "max_risk": 70 },
  "recommended": {
    "route": { "id": 1, "name": "Route A" },
    "scores": { "overall": 78.5, "risk": 85, "time": 70, "cost": 80, "priority": 70 },
    "eligible": true,
    "tradeoffs": []
  },
  "alternatives": [...],
  "ineligible": [...]
}
```

### External AI Integration

The service is structured to allow swapping the internal rules-based engine with an external ML/AI backend. To integrate:

1. Implement an adapter that conforms to the `DynamicRouteOptimizer` interface
2. Configure via `ROUTE_OPTIMIZER_PROVIDER` environment variable
3. External endpoint should accept route data and constraints, return scored recommendations

## Predictive Risk & Early Warning

The `PredictiveRiskEngine` service provides forward-looking risk assessment and early warnings for active routes.

### Features Feeding the Forecast

The forecasting model analyzes these real-time factors:

| Factor | Description | Weight |
|--------|-------------|--------|
| Current Temp Deviation | How far current temperature is from ideal range midpoint | 30% |
| Temperature Variance | Standard deviation of readings over past 6 hours | 20% |
| Truck Risk Score | Historical risk profile of the vehicle | 25% |
| Route Progress | Remaining distance/stops as risk exposure | 10% |
| Time in Transit | Hours elapsed vs. maximum allowed | 15% |
| Delay Factor | Actual vs. expected progress | 40% (on-time) |
| Remaining Stops | Stops left to complete | 20% (on-time) |

### Risk Bands

Routes are classified into risk bands based on combined excursion and delay probability:

| Band | Score Range | Interpretation |
|------|-------------|----------------|
| Low | 0-30 | Normal operations, standard monitoring |
| Medium | 31-60 | Elevated attention needed, prepare contingencies |
| High | 61-100 | Active intervention required |

### Excursion Probability

The excursion probability (0.0-1.0) predicts likelihood of temperature going out of range:

- **< 0.4**: Normal - continue standard monitoring
- **0.4-0.6**: Watch - moderate risk, monitor trends closely
- **0.6-0.8**: Elevated - increase monitoring frequency, prepare contingency
- **≥ 0.8**: Critical - immediate action required (re-ice, reroute to cold storage)

### On-Time Probability

The on-time probability (0.0-1.0) estimates likelihood of completing route within time window:

- **> 0.7**: On track for on-time delivery
- **0.5-0.7**: At risk - monitor progress, consider expediting
- **< 0.5**: Unlikely on-time - notify recipients, expedite if possible

### Early Warning System

Routes with excursion probability ≥ 0.6 trigger early warnings displayed on the console and available via API.

Warning levels:
- **Elevated** (0.6-0.8): Requires increased monitoring
- **Critical** (≥ 0.8): Requires immediate operator intervention

### API Endpoints

```bash
# Get forecast for a specific route
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/routes/1/forecast

# Get all early warnings for in-progress routes
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/routes/early_warnings
```

### Forecast Response

```json
{
  "route_id": 1,
  "excursion_probability": 0.65,
  "ontime_probability": 0.72,
  "risk_band": "medium",
  "risk_band_label": "Medium",
  "factors": {
    "current_temp_deviation": 0.4,
    "temp_variance_factor": 0.2,
    "truck_risk_factor": 0.35,
    "route_progress_factor": 0.25,
    "time_in_transit_factor": 0.45,
    "delay_factor": 0.15,
    "remaining_stops_factor": 0.6,
    "route_risk_factor": 0.3
  },
  "early_warning": true,
  "recommendations": [
    {
      "priority": 2,
      "type": "excursion_risk",
      "action": "MONITOR_CLOSELY",
      "message": "Elevated excursion risk. Increase monitoring frequency and prepare contingency."
    }
  ],
  "forecast_generated_at": "2025-01-15T14:30:00Z"
}
```

### Operator Guidance

1. **Check the Console**: The live console displays early warnings prominently with probability bars
2. **Review Factors**: Examine which factors are driving high risk to understand root cause
3. **Follow Recommendations**: The system provides prioritized action recommendations
4. **Take Action**: For critical warnings, options include:
   - Re-icing at nearest facility
   - Rerouting to cold storage
   - Expediting remaining stops
   - Notifying recipients of potential issues

## Digital Twin & Simulation Mode

The `DigitalTwinSimulator` service enables scenario-based testing and training without affecting production data.

### Available Scenarios

| Scenario | Description | Key Parameters |
|----------|-------------|----------------|
| `temperature_excursion` | Simulates temperature going out of range | `excursion_start_minute`, `excursion_severity` (mild/moderate/severe), `recovery_enabled` |
| `power_failure` | Simulates refrigeration power loss | `failure_start_minute`, `failure_duration_minutes`, `temperature_rise_rate` |
| `route_delay` | Simulates delivery delays | `delay_start_minute`, `delay_duration_minutes`, `delay_cause` |
| `multi_truck_stress` | Multiple trucks with simultaneous issues | `affected_percentage`, `stress_type` (mixed/temperature/power) |
| `weather_event` | External weather affecting cold chain | `weather_type` (heat_wave/cold_snap), `ambient_temp_change` |
| `equipment_degradation` | Gradual efficiency loss over time | `degradation_rate`, `initial_efficiency` |
| `custom` | User-defined parameters | Any custom configuration |

### API Endpoints

```bash
# List available scenarios with default parameters
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/simulations/scenarios

# Create a new simulation
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{
    "scenario_type": "temperature_excursion",
    "name": "Summer Heat Test",
    "duration_minutes": 60,
    "excursion_severity": "severe",
    "truck_ids": [1, 2, 3]
  }' \
  https://app/api/v1/simulations

# Start a simulation
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  "https://app/api/v1/simulations/1/start?speed_multiplier=100"

# Get simulation events
curl -H "Authorization: Token token=\"your-api-token\"" \
  "https://app/api/v1/simulations/1/events?event_type=temperature_reading"

# Replay a completed simulation
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/simulations/1/replay
```

### Simulation Results

After completion, simulations provide:

- **Ticks Processed**: Number of time intervals simulated
- **Events Generated**: Total simulation events recorded
- **Excursions Detected**: Temperature excursion incidents
- **Alerts Triggered**: Alert events generated
- **Trucks/Routes Affected**: IDs of affected entities

### Event Types

Simulations generate these event types:

- `simulation_tick` - Time marker for each simulated minute
- `temperature_reading` - Temperature data point
- `power_change` - Power on/off transitions
- `alert_triggered` - Alert conditions detected
- `excursion_start` / `excursion_end` - Excursion boundaries
- `route_progress` - Route completion progress

### Web Interface

Access `/simulations` for a visual interface to:

1. Create simulations from scenario templates
2. Configure scenario-specific parameters
3. Start and monitor simulation progress
4. View results and event timelines
5. Replay completed simulations with temperature charts

### Use Cases

1. **Operator Training**: Practice responding to excursion alerts
2. **Process Validation**: Test alert thresholds and response procedures
3. **System Testing**: Validate monitoring systems under stress
4. **Compliance Preparation**: Document response capabilities for audits
5. **What-If Analysis**: Explore impact of various failure scenarios

## Warehouse & Cold Storage Integration

The `WarehouseIntegrationService` enables seamless handoffs between trucks and warehouse facilities.

### Data Model

- **Warehouse**: Cold storage facility with temperature ranges and capacity
- **StorageZone**: Temperature-controlled zones within warehouses (frozen, refrigerated, ambient)
- **InventoryItem**: Products tracked with lot numbers, expiration, and temperature requirements
- **WarehouseReading**: Temperature/humidity sensor data from warehouse sensors
- **DockAppointment**: Scheduled and actual truck arrivals/departures

### Warehouse Types

| Type | Description |
|------|-------------|
| `distribution_center` | Full-service distribution hub |
| `cold_storage` | Dedicated temperature-controlled storage |
| `cross_dock` | Minimal storage, rapid transfer facility |
| `regional_hub` | Regional consolidation point |

### Storage Zone Types

| Zone Type | Typical Temp Range | Use Case |
|-----------|-------------------|----------|
| `frozen` | -25°C to -15°C | Frozen biologics, vaccines |
| `refrigerated` | 2°C to 8°C | Standard cold chain pharma |
| `controlled_room` | 15°C to 25°C | Controlled room temperature |
| `ambient` | No control | Non-temperature-sensitive |
| `quarantine` | Varies | Products awaiting QA release |
| `staging` | Varies | Temporary staging area |

### API Endpoints

```bash
# Find nearest cold storage
curl -H "Authorization: Token token=\"your-api-token\"" \
  "https://app/api/v1/warehouses/nearest?latitude=42.36&longitude=-71.06&min_capacity=10"

# Get warehouse status (zones, occupancy, alerts)
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/warehouses/1

# Check in truck at warehouse
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{"truck_id": 1, "dock_number": "D3"}' \
  https://app/api/v1/warehouses/1/check_in

# Check out truck
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{"truck_id": 1}' \
  https://app/api/v1/warehouses/1/check_out

# Get handoff report (temperature continuity)
curl -H "Authorization: Token token=\"your-api-token\"" \
  "https://app/api/v1/warehouses/1/handoff?truck_id=1"

# Record warehouse temperature reading
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{"reading": {"temperature": 5.2, "humidity": 45, "storage_zone_id": 1}}' \
  https://app/api/v1/warehouses/1/record_reading

# Transfer inventory to storage zone
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{
    "truck_id": 1,
    "items": [
      {"product_name": "Vaccine A", "lot_number": "LOT001", "quantity": 10, "temperature_requirements": "refrigerated"}
    ]
  }' \
  https://app/api/v1/warehouses/1/storage_zones/1/transfer
```

### Dock Appointments

Manage truck arrivals and departures:

```bash
# Get today's appointments
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/warehouses/1/appointments

# Create appointment
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{
    "appointment": {
      "truck_id": 1,
      "appointment_type": "inbound",
      "scheduled_at": "2025-01-15T10:00:00Z",
      "dock_number": "D1"
    }
  }' \
  https://app/api/v1/warehouses/1/create_appointment
```

### Handoff Report

The handoff report provides chain-of-custody documentation:

```json
{
  "timestamp": "2025-01-15T14:30:00Z",
  "truck": {
    "id": 1,
    "name": "Truck A",
    "temperature": 5.2,
    "temp_range": "2°C - 8°C"
  },
  "warehouse": {
    "id": 1,
    "name": "Cold Storage A",
    "temperature": 4.8,
    "temp_range": "2°C - 8°C"
  },
  "handoff": {
    "dock_number": "D3",
    "temperature_delta": 0.4,
    "temperature_compatible": true,
    "on_time": true,
    "dwell_time_minutes": 45
  },
  "chain_of_custody": {
    "continuous": true,
    "notes": null
  }
}
```

### Alerts Generated

The system generates alerts for:

- Temperature excursions (zone or warehouse level)
- Capacity warnings (>95% occupancy)
- Expiring inventory (items expiring within 7 days)
- Temperature gaps during handoffs (>3°C difference)

## Chain-of-Custody & Compliance

The `ComplianceService` provides GDP (Good Distribution Practice) compliance verification and audit trail capabilities.

### Compliance Features

- **Shipment Verification**: Automated compliance checks for routes
- **Chain of Custody**: Tamper-evident event chain with hash verification
- **Digital Signatures**: Electronic signatures with role-based capture
- **Audit Logging**: Complete audit trail for all compliance-relevant actions
- **Deviation Reporting**: Structured deviation documentation with CAPA tracking
- **Compliance Records**: Centralized compliance documentation management

### GDP Requirements Checked

| Requirement | ID | Description |
|-------------|-----|-------------|
| Temperature Monitoring | GDP-001 | Continuous temperature monitoring during transport |
| Chain of Custody | GDP-002 | Complete chain of custody documentation |
| Calibration | GDP-003 | Calibrated monitoring equipment |
| Training | GDP-004 | Personnel training documentation |
| Deviation Handling | GDP-005 | Documented deviation handling procedures |

### API Endpoints

```bash
# Verify shipment compliance
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/compliance/verify/1

# Generate full compliance report
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/compliance/report/1

# Verify chain of custody integrity
curl -H "Authorization: Token token=\"your-api-token\"" \
  "https://app/api/v1/compliance/chain/1?route_id=1"

# Report deviation
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{"description": "Temperature excursion", "reporter": "QA Manager", "justification": "Equipment failure"}' \
  https://app/api/v1/compliance/deviation/123

# Get audit trail
curl -H "Authorization: Token token=\"your-api-token\"" \
  "https://app/api/v1/compliance/audit_trail?route_id=1"

# Create signature
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{"signature": {"signer_name": "John Driver", "signer_role": "driver", "signer_email": "john@example.com"}}' \
  "https://app/api/v1/compliance/signatures?route_id=1"

# List compliance records
curl -H "Authorization: Token token=\"your-api-token\"" \
  "https://app/api/v1/compliance/records?type=deviation_report&status=pending"

# Approve compliance record
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{"verified_by": "QA Director"}' \
  https://app/api/v1/compliance/records/1/approve
```

### Compliance Report Structure

```json
{
  "report_id": "uuid",
  "generated_at": "2025-01-15T14:30:00Z",
  "route": { "id": 1, "name": "Route A", "status": "completed" },
  "truck": { "id": 1, "name": "Truck A", "temp_range": "2°C - 8°C" },
  "temperature_log": [
    { "timestamp": "...", "temperature": 5.2, "in_range": true }
  ],
  "chain_of_custody": [
    { "event_type": "route_started", "recorded_by": "driver", "event_hash": "abc123" }
  ],
  "signatures": [
    { "signer_name": "John Driver", "signer_role": "driver", "signature_hash": "def456" }
  ],
  "deviations": [],
  "compliance_verification": {
    "compliance_status": "compliant",
    "findings": [
      { "check": "temperature", "passed": true },
      { "check": "chain_of_custody", "passed": true },
      { "check": "signatures", "passed": true },
      { "check": "time_window", "passed": true }
    ]
  },
  "audit_trail": [...]
}
```

### Signature Roles

| Role | Description |
|------|-------------|
| `driver` | Truck driver |
| `dispatcher` | Dispatch coordinator |
| `warehouse_operator` | Warehouse personnel |
| `quality_manager` | Quality assurance manager |
| `recipient` | Delivery recipient |
| `witness` | Third-party witness |

### Compliance Record Types

| Type | Description |
|------|-------------|
| `gdp_certification` | GDP certification documentation |
| `temperature_validation` | Temperature validation records |
| `calibration_certificate` | Equipment calibration certificates |
| `sop_acknowledgment` | SOP training acknowledgments |
| `training_record` | Personnel training records |
| `deviation_report` | Deviation/incident reports |
| `capa_record` | Corrective/preventive action records |
| `batch_release` | Batch release documentation |
| `shipment_release` | Shipment release authorization |
| `recall_notification` | Product recall notifications |

### Audit Actions Logged

All compliance-relevant actions are automatically logged:

- `create`, `update`, `delete` - Record modifications
- `approve`, `reject` - Compliance record decisions
- `sign`, `verify` - Signature operations
- `temperature_excursion` - Temperature violations
- `chain_break`, `chain_verified` - Chain integrity events
- `compliance_check`, `compliance_violation` - Compliance verifications
- `deviation_reported` - Deviation submissions

## Customer & Partner Portals

The `PortalService` provides external access for customers and partners to track shipments and receive notifications.

### Portal Users

| Role | Description | Typical Permissions |
|------|-------------|---------------------|
| `customer` | Receiving party | view_shipments, view_temperature, receive_alerts |
| `partner` | Logistics partner | view_shipments, view_location, view_analytics |
| `carrier` | Transport carrier | view_shipments, view_location, create_appointments |
| `admin` | Full access | All permissions |

### Access Levels

| Level | Features |
|-------|----------|
| `basic` | Shipment status, origin/destination, progress |
| `tracking` | + Real-time location, temperature, waypoints |
| `full` | + Documents, compliance data, signatures |

### API Endpoints

```bash
# Public tracking (no auth required)
curl https://app/api/v1/portal/track/abc123token

# Create portal user
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "customer@example.com",
      "name": "ACME Corp",
      "role": "customer",
      "organization_name": "ACME Corporation",
      "permissions": ["view_shipments", "view_temperature", "receive_alerts"]
    }
  }' \
  https://app/api/v1/portal/users

# Create shipment share
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{"route_id": 1, "portal_user_id": 1, "access_level": "tracking", "expires_in_hours": 72}' \
  https://app/api/v1/portal/shares

# Get customer dashboard
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/portal/dashboard/1

# Get partner analytics
curl -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/portal/analytics/1
```

### Public Tracking View

The `/api/v1/portal/track/:token` endpoint returns shipment data based on access level:

```json
{
  "shipment": {
    "id": 1,
    "name": "Route A",
    "origin": "Boston",
    "destination": "New York",
    "status": "in_progress",
    "progress": 65,
    "estimated_arrival": "2025-01-15T16:00:00Z"
  },
  "access_level": "tracking",
  "location": {
    "latitude": 41.2565,
    "longitude": -73.1284,
    "speed_kph": 65,
    "updated_at": "2025-01-15T14:30:00Z"
  },
  "temperature": {
    "current": 5.2,
    "min": 2,
    "max": 8,
    "status": "in_range"
  },
  "waypoints": [
    { "position": 1, "site_name": "Boston Hub", "status": "completed" },
    { "position": 2, "site_name": "Hartford", "status": "in_progress" }
  ]
}
```

### Webhooks

Partners can subscribe to real-time event notifications:

```bash
# Create webhook subscription
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  -H "Content-Type: application/json" \
  -d '{
    "webhook": {
      "url": "https://partner.example.com/webhooks/pharma",
      "events": ["shipment.started", "temperature.excursion", "delivery.completed"]
    }
  }' \
  https://app/api/v1/portal/webhooks/1

# Test webhook
curl -X POST \
  -H "Authorization: Token token=\"your-api-token\"" \
  https://app/api/v1/portal/webhooks/1/test
```

### Webhook Events

| Event | Description |
|-------|-------------|
| `shipment.started` | Route has started |
| `shipment.completed` | Route completed |
| `shipment.delayed` | Shipment running behind schedule |
| `temperature.excursion` | Temperature out of range |
| `temperature.warning` | Temperature approaching limits |
| `location.updated` | New GPS position received |
| `delivery.arrived` | Arrived at destination |
| `delivery.completed` | Delivery confirmed |
| `delivery.refused` | Delivery refused |
| `alert.triggered` | System alert generated |

### Webhook Payload

```json
{
  "event": "temperature.excursion",
  "timestamp": "2025-01-15T14:30:00Z",
  "data": {
    "route_id": 1,
    "route_name": "Route A",
    "truck_id": 1,
    "temperature": 12.5,
    "threshold": 8.0
  }
}
```

Webhooks include `X-Webhook-Signature` header for verification using HMAC-SHA256.

### Customer Dashboard

Returns active shipments, alerts, and statistics for a portal user:

- Active and recent shipments
- Temperature and delay alerts
- Delivery statistics (on-time rate, etc.)

### Partner Analytics

Returns detailed analytics for partner organizations:

- Shipment summary (total, in-progress, completed)
- Performance metrics (on-time rate, temperature compliance)
- Average transit times
- Recent activity log
- Webhook status

## External AI Integration

Pluggable AI provider framework for intelligent cold chain analysis.

### Supported Providers

- **OpenAI** (GPT-4, GPT-3.5)
- **Anthropic** (Claude)
- **Azure OpenAI**
- **Custom** (webhook-based integration)
- **Simulation Mode** (for testing without API keys)

### AI Analysis Types

| Type | Description |
|------|-------------|
| `risk_assessment` | Evaluate risk factors for trucks/routes |
| `route_optimization` | AI-powered route improvement suggestions |
| `anomaly_detection` | Detect unusual patterns in telemetry data |
| `temperature_prediction` | Forecast temperature trends |
| `compliance_review` | Automated GDP compliance checking |
| `incident_analysis` | Analyze and summarize incidents |

### API Endpoints

```bash
# Provider Management
GET    /api/v1/ai/providers              # List AI providers
POST   /api/v1/ai/providers              # Create provider
PATCH  /api/v1/ai/providers/:id          # Update provider

# Prompt Templates
GET    /api/v1/ai/prompts                # List prompts
POST   /api/v1/ai/prompts                # Create prompt
PATCH  /api/v1/ai/prompts/:id            # Update prompt

# Analysis Endpoints
POST   /api/v1/ai/analyze                # Generic analysis
POST   /api/v1/ai/assess_risk            # Risk assessment
POST   /api/v1/ai/optimize_route/:id     # Route optimization
POST   /api/v1/ai/detect_anomalies/:id   # Anomaly detection
POST   /api/v1/ai/predict_temperature/:id # Temperature forecast
POST   /api/v1/ai/review_compliance/:id  # Compliance review

# Insights Management
GET    /api/v1/ai/insights               # List insights
GET    /api/v1/ai/insights/:id           # Get insight details
POST   /api/v1/ai/insights/:id/acknowledge
POST   /api/v1/ai/insights/:id/resolve
POST   /api/v1/ai/insights/:id/dismiss

# Feedback & Stats
POST   /api/v1/ai/feedback/:insight_id   # Submit feedback
GET    /api/v1/ai/requests               # Request history
GET    /api/v1/ai/stats                  # Usage statistics
GET    /api/v1/ai/types                  # Available types
```

### Example: Configure AI Provider

```bash
# Create OpenAI provider
curl -X POST http://localhost:3000/api/v1/ai/providers \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "provider": {
      "name": "OpenAI GPT-4",
      "provider_type": "openai",
      "api_key_encrypted": "sk-...",
      "ai_model": "gpt-4",
      "max_tokens": 2000,
      "cost_per_1k_tokens": 0.03
    }
  }'
```

### Example: Run Risk Assessment

```bash
curl -X POST http://localhost:3000/api/v1/ai/assess_risk \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_type": "truck",
    "entity_id": 1
  }'
```

Response:
```json
{
  "request_id": 1,
  "response": {
    "risk_score": 0.65,
    "risk_level": "medium",
    "factors": [
      { "factor": "temperature_stability", "score": 0.78 },
      { "factor": "route_history", "score": 0.62 }
    ],
    "recommendations": [
      "Consider adding additional monitoring points"
    ]
  },
  "insights": [
    {
      "id": 1,
      "insight_type": "risk_prediction",
      "title": "Risk Level: Medium",
      "severity": "medium",
      "confidence_score": 0.65
    }
  ]
}
```

### AI Insights

Generated insights include:
- **Risk Predictions**: Overall risk scores with contributing factors
- **Route Recommendations**: Time/fuel savings and suggested stops
- **Anomaly Alerts**: Detected unusual patterns with severity levels
- **Temperature Forecasts**: Hour-by-hour predictions with excursion risk
- **Compliance Issues**: Automated GDP compliance findings

### Feedback Loop

Submit feedback to improve AI accuracy:

```bash
curl -X POST http://localhost:3000/api/v1/ai/feedback/1 \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "feedback_type": "accurate",
    "rating": 5,
    "comments": "Prediction was very helpful"
  }'
```

### Environment Variables (AI)

| Variable | Description |
|----------|-------------|
| `AI_DEFAULT_PROVIDER` | Default AI provider name |
| `OPENAI_API_KEY` | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `AZURE_OPENAI_ENDPOINT` | Azure OpenAI endpoint URL |
| `AZURE_OPENAI_KEY` | Azure OpenAI API key |

## Performance, Scaling & Reliability

Enterprise-grade infrastructure for high-volume cold chain operations.

### Database Indexes

Optimized indexes for common query patterns:
- Telemetry lookups by truck and time
- Shipment event chain queries
- Route status filtering
- Warehouse reading time series
- Audit log compliance queries

### Caching Layer

`CacheService` provides intelligent caching:

```ruby
# Dashboard caching (5 min TTL)
CacheService.dashboard_summary(region_id: 1) { compute_dashboard }

# Truck status (1 min TTL)
CacheService.truck_status(truck_id) { truck.status_data }

# Route risk (5 min TTL)
CacheService.route_risk(route_id) { calculate_risk }

# Cache invalidation
CacheService.invalidate_truck(truck_id)
CacheService.invalidate_route(route_id)
```

### Rate Limiting

`RateLimiter` protects against abuse:

```ruby
# Check rate limit
RateLimiter.check!(client_id, category: :api_general)  # 100/min
RateLimiter.check!(client_id, category: :api_telemetry)  # 1000/min
RateLimiter.check!(client_id, category: :api_ai)  # 20/min

# Get status
RateLimiter.status(client_id, category: :api_general)
# => { current: 45, limit: 100, remaining: 55, exceeded: false }

# IP-based limiting
RateLimiter.check_ip!(request.remote_ip, category: :api_general)
```

### Batch Processing

High-throughput data ingestion via `BatchProcessor`:

```bash
# Batch telemetry (up to 1000 readings)
POST /api/v1/batch/telemetry/:truck_id
{
  "readings": [
    { "temperature_c": 5.0, "humidity": 50, "recorded_at": "2024-01-15T10:00:00Z" },
    { "temperature_c": 5.2, "humidity": 51, "recorded_at": "2024-01-15T10:01:00Z" }
  ]
}

# Batch monitoring
POST /api/v1/batch/monitoring/:truck_id

# Batch events
POST /api/v1/batch/events/:truck_id

# Batch warehouse readings
POST /api/v1/batch/warehouse_readings/:warehouse_id

# Batch AI analysis
POST /api/v1/batch/ai_analysis
{
  "entity_type": "truck",
  "entity_ids": [1, 2, 3],
  "analysis_type": "risk_assessment"
}

# Data export
GET /api/v1/batch/export?type=telemetry&truck_id=1&format=csv
```

### Health Checks

Comprehensive health monitoring:

```bash
# Quick check (for load balancers)
GET /health
# => {"status":"ok","timestamp":"2024-01-15T10:00:00Z"}

# Full health check
GET /health/full
# => {
#   "status": "healthy",
#   "checks": {
#     "database": {"status":"healthy","latency_ms":2.5},
#     "cache": {"status":"healthy","backend":"ActiveSupport::Cache::MemoryStore"},
#     "disk": {"status":"healthy","usage_percent":45.2},
#     "memory": {"status":"healthy","usage_percent":62.1}
#   }
# }

# Kubernetes probes
GET /health/ready   # Readiness probe
GET /health/live    # Liveness probe

# Metrics endpoint
GET /health/metrics
# => {
#   "database": {"connection_pool":{"size":5,"connections":2}},
#   "entities": {"trucks":25,"routes":150,"active_routes":12}
# }
```

### Data Cleanup

Automated data retention:

```ruby
# Clean old telemetry (keep 90 days)
BatchProcessor.cleanup_old_telemetry(days_to_keep: 90)

# Clean old monitoring data
BatchProcessor.cleanup_old_monitoring(days_to_keep: 90)

# Clean old audit logs (keep 1 year)
BatchProcessor.cleanup_old_audit_logs(days_to_keep: 365)

# Clean old AI requests (keep 30 days)
BatchProcessor.cleanup_old_ai_requests(days_to_keep: 30)
```

### Production Recommendations

1. **Database**: Use PostgreSQL for production with connection pooling (PgBouncer)
2. **Cache**: Redis for distributed caching and rate limiting
3. **Background Jobs**: Sidekiq or GoodJob for async processing
4. **CDN**: CloudFront/Cloudflare for static assets
5. **Monitoring**: DataDog, New Relic, or Prometheus + Grafana
6. **Logging**: Structured JSON logging with ELK stack or CloudWatch

### Environment Variables (Performance)

| Variable | Description | Recommended |
|----------|-------------|-------------|
| `RAILS_MAX_THREADS` | Puma threads per worker | 5 |
| `WEB_CONCURRENCY` | Puma worker count | CPU cores |
| `REDIS_URL` | Redis connection | Required for caching |
| `DATABASE_POOL` | DB connection pool size | threads × workers |
| `RAILS_LOG_LEVEL` | Log verbosity | `info` in production |

## Network Planning & Capacity

The `NetworkPlanner` service provides demand vs. capacity analysis and planning for the pharmaceutical logistics network.

### Key Concepts

- **Node Capacity**: Storage and throughput capacity at warehouses, depots, and sites
- **Lane Capacity**: Transport capacity between nodes (trucks, air, rail, sea)
- **Demand Forecasts**: Projected shipment volumes by product, region, and time period
- **Capacity Plans**: Generated plans with recommendations for capacity management

### Inputs

| Input | Description |
|-------|-------------|
| Demand Forecasts | Product-level forecasts by region/site/date |
| Lane Capacities | Active transport lanes with daily shipment capacity |
| Node Capacities | Storage capacity (pallets) and throughput rates |

### Outputs

| Output | Description |
|--------|-------------|
| Demand vs Capacity Analysis | Total demand, capacity, gap, and utilization by region |
| Lane Suggestions | Recommended daily shipments per lane with utilization |
| Capacity Upgrades | Nodes and lanes requiring capacity increases |
| Additional Carriers | Lanes needing additional carrier support |
| Capacity Plans | Generated plans with item-level analysis and recommendations |

### API Endpoints

```bash
# Get demand vs capacity analysis
GET /network_planning/demand_analysis
GET /network_planning/demand_analysis?region_id=1&start_date=2025-01-01&end_date=2025-01-31

# Get lane shipment suggestions
GET /network_planning/lane_suggestions
GET /network_planning/lane_suggestions?start_date=2025-01-01&end_date=2025-01-07

# Get capacity upgrade recommendations
GET /network_planning/capacity_upgrades

# Get lanes needing additional carriers
GET /network_planning/additional_carriers

# Get regional capacity summary
GET /network_planning/regional_summary

# Generate new capacity plan
POST /network_planning
{
  "name": "Q1 2025 Capacity Plan",
  "start_date": "2025-01-01",
  "end_date": "2025-03-31"
}

# Approve/reject capacity plan
POST /network_planning/:id/approve
POST /network_planning/:id/reject
```

### Web Interface

Access `/network_planning` for a visual dashboard showing:

- Overall demand vs capacity metrics
- Regional capacity summary table
- Required capacity upgrades with priority
- Lane-by-lane utilization and recommendations
- Recent capacity plans with approval workflow

### Capacity Plan Items

Generated plans analyze three item types:

| Item Type | Analysis |
|-----------|----------|
| `lane` | Demand vs lane capacity, utilization, gap |
| `node` | Storage utilization, throughput analysis |
| `region` | Aggregate regional demand |

### Recommendations

The planner generates these recommendations:

| Recommendation | Trigger |
|----------------|---------|
| `no_action` | Demand ≤ 80% of capacity |
| `optimize_routing` | Demand 80-100% of capacity |
| `add_carrier` | Demand 100-120% of capacity |
| `increase_capacity` | Demand > 120% of capacity |

### Priority Levels

| Priority | Criteria |
|----------|----------|
| `critical` | Utilization > 100% |
| `high` | Gap > 0 and utilization > 90% |
| `medium` | Gap > 0 and utilization > 80% |
| `low` | Normal operations |

## Future Enhancements

Potential additional integrations:

1. **Computer Vision**: Analyze loading dock images for cargo verification
2. **Voice Alerts**: Natural language alert generation
3. **Automated Reporting**: AI-generated compliance reports
4. **Fleet Scheduling**: ML-optimized delivery scheduling

## License

Proprietary - All rights reserved.
