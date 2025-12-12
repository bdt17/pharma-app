# PharmaTransport API Reference

## Authentication

All API endpoints (except health checks and public tracking) require token authentication.

```bash
curl -H "Authorization: Bearer YOUR_API_TOKEN" https://api.example.com/api/v1/trucks
```

Set `PHARMA_API_TOKEN` environment variable to configure the token.

---

## Core Resources

### Trucks

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/trucks` | List all trucks |
| GET | `/api/v1/trucks/:id` | Get truck details |
| POST | `/api/v1/trucks` | Create truck |
| PATCH | `/api/v1/trucks/:id` | Update truck |
| DELETE | `/api/v1/trucks/:id` | Delete truck |
| GET | `/api/v1/trucks_by_risk` | List trucks sorted by risk score |

### Routes

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/routes` | List all routes |
| GET | `/api/v1/routes/:id` | Get route details |
| POST | `/api/v1/routes` | Create route |
| POST | `/api/v1/routes/:id/optimize` | Optimize route |
| POST | `/api/v1/routes/:id/reorder_by_risk` | Reorder by risk |
| GET | `/api/v1/routes/:id/suggestions` | Get route suggestions |
| GET | `/api/v1/routes/:id/risk_assessment` | Get risk assessment |
| GET | `/api/v1/routes/:id/forecast` | Get route forecast |
| GET | `/api/v1/routes/recommend` | Get route recommendations |
| GET | `/api/v1/routes/compare` | Compare routes |
| GET | `/api/v1/routes/early_warnings` | Get early warnings |

### Regions & Sites

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/regions` | List regions |
| GET | `/api/v1/regions/:id` | Get region details |
| GET | `/api/v1/sites` | List sites |
| GET | `/api/v1/sites/:id` | Get site details |

---

## Telemetry & Monitoring

### Telemetry Readings

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/trucks/:truck_id/telemetry` | List readings |
| POST | `/api/v1/trucks/:truck_id/telemetry` | Create reading |
| GET | `/api/v1/trucks/:truck_id/telemetry/latest` | Get latest reading |

**Create Reading Request:**
```json
{
  "telemetry_reading": {
    "temperature_c": 5.2,
    "humidity": 55,
    "latitude": 40.7128,
    "longitude": -74.0060,
    "speed_kph": 65,
    "recorded_at": "2024-01-15T10:30:00Z"
  }
}
```

### Monitoring Data

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/trucks/:truck_id/monitorings` | Create monitoring record |

**Request:**
```json
{
  "monitoring": {
    "temperature": 5.0,
    "power_status": "on",
    "recorded_at": "2024-01-15T10:30:00Z"
  }
}
```

---

## Shipment Events & Chain of Custody

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/trucks/:truck_id/shipment_events` | List events |
| POST | `/api/v1/trucks/:truck_id/shipment_events` | Create event |
| GET | `/api/v1/trucks/:truck_id/shipment_events/chain_of_custody` | Get chain |
| GET | `/api/v1/trucks/:truck_id/shipment_events/verify_chain` | Verify chain integrity |
| GET | `/api/v1/routes/:id/history` | Get route event history |

**Create Event Request:**
```json
{
  "shipment_event": {
    "event_type": "pickup",
    "description": "Cargo picked up from warehouse",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "temperature_c": 5.0,
    "recorded_by": "driver@example.com",
    "route_id": 1
  }
}
```

**Event Types:** `pickup`, `delivery`, `departure`, `arrival`, `inspection`, `temperature_check`, `delay`, `incident`, `handoff`, `customs_clearance`

---

## Simulations (Digital Twin)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/simulations` | List simulations |
| GET | `/api/v1/simulations/:id` | Get simulation details |
| POST | `/api/v1/simulations` | Create simulation |
| POST | `/api/v1/simulations/:id/start` | Start simulation |
| POST | `/api/v1/simulations/:id/pause` | Pause simulation |
| GET | `/api/v1/simulations/:id/replay` | Replay simulation |
| GET | `/api/v1/simulations/:id/events` | Get simulation events |
| GET | `/api/v1/simulations/scenarios` | List available scenarios |

