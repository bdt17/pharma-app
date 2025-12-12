class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Telemetry readings - high volume table
    add_index :telemetry_readings, [:truck_id, :recorded_at], name: 'idx_telemetry_truck_time', if_not_exists: true
    add_index :telemetry_readings, :recorded_at, name: 'idx_telemetry_recorded_at', if_not_exists: true
    
    # Monitorings - frequently queried
    add_index :monitorings, [:truck_id, :recorded_at], name: 'idx_monitoring_truck_time', if_not_exists: true
    add_index :monitorings, :recorded_at, name: 'idx_monitoring_recorded_at', if_not_exists: true
    
    # Shipment events - chain of custody queries
    add_index :shipment_events, [:truck_id, :recorded_at], name: 'idx_events_truck_time', if_not_exists: true
    add_index :shipment_events, [:route_id, :recorded_at], name: 'idx_events_route_time', if_not_exists: true
    add_index :shipment_events, :event_type, name: 'idx_events_type', if_not_exists: true
    
    # Routes - status and truck lookups
    add_index :routes, [:status, :started_at], name: 'idx_routes_status_started', if_not_exists: true
    add_index :routes, [:truck_id, :status], name: 'idx_routes_truck_status', if_not_exists: true
    
    # Trucks - site and status
    add_index :trucks, [:site_id, :status], name: 'idx_trucks_site_status', if_not_exists: true
    
    # Warehouse readings - time series
    add_index :warehouse_readings, [:warehouse_id, :recorded_at], name: 'idx_warehouse_readings_time', if_not_exists: true
    add_index :warehouse_readings, [:storage_zone_id, :recorded_at], name: 'idx_zone_readings_time', if_not_exists: true
    
    # Inventory items - lookups
    add_index :inventory_items, [:storage_zone_id, :status], name: 'idx_inventory_zone_status', if_not_exists: true
    add_index :inventory_items, :lot_number, name: 'idx_inventory_lot', if_not_exists: true
    
    # Audit logs - compliance queries
    add_index :audit_logs, [:auditable_type, :auditable_id, :created_at], name: 'idx_audit_entity_time', if_not_exists: true
    add_index :audit_logs, [:action, :created_at], name: 'idx_audit_action_time', if_not_exists: true
    
    # AI requests - analytics
    add_index :ai_requests, [:created_at, :status], name: 'idx_ai_requests_time_status', if_not_exists: true
    
    # Simulation events - replay (uses timestamp column)
    add_index :simulation_events, [:simulation_id, :timestamp], name: 'idx_sim_events_time', if_not_exists: true
  end
end
