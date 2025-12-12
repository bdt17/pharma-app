# Changelog

All notable changes to PharmaTransport are documented in this file.

## [Unreleased] - Advanced Intelligence & Enterprise Scale

### Added

#### STEP M - Dynamic Route Optimization
- `RouteOptimizationService` for intelligent route planning
- Risk-based waypoint reordering
- Route suggestions based on historical data
- Multi-factor scoring (weather, traffic, historical excursions)

#### STEP N - Predictive Risk & Excursion Forecasting
- `PredictiveRiskEngine` for AI-like risk assessment
- Excursion probability forecasting
- Early warning system for high-risk routes
- Automated recommendations engine

#### STEP O - Digital Twin & Simulation Mode
- `Simulation` and `SimulationEvent` models
- `DigitalTwinSimulator` service
- 7 scenario types (temperature_excursion, power_failure, route_delay, etc.)
- Web UI for simulation management
- Timeline replay with Chart.js visualization

#### STEP P - Warehouse & Cold-Storage Integration
- `Warehouse`, `StorageZone`, `InventoryItem` models
- `WarehouseReading`, `DockAppointment` models
- `WarehouseIntegrationService` for facility management
- Check-in/check-out workflows
- Inventory transfer tracking
- Dock appointment scheduling

#### STEP Q - Chain-of-Custody & Compliance Hardening
- `AuditLog`, `ComplianceRecord`, `Signature` models
- `ComplianceService` for GDP compliance
- Tamper-evident hash chain verification
- Digital signature capture with roles
- Deviation reporting and justification
- Audit trail export (JSON/CSV)
- PDF report generation support

#### STEP R - Customer & Partner Portals
- `PortalUser`, `ShipmentShare`, `WebhookSubscription` models
- `PortalService` for portal functionality
- Public shipment tracking (token-based, no auth)
- Tiered access levels (basic, tracking, full)
- Webhook subscriptions with HMAC-SHA256 signing
- Customer dashboard with stats
- Partner analytics with performance metrics

#### STEP S - External AI Integration
- `AiProvider`, `AiPrompt`, `AiRequest`, `AiInsight`, `AiFeedback` models
- `AiIntegrationService` for AI orchestration
- Multi-provider support (OpenAI, Anthropic, Azure, Custom)
- Simulation mode for testing without API keys
- Risk assessment, route optimization, anomaly detection
- Temperature prediction, compliance review
- Feedback loop for model improvement
- Usage statistics and cost tracking

#### STEP T - Performance, Scaling & Reliability
- 18 strategic database indexes for high-volume tables
- `CacheService` with intelligent TTLs
- `RateLimiter` with multiple algorithms (fixed window, sliding window, token bucket)
- `BatchProcessor` for high-throughput ingestion (up to 1000/batch)
- `HealthCheckService` with comprehensive checks
- Health endpoints for Kubernetes (ready, live)
- Batch API endpoints for telemetry, monitoring, events
- Data cleanup jobs for retention management
- Data export functionality (JSON, CSV)

#### STEP U - Documentation & Readiness
- Complete API Reference documentation
- System Architecture documentation
- Deployment Guide (Heroku, Docker, Kubernetes)
- Production Readiness Checklist
- This Changelog

### Database Migrations

| Migration | Description |
|-----------|-------------|
| `create_simulations` | Digital twin simulation storage |
| `create_simulation_events` | Simulation event timeline |
| `create_warehouses` | Cold storage facilities |
| `create_storage_zones` | Temperature-controlled zones |
| `create_inventory_items` | Product inventory tracking |
| `create_warehouse_readings` | Facility temperature sensors |
| `create_dock_appointments` | Truck scheduling |
| `create_audit_logs` | Compliance audit trail |
| `create_compliance_records` | GDP compliance records |
| `create_signatures` | Digital signatures |
| `add_compliance_fields_to_shipment_events` | Event compliance tracking |
| `create_portal_users` | External user accounts |
| `create_shipment_shares` | Public tracking tokens |
| `create_webhook_subscriptions` | Event webhooks |
| `create_ai_integration_tables` | AI provider/request/insight storage |
| `add_performance_indexes` | Query optimization indexes |

### API Endpoints Added

- `/api/v1/simulations/*` - Digital twin management
- `/api/v1/warehouses/*` - Warehouse operations
- `/api/v1/warehouses/:id/storage_zones/*` - Zone management
- `/api/v1/compliance/*` - Compliance verification
- `/api/v1/portal/*` - Customer/partner portal
- `/api/v1/ai/*` - AI integration
- `/api/v1/batch/*` - Batch processing
- `/health/*` - Health checks

### Test Coverage

- 114 tests total
- 279 assertions
- 0 failures, 0 errors

### Dependencies

No new gem dependencies required. All features use Rails built-in functionality.

---

## [1.0.0] - Initial Release

### Core Features
- Multi-state organization (Regions → Sites → Trucks)
- Temperature and power monitoring
- Risk scoring algorithm
- Route planning with waypoints
- Analytics dashboard
- Email alerts for excursions

### IoT Features
- Telemetry ingestion API
- Real-time WebSocket updates
- Chain of custody tracking
- Live operator console

---

## Version Numbering

PharmaTransport follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality (backward compatible)
- **PATCH**: Bug fixes (backward compatible)