**Create Simulation Request:**
```json
{
  "simulation": {
    "name": "Temperature Excursion Test",
    "scenario_type": "temperature_excursion",
    "truck_id": 1,
    "route_id": 1,
    "duration_hours": 8,
    "parameters": {
      "excursion_magnitude": 5,
      "recovery_time_minutes": 30
    }
  }
}
```

**Scenario Types:** `temperature_excursion`, `power_failure`, `route_delay`, `traffic_congestion`, `weather_impact`, `equipment_malfunction`, `normal_operation`

---

## Warehouses & Storage

### Warehouses

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/warehouses` | List warehouses |
| GET | `/api/v1/warehouses/:id` | Get warehouse details |
| POST | `/api/v1/warehouses` | Create warehouse |
| POST | `/api/v1/warehouses/:id/check_in` | Check in truck |
| POST | `/api/v1/warehouses/:id/check_out` | Check out truck |
| GET | `/api/v1/warehouses/:id/handoff` | Get handoff report |
| GET | `/api/v1/warehouses/:id/readings` | Get readings |
| POST | `/api/v1/warehouses/:id/record_reading` | Record reading |
| GET | `/api/v1/warehouses/:id/appointments` | List appointments |
| POST | `/api/v1/warehouses/:id/create_appointment` | Create appointment |
| GET | `/api/v1/warehouses/nearest` | Find nearest warehouse |

### Storage Zones

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/warehouses/:warehouse_id/storage_zones` | List zones |
| GET | `/api/v1/warehouses/:warehouse_id/storage_zones/:id` | Get zone |
| POST | `/api/v1/warehouses/:warehouse_id/storage_zones` | Create zone |
| PATCH | `/api/v1/warehouses/:warehouse_id/storage_zones/:id` | Update zone |
| GET | `/api/v1/warehouses/:warehouse_id/storage_zones/:id/inventory` | Get inventory |
| POST | `/api/v1/warehouses/:warehouse_id/storage_zones/:id/transfer` | Transfer inventory |

---

## Compliance

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/compliance/verify/:route_id` | Verify shipment compliance |
| GET | `/api/v1/compliance/report/:route_id` | Generate compliance report |
| GET | `/api/v1/compliance/chain/:truck_id` | Verify chain of custody |
| POST | `/api/v1/compliance/deviation/:event_id` | Report deviation |
| GET | `/api/v1/compliance/audit_trail` | Get audit trail |
| GET | `/api/v1/compliance/records` | List compliance records |
| GET | `/api/v1/compliance/records/:id` | Get record details |
| POST | `/api/v1/compliance/records/:id/approve` | Approve record |
| POST | `/api/v1/compliance/records/:id/reject` | Reject record |
| POST | `/api/v1/compliance/records/:id/evidence` | Add evidence |
| GET | `/api/v1/compliance/signatures` | List signatures |
| POST | `/api/v1/compliance/signatures` | Create signature |
| GET | `/api/v1/compliance/gdp_requirements` | Get GDP requirements |

---

## Customer & Partner Portal

### Public Tracking (No Auth)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/portal/track/:token` | Track shipment by token |

### Portal Users

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/portal/users` | List portal users |
| GET | `/api/v1/portal/users/:id` | Get user details |
| POST | `/api/v1/portal/users` | Create user |
| PATCH | `/api/v1/portal/users/:id` | Update user |
| POST | `/api/v1/portal/users/:id/regenerate_key` | Regenerate API key |

### Shipment Sharing

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/portal/shares` | List shares |
| POST | `/api/v1/portal/shares` | Create share |
| DELETE | `/api/v1/portal/shares/:id` | Revoke share |

