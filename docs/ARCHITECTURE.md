# PharmaTransport Architecture

## System Overview

PharmaTransport is an enterprise-grade cold chain monitoring platform for pharmaceutical logistics. It provides real-time temperature monitoring, compliance tracking, and AI-powered analytics.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PharmaTransport                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Web UI     │  │   REST API   │  │  WebSocket   │  │   Webhooks   │    │
│  │  (Rails)     │  │   (v1)       │  │ (ActionCable)│  │  (Outbound)  │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │                 │                 │                 │             │
│  ┌──────┴─────────────────┴─────────────────┴─────────────────┴───────┐    │
│  │                        Application Layer                           │    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  │    │
│  │  │   Routes    │ │  Telemetry  │ │ Compliance  │ │     AI      │  │    │
│  │  │  Service    │ │  Service    │ │  Service    │ │  Service    │  │    │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘  │    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  │    │
│  │  │  Warehouse  │ │   Portal    │ │ Simulation  │ │   Batch     │  │    │
│  │  │  Service    │ │  Service    │ │  Service    │ │  Processor  │  │    │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘  │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                        Data Layer                                   │    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  │    │
│  │  │ PostgreSQL  │ │    Redis    │ │    Cache    │ │  External   │  │    │
│  │  │  (Primary)  │ │ (Pub/Sub)   │ │  Service    │ │  AI APIs    │  │    │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘  │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Domain Model

### Core Entities

```
Region (1) ──────────── (*) Site
                              │
                              │ (1)
                              ▼
                           (*) Truck ──────────── (*) TelemetryReading
                              │                        │
                              │ (1)                    │
                              ▼                        │
                           (*) Route ─────────────────┘
                              │
                              │ (*)
                              ▼
                        RouteWaypoint
                              │
                              │ (*)
                              ▼
                        ShipmentEvent ──────────── (*) Signature
                              │
                              │ (*)
                              ▼
                          AuditLog
```

### Warehouse Domain

```
Warehouse (1) ──────── (*) StorageZone
    │                        │
    │ (*)                    │ (*)
    ▼                        ▼
DockAppointment        InventoryItem
    │                        │
    │ (*)                    │
    ▼                        │
WarehouseReading ◄───────────┘
```

### Portal Domain

```
PortalUser (1) ──────── (*) ShipmentShare
    │                        │
    │ (*)                    │ (*)
    ▼                        ▼
WebhookSubscription         Route
```

### AI Domain

```
AiProvider (1) ──────── (*) AiRequest
                              │
                              │ (*)
                              ▼
AiPrompt (1) ────────── (*) AiInsight
                              │
                              │ (*)
                              ▼
                         AiFeedback
```

## Service Layer

### RouteOptimizationService

Handles dynamic route planning and optimization.

```ruby
RouteOptimizationService.optimize(route)
RouteOptimizationService.reorder_by_risk(route)
RouteOptimizationService.suggest_improvements(route)
```

### PredictiveRiskEngine

AI-powered risk assessment and forecasting.

```ruby
PredictiveRiskEngine.assess_truck(truck)
PredictiveRiskEngine.forecast_route(route, hours_ahead: 8)
PredictiveRiskEngine.early_warnings
PredictiveRiskEngine.recommendations
```

### DigitalTwinSimulator

Simulation engine for testing scenarios.

```ruby
DigitalTwinSimulator.create_simulation(params)
DigitalTwinSimulator.run(simulation_id)
DigitalTwinSimulator.replay(simulation_id)
```

### WarehouseIntegrationService

Cold storage facility management.

```ruby
WarehouseIntegrationService.find_nearest_cold_storage(lat, lng, capacity, temp_range)
WarehouseIntegrationService.check_in_truck(truck, warehouse)
WarehouseIntegrationService.check_out_truck(truck, warehouse)
WarehouseIntegrationService.handoff_report(truck, warehouse)
```

### ComplianceService

GDP compliance verification and reporting.

```ruby
ComplianceService.verify_shipment_compliance(route)
ComplianceService.generate_compliance_report(route)
ComplianceService.verify_chain_of_custody(truck, route)
ComplianceService.create_deviation_report(event, description, reporter, justification)
```

### PortalService

Customer and partner portal functionality.

```ruby
PortalService.create_share(route, portal_user, access_level, expires_in)
PortalService.get_shipment_view(share_token)
PortalService.customer_dashboard(portal_user)
PortalService.partner_analytics(portal_user)
PortalService.trigger_webhooks(event, payload)
```

### AiIntegrationService

External AI provider integration.

```ruby
AiIntegrationService.assess_risk(entity)
AiIntegrationService.optimize_route(route)
AiIntegrationService.detect_anomalies(truck)
AiIntegrationService.predict_temperature(truck, hours_ahead: 4)
AiIntegrationService.review_compliance(route)
```

### Performance Services