### Dashboards

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/portal/dashboard/:user_id` | Customer dashboard |
| GET | `/api/v1/portal/analytics/:user_id` | Partner analytics |

### Webhooks

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/portal/webhooks/:user_id` | List webhooks |
| POST | `/api/v1/portal/webhooks/:user_id` | Create webhook |
| PATCH | `/api/v1/portal/webhooks/:id/update` | Update webhook |
| DELETE | `/api/v1/portal/webhooks/:id` | Delete webhook |
| POST | `/api/v1/portal/webhooks/:id/test` | Test webhook |
| GET | `/api/v1/portal/webhook_events` | List available events |

---

## AI Integration

### Providers & Prompts

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/ai/providers` | List AI providers |
| POST | `/api/v1/ai/providers` | Create provider |
| PATCH | `/api/v1/ai/providers/:id` | Update provider |
| GET | `/api/v1/ai/prompts` | List prompts |
| POST | `/api/v1/ai/prompts` | Create prompt |
| PATCH | `/api/v1/ai/prompts/:id` | Update prompt |

### Analysis

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/ai/analyze` | Generic analysis |
| POST | `/api/v1/ai/assess_risk` | Risk assessment |
| POST | `/api/v1/ai/optimize_route/:route_id` | Optimize route |
| POST | `/api/v1/ai/detect_anomalies/:truck_id` | Detect anomalies |
| POST | `/api/v1/ai/predict_temperature/:truck_id` | Predict temperature |
| POST | `/api/v1/ai/review_compliance/:route_id` | Review compliance |

### Insights

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/ai/insights` | List insights |
| GET | `/api/v1/ai/insights/:id` | Get insight details |
| POST | `/api/v1/ai/insights/:id/acknowledge` | Acknowledge insight |
| POST | `/api/v1/ai/insights/:id/resolve` | Resolve insight |
| POST | `/api/v1/ai/insights/:id/dismiss` | Dismiss insight |
| POST | `/api/v1/ai/feedback/:insight_id` | Submit feedback |

### Stats & Types

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/ai/requests` | List AI requests |
| GET | `/api/v1/ai/stats` | Usage statistics |
| GET | `/api/v1/ai/types` | Available types |

---

## Batch Processing

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/batch/telemetry/:truck_id` | Batch telemetry (max 1000) |
| POST | `/api/v1/batch/monitoring/:truck_id` | Batch monitoring (max 1000) |
| POST | `/api/v1/batch/events/:truck_id` | Batch events (max 100) |
| POST | `/api/v1/batch/warehouse_readings/:warehouse_id` | Batch readings (max 1000) |
| POST | `/api/v1/batch/ai_analysis` | Batch AI analysis (max 50) |
| GET | `/api/v1/batch/export` | Export data |

---

## Health Checks (No Auth)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Quick health check |
| GET | `/health/full` | Full health check |
| GET | `/health/ready` | Readiness probe |
| GET | `/health/live` | Liveness probe |
| GET | `/health/metrics` | System metrics |

---

## Analytics

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/analytics/summary` | Summary statistics |
| GET | `/api/v1/analytics/regions` | Region analytics |
| GET | `/api/v1/analytics/sites` | Site analytics |
| GET | `/api/v1/analytics/routes` | Route analytics |

---

## WebSocket (Action Cable)

Connect to `/cable` for real-time updates.

### Channels

- `AlertsChannel` - Temperature excursions, incidents
- `TelemetryChannel` - Live telemetry updates
- `ConsoleChannel` - Operator console updates

### Example (JavaScript)

```javascript
import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer("wss://api.example.com/cable")

consumer.subscriptions.create("AlertsChannel", {
  received(data) {
    console.log("Alert:", data)
  }
})
```

---

## Error Responses

### Standard Error Format

```json
{
  "error": "Error message",
  "details": ["Additional detail 1", "Additional detail 2"]
}
```

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 207 | Multi-Status (partial success) |
| 400 | Bad Request |
| 401 | Unauthorized |
| 404 | Not Found |
| 422 | Unprocessable Entity |
| 429 | Too Many Requests |
| 500 | Internal Server Error |

### Rate Limit Response

```json
{
  "error": "Rate limit exceeded",
  "retry_after": 45
}
```