```ruby
# Caching
CacheService.dashboard_summary { compute_data }
CacheService.invalidate_truck(truck_id)

# Rate Limiting
RateLimiter.check!(identifier, category: :api_telemetry)

# Batch Processing
BatchProcessor.process_telemetry_batch(truck_id, readings)
BatchProcessor.cleanup_old_telemetry(days_to_keep: 90)

# Health Checks
HealthCheckService.full_check
HealthCheckService.readiness_check
```

## Data Flow

### Telemetry Ingestion

```
IoT Device → POST /api/v1/trucks/:id/telemetry
                        │
                        ▼
              TelemetryController
                        │
                        ▼
              TelemetryReading.create!
                        │
                        ├──────────────────┐
                        │                  │
                        ▼                  ▼
              ActionCable.broadcast   Check Temperature
              (telemetry_channel)     Out of Range?
                                           │
                                           ▼ (if yes)
                                      AlertsMailer
                                      ActionCable.broadcast
                                      (alerts_channel)
```

### Compliance Verification

```
GET /api/v1/compliance/verify/:route_id
                │
                ▼
      ComplianceController
                │
                ▼
      ComplianceService.verify_shipment_compliance
                │
                ├── Check temperature history
                ├── Verify chain of custody
                ├── Validate signatures
                └── Check time compliance
                │
                ▼
         Generate Report
                │
                ▼
         Return JSON/PDF
```

### AI Analysis Flow

```
POST /api/v1/ai/assess_risk
         │
         ▼
   AiController
         │
         ▼
   AiIntegrationService.assess_risk
         │
         ├── Get default provider
         ├── Get prompt template
         ├── Build context
         │
         ▼
   call_provider (OpenAI/Anthropic/etc)
         │
         ├── If API key present: Real API call
         └── If no API key: Simulation mode
         │
         ▼
   Create AiRequest (logging)
         │
         ▼
   Create AiInsight (if actionable)
         │
         ▼
   Return result with insights
```

## Security Model

### Authentication

```
Request → Authorization Header
              │
              ▼
        Api::BaseController
              │
              ▼
        authenticate_api_token!
              │
              ├── Valid token → Continue
              └── Invalid → 401 Unauthorized
```

### Rate Limiting

```
Request → IP Address / API Key
              │
              ▼
         RateLimiter
              │
              ├── Under limit → Continue
              └── Over limit → 429 Too Many Requests
```

### Chain of Custody Integrity

```
ShipmentEvent → calculate_hash(previous_event_hash + event_data)
                    │
                    ▼
              Store hash + previous_hash
                    │
                    ▼
         Verification: recalculate and compare
```

## Technology Stack

| Layer | Technology |
|-------|------------|
| Framework | Ruby on Rails 8.1 |
| Database | PostgreSQL (production), SQLite (development) |
| Cache | Redis / Memory Store |
| Real-time | Action Cable (WebSocket) |
| Background Jobs | Rails Async / Sidekiq |
| AI Integration | OpenAI, Anthropic, Azure OpenAI |
| Testing | Minitest |
| API Format | JSON |

## File Structure

```
app/
├── controllers/
│   ├── api/
│   │   ├── base_controller.rb
│   │   └── v1/
│   │       ├── trucks_controller.rb
│   │       ├── telemetry_controller.rb
│   │       ├── routes_controller.rb
│   │       ├── simulations_controller.rb
│   │       ├── warehouses_controller.rb
│   │       ├── compliance_controller.rb
│   │       ├── portal_controller.rb
│   │       ├── ai_controller.rb
│   │       ├── batch_controller.rb
│   │       └── health_controller.rb
│   ├── dashboard_controller.rb
│   ├── console_controller.rb
│   └── analytics_controller.rb
├── models/
│   ├── truck.rb
│   ├── route.rb
│   ├── telemetry_reading.rb
│   ├── shipment_event.rb
│   ├── simulation.rb
│   ├── warehouse.rb
│   ├── portal_user.rb
│   ├── ai_provider.rb
│   └── ...
├── services/
│   ├── route_optimization_service.rb
│   ├── predictive_risk_engine.rb
│   ├── digital_twin_simulator.rb
│   ├── warehouse_integration_service.rb
│   ├── compliance_service.rb
│   ├── portal_service.rb
│   ├── ai_integration_service.rb
│   ├── cache_service.rb
│   ├── rate_limiter.rb
│   ├── batch_processor.rb
│   └── health_check_service.rb
├── channels/
│   ├── alerts_channel.rb
│   └── telemetry_channel.rb
└── views/
    ├── dashboard/
    ├── console/
    ├── analytics/
    └── simulations/
```

## Performance Characteristics

### Expected Throughput

| Operation | Target | Notes |
|-----------|--------|-------|
| API Response | < 200ms | p95 |
| Telemetry Ingestion | 1000/min/truck | Batch supported |
| WebSocket Broadcast | < 100ms | Action Cable |
| AI Analysis | < 30s | Depends on provider |
| Database Query | < 50ms | With indexes |

### Scalability

- Horizontal: Add web workers behind load balancer
- Vertical: Increase resources per instance
- Database: Read replicas for analytics
- Cache: Redis Cluster for HA
