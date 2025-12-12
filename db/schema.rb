# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_12_040326) do
  create_table "ai_feedbacks", force: :cascade do |t|
    t.integer "ai_insight_id"
    t.text "comments"
    t.datetime "created_at", null: false
    t.string "feedback_type", null: false
    t.integer "rating"
    t.string "submitted_by"
    t.datetime "updated_at", null: false
    t.boolean "used_for_training", default: false
    t.index ["ai_insight_id"], name: "index_ai_feedbacks_on_ai_insight_id"
  end

  create_table "ai_insights", force: :cascade do |t|
    t.datetime "acknowledged_at"
    t.string "acknowledged_by"
    t.integer "ai_request_id"
    t.decimal "confidence_score", precision: 5, scale: 4
    t.datetime "created_at", null: false
    t.text "details"
    t.string "insight_type", null: false
    t.bigint "insightable_id"
    t.string "insightable_type"
    t.string "severity"
    t.string "status", default: "active"
    t.text "summary"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["ai_request_id"], name: "index_ai_insights_on_ai_request_id"
    t.index ["insight_type"], name: "index_ai_insights_on_insight_type"
    t.index ["insightable_type", "insightable_id"], name: "index_ai_insights_on_insightable_type_and_insightable_id"
    t.index ["severity"], name: "index_ai_insights_on_severity"
    t.index ["status"], name: "index_ai_insights_on_status"
  end

  create_table "ai_prompts", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "prompt_type", null: false
    t.text "system_prompt"
    t.datetime "updated_at", null: false
    t.text "user_prompt_template"
    t.text "variables"
    t.string "version"
    t.index ["prompt_type", "active"], name: "index_ai_prompts_on_prompt_type_and_active"
    t.index ["prompt_type"], name: "index_ai_prompts_on_prompt_type"
  end

  create_table "ai_providers", force: :cascade do |t|
    t.string "ai_model"
    t.string "api_key_encrypted"
    t.decimal "cost_per_1k_tokens", precision: 10, scale: 6
    t.datetime "created_at", null: false
    t.string "endpoint_url"
    t.integer "max_tokens"
    t.string "name", null: false
    t.string "provider_type", null: false
    t.integer "rate_limit_per_minute"
    t.text "settings"
    t.string "status", default: "active"
    t.datetime "updated_at", null: false
    t.index ["provider_type"], name: "index_ai_providers_on_provider_type"
    t.index ["status"], name: "index_ai_providers_on_status"
  end

  create_table "ai_requests", force: :cascade do |t|
    t.integer "ai_prompt_id"
    t.integer "ai_provider_id"
    t.decimal "cost", precision: 10, scale: 6
    t.datetime "created_at", null: false
    t.text "error_message"
    t.text "input_data"
    t.integer "latency_ms"
    t.string "request_type", null: false
    t.bigint "requestable_id"
    t.string "requestable_type"
    t.text "response_data"
    t.string "status", default: "pending"
    t.integer "tokens_used"
    t.datetime "updated_at", null: false
    t.index ["ai_prompt_id"], name: "index_ai_requests_on_ai_prompt_id"
    t.index ["ai_provider_id"], name: "index_ai_requests_on_ai_provider_id"
    t.index ["created_at", "status"], name: "idx_ai_requests_time_status"
    t.index ["request_type"], name: "index_ai_requests_on_request_type"
    t.index ["requestable_type", "requestable_id"], name: "index_ai_requests_on_requestable_type_and_requestable_id"
    t.index ["status"], name: "index_ai_requests_on_status"
  end

  create_table "anomalies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "severity"
    t.float "temp_deviation"
    t.integer "truck_id", null: false
    t.datetime "updated_at", null: false
    t.float "voltage_deviation"
    t.index ["truck_id"], name: "index_anomalies_on_truck_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action"
    t.string "actor_id"
    t.string "actor_name"
    t.string "actor_type"
    t.integer "auditable_id"
    t.string "auditable_type"
    t.text "change_data"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.text "metadata"
    t.datetime "recorded_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["action", "created_at"], name: "idx_audit_action_time"
    t.index ["auditable_type", "auditable_id", "created_at"], name: "idx_audit_entity_time"
  end

  create_table "capacity_plan_items", force: :cascade do |t|
    t.integer "available_capacity"
    t.integer "capacity_gap"
    t.integer "capacity_plan_id", null: false
    t.datetime "created_at", null: false
    t.text "details"
    t.integer "forecast_demand"
    t.string "item_type", null: false
    t.string "lane_code"
    t.string "priority"
    t.string "recommendation"
    t.integer "region_id"
    t.integer "site_id"
    t.datetime "updated_at", null: false
    t.decimal "utilization_percent", precision: 5, scale: 2
    t.index ["capacity_plan_id"], name: "index_capacity_plan_items_on_capacity_plan_id"
    t.index ["item_type"], name: "index_capacity_plan_items_on_item_type"
    t.index ["region_id"], name: "index_capacity_plan_items_on_region_id"
    t.index ["site_id"], name: "index_capacity_plan_items_on_site_id"
  end

  create_table "capacity_plans", force: :cascade do |t|
    t.datetime "approved_at"
    t.string "approved_by"
    t.datetime "created_at", null: false
    t.string "created_by"
    t.string "name", null: false
    t.date "plan_end_date", null: false
    t.date "plan_start_date", null: false
    t.text "recommendations"
    t.string "status", default: "draft"
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_capacity_plans_on_status"
  end

  create_table "compliance_records", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "evidence"
    t.datetime "expires_at"
    t.text "notes"
    t.string "record_type"
    t.string "reference_id"
    t.string "reference_type"
    t.text "requirements"
    t.string "status"
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.string "verified_by"
  end

  create_table "consumption_rates", force: :cascade do |t|
    t.decimal "average_daily_consumption", precision: 10, scale: 2
    t.date "calculated_from"
    t.date "calculated_to"
    t.decimal "consumption_variance", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.integer "lead_time_days"
    t.decimal "peak_daily_consumption", precision: 10, scale: 2
    t.string "period_type", default: "daily"
    t.string "product_code", null: false
    t.integer "region_id"
    t.integer "site_id"
    t.datetime "updated_at", null: false
    t.index ["product_code", "region_id"], name: "index_consumption_rates_on_product_code_and_region_id"
    t.index ["product_code", "site_id"], name: "index_consumption_rates_on_product_code_and_site_id"
    t.index ["product_code"], name: "index_consumption_rates_on_product_code"
    t.index ["region_id"], name: "index_consumption_rates_on_region_id"
    t.index ["site_id"], name: "index_consumption_rates_on_site_id"
  end

  create_table "customers", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "hospital"
    t.integer "trucks"
    t.datetime "updated_at", null: false
  end

  create_table "data_exports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "format"
    t.string "status"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "demand_forecasts", force: :cascade do |t|
    t.integer "actual_quantity"
    t.decimal "confidence_level", precision: 5, scale: 4
    t.datetime "created_at", null: false
    t.date "forecast_date", null: false
    t.integer "forecast_quantity", null: false
    t.string "forecast_source"
    t.text "notes"
    t.string "period_type", default: "daily"
    t.string "product_code", null: false
    t.string "product_name"
    t.integer "region_id"
    t.integer "site_id"
    t.datetime "updated_at", null: false
    t.index ["product_code", "forecast_date"], name: "index_demand_forecasts_on_product_code_and_forecast_date"
    t.index ["region_id", "forecast_date"], name: "index_demand_forecasts_on_region_id_and_forecast_date"
    t.index ["region_id"], name: "index_demand_forecasts_on_region_id"
    t.index ["site_id", "forecast_date"], name: "index_demand_forecasts_on_site_id_and_forecast_date"
    t.index ["site_id"], name: "index_demand_forecasts_on_site_id"
  end

  create_table "dock_appointments", force: :cascade do |t|
    t.string "appointment_type"
    t.datetime "arrived_at"
    t.datetime "created_at", null: false
    t.datetime "departed_at"
    t.string "dock_number"
    t.text "notes"
    t.datetime "scheduled_at"
    t.string "status"
    t.integer "truck_id", null: false
    t.datetime "updated_at", null: false
    t.integer "warehouse_id", null: false
    t.index ["truck_id"], name: "index_dock_appointments_on_truck_id"
    t.index ["warehouse_id"], name: "index_dock_appointments_on_warehouse_id"
  end

  create_table "inventory_items", force: :cascade do |t|
    t.datetime "arrival_time"
    t.datetime "created_at", null: false
    t.date "expiration_date"
    t.string "lot_number"
    t.string "product_name"
    t.integer "quantity"
    t.string "status"
    t.integer "storage_zone_id", null: false
    t.string "temperature_requirements"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["lot_number"], name: "idx_inventory_lot"
    t.index ["storage_zone_id", "status"], name: "idx_inventory_zone_status"
    t.index ["storage_zone_id"], name: "index_inventory_items_on_storage_zone_id"
  end

  create_table "inventory_movements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "from_location_id"
    t.string "from_location_type"
    t.integer "inventory_position_id"
    t.string "movement_type", null: false
    t.text "notes"
    t.string "performed_by"
    t.integer "quantity", null: false
    t.string "reason"
    t.bigint "reference_id"
    t.string "reference_type"
    t.bigint "to_location_id"
    t.string "to_location_type"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_inventory_movements_on_created_at"
    t.index ["inventory_position_id"], name: "index_inventory_movements_on_inventory_position_id"
    t.index ["movement_type"], name: "index_inventory_movements_on_movement_type"
    t.index ["reference_type", "reference_id"], name: "index_inventory_movements_on_reference_type_and_reference_id"
  end

  create_table "inventory_positions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "expiration_date"
    t.datetime "last_movement_at"
    t.string "lot_number"
    t.integer "max_stock_level"
    t.string "product_code", null: false
    t.string "product_name"
    t.integer "quantity_allocated", default: 0
    t.integer "quantity_available", default: 0
    t.integer "quantity_in_transit", default: 0
    t.integer "quantity_on_hand", default: 0
    t.integer "reorder_point"
    t.integer "safety_stock"
    t.integer "site_id"
    t.string "status", default: "available"
    t.integer "storage_zone_id"
    t.string "temperature_requirement"
    t.datetime "updated_at", null: false
    t.integer "warehouse_id"
    t.index ["expiration_date"], name: "index_inventory_positions_on_expiration_date"
    t.index ["lot_number"], name: "index_inventory_positions_on_lot_number"
    t.index ["product_code", "site_id"], name: "index_inventory_positions_on_product_code_and_site_id"
    t.index ["product_code", "warehouse_id"], name: "index_inventory_positions_on_product_code_and_warehouse_id"
    t.index ["product_code"], name: "index_inventory_positions_on_product_code"
    t.index ["site_id"], name: "index_inventory_positions_on_site_id"
    t.index ["status"], name: "index_inventory_positions_on_status"
    t.index ["storage_zone_id"], name: "index_inventory_positions_on_storage_zone_id"
    t.index ["warehouse_id"], name: "index_inventory_positions_on_warehouse_id"
  end

  create_table "lane_capacities", force: :cascade do |t|
    t.string "carrier_name"
    t.decimal "cost_per_shipment", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.bigint "destination_id"
    t.string "destination_type"
    t.date "effective_date"
    t.date "end_date"
    t.string "lane_code", null: false
    t.decimal "lead_time_hours", precision: 6, scale: 2
    t.bigint "origin_id"
    t.string "origin_type"
    t.integer "pallets_per_day"
    t.integer "shipments_per_day"
    t.string "status", default: "active"
    t.string "transport_mode"
    t.datetime "updated_at", null: false
    t.integer "weight_capacity_kg"
    t.index ["destination_type", "destination_id"], name: "index_lane_capacities_on_destination_type_and_destination_id"
    t.index ["lane_code"], name: "index_lane_capacities_on_lane_code", unique: true
    t.index ["origin_type", "origin_id"], name: "index_lane_capacities_on_origin_type_and_origin_id"
    t.index ["status"], name: "index_lane_capacities_on_status"
  end

  create_table "monitorings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "power_status"
    t.datetime "recorded_at"
    t.decimal "temperature"
    t.integer "truck_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recorded_at"], name: "idx_monitoring_recorded_at"
    t.index ["truck_id", "recorded_at"], name: "idx_monitoring_truck_time"
    t.index ["truck_id"], name: "index_monitorings_on_truck_id"
  end

  create_table "node_capacities", force: :cascade do |t|
    t.integer "ambient_capacity"
    t.bigint "capacitable_id"
    t.string "capacitable_type"
    t.integer "cold_storage_capacity"
    t.datetime "created_at", null: false
    t.date "effective_date"
    t.date "end_date"
    t.integer "frozen_capacity"
    t.string "name", null: false
    t.text "notes"
    t.string "status", default: "active"
    t.integer "storage_capacity_pallets"
    t.integer "throughput_per_day"
    t.datetime "updated_at", null: false
    t.decimal "utilization_percent", precision: 5, scale: 2
    t.index ["capacitable_type", "capacitable_id"], name: "index_node_capacities_on_capacitable_type_and_capacitable_id"
    t.index ["status"], name: "index_node_capacities_on_status"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "plan"
    t.datetime "updated_at", null: false
    t.integer "users_count"
  end

  create_table "packages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "lane"
    t.string "qualification_status"
    t.integer "truck_id", null: false
    t.datetime "updated_at", null: false
    t.index ["truck_id"], name: "index_packages_on_truck_id"
  end

  create_table "portal_users", force: :cascade do |t|
    t.string "api_key"
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "last_login_at"
    t.string "name"
    t.string "organization_name"
    t.string "organization_type"
    t.text "permissions"
    t.string "role"
    t.string "status"
    t.datetime "updated_at", null: false
  end

  create_table "provenances", force: :cascade do |t|
    t.string "batch_id"
    t.string "blockchain_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified"
  end

  create_table "regions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "replenishment_orders", force: :cascade do |t|
    t.date "actual_arrival_date"
    t.datetime "created_at", null: false
    t.string "created_by"
    t.integer "destination_site_id"
    t.integer "destination_warehouse_id"
    t.date "expected_arrival_date"
    t.text "notes"
    t.string "order_number", null: false
    t.string "order_type", default: "replenishment"
    t.string "priority", default: "normal"
    t.string "product_code", null: false
    t.integer "quantity_ordered", null: false
    t.integer "quantity_received", default: 0
    t.integer "quantity_shipped", default: 0
    t.date "requested_date"
    t.integer "source_site_id"
    t.integer "source_warehouse_id"
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.index ["destination_site_id"], name: "index_replenishment_orders_on_destination_site_id"
    t.index ["destination_warehouse_id"], name: "index_replenishment_orders_on_destination_warehouse_id"
    t.index ["order_number"], name: "index_replenishment_orders_on_order_number", unique: true
    t.index ["priority"], name: "index_replenishment_orders_on_priority"
    t.index ["product_code"], name: "index_replenishment_orders_on_product_code"
    t.index ["source_site_id"], name: "index_replenishment_orders_on_source_site_id"
    t.index ["source_warehouse_id"], name: "index_replenishment_orders_on_source_warehouse_id"
    t.index ["status"], name: "index_replenishment_orders_on_status"
  end

  create_table "routes", force: :cascade do |t|
    t.boolean "allowed_detours", default: true
    t.datetime "completed_at"
    t.decimal "cost_estimate", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.string "destination"
    t.decimal "distance"
    t.integer "estimated_duration"
    t.decimal "lane_risk_factor", precision: 5, scale: 2
    t.integer "max_transit_hours"
    t.string "name"
    t.string "origin"
    t.string "preferred_carrier"
    t.integer "priority", default: 5
    t.datetime "started_at"
    t.string "status"
    t.string "temperature_sensitivity", default: "standard"
    t.datetime "time_window_end"
    t.datetime "time_window_start"
    t.integer "truck_id"
    t.datetime "updated_at", null: false
    t.text "waypoints"
    t.index ["status", "started_at"], name: "idx_routes_status_started"
    t.index ["truck_id", "status"], name: "idx_routes_truck_status"
    t.index ["truck_id"], name: "index_routes_on_truck_id"
  end

  create_table "rules", force: :cascade do |t|
    t.string "action"
    t.boolean "active"
    t.string "condition"
    t.datetime "created_at", null: false
    t.integer "priority"
    t.datetime "updated_at", null: false
  end

  create_table "shipment_events", force: :cascade do |t|
    t.text "compliance_notes"
    t.datetime "created_at", null: false
    t.text "description"
    t.text "deviation_justification"
    t.boolean "deviation_reported"
    t.string "event_type", null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.text "metadata"
    t.string "previous_hash"
    t.datetime "recorded_at", null: false
    t.string "recorded_by"
    t.integer "route_id"
    t.string "signature"
    t.boolean "signature_captured"
    t.boolean "signature_required"
    t.decimal "temperature_c", precision: 5, scale: 2
    t.integer "truck_id", null: false
    t.datetime "updated_at", null: false
    t.integer "waypoint_id"
    t.string "witness_name"
    t.index ["event_type"], name: "idx_events_type"
    t.index ["event_type"], name: "index_shipment_events_on_event_type"
    t.index ["route_id", "recorded_at"], name: "idx_events_route_time"
    t.index ["route_id"], name: "index_shipment_events_on_route_id"
    t.index ["truck_id", "recorded_at"], name: "idx_events_truck_time"
    t.index ["truck_id", "recorded_at"], name: "index_shipment_events_on_truck_id_and_recorded_at"
    t.index ["truck_id"], name: "index_shipment_events_on_truck_id"
    t.index ["waypoint_id"], name: "index_shipment_events_on_waypoint_id"
  end

  create_table "shipment_shares", force: :cascade do |t|
    t.string "access_level"
    t.integer "accessed_count"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "last_accessed_at"
    t.integer "portal_user_id", null: false
    t.integer "route_id", null: false
    t.string "share_token"
    t.datetime "updated_at", null: false
    t.index ["portal_user_id"], name: "index_shipment_shares_on_portal_user_id"
    t.index ["route_id"], name: "index_shipment_shares_on_route_id"
  end

  create_table "signatures", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device_info"
    t.string "ip_address"
    t.integer "signable_id"
    t.string "signable_type"
    t.text "signature_data"
    t.datetime "signed_at"
    t.string "signer_email"
    t.string "signer_name"
    t.string "signer_role"
    t.datetime "updated_at", null: false
    t.string "verification_code"
  end

  create_table "simulation_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "data"
    t.string "event_type"
    t.integer "route_id"
    t.integer "simulation_id", null: false
    t.datetime "timestamp"
    t.integer "truck_id"
    t.datetime "updated_at", null: false
    t.index ["simulation_id", "timestamp"], name: "idx_sim_events_time"
    t.index ["simulation_id"], name: "index_simulation_events_on_simulation_id"
  end

  create_table "simulations", force: :cascade do |t|
    t.datetime "completed_at"
    t.text "configuration"
    t.datetime "created_at", null: false
    t.string "created_by"
    t.text "description"
    t.text "results"
    t.string "scenario_name"
    t.datetime "started_at"
    t.string "status"
    t.datetime "updated_at", null: false
  end

  create_table "site_impacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "impact_score"
    t.integer "patients_affected"
    t.string "site_name"
    t.datetime "updated_at", null: false
  end

  create_table "sites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "region_id", null: false
    t.datetime "updated_at", null: false
    t.index ["region_id"], name: "index_sites_on_region_id"
  end

  create_table "stock_alerts", force: :cascade do |t|
    t.datetime "acknowledged_at"
    t.string "acknowledged_by"
    t.string "alert_type", null: false
    t.datetime "created_at", null: false
    t.integer "current_quantity"
    t.integer "days_until_stockout"
    t.date "expiration_date"
    t.integer "inventory_position_id"
    t.text "message"
    t.string "product_code"
    t.text "recommended_action"
    t.datetime "resolved_at"
    t.string "resolved_by"
    t.string "severity", default: "medium"
    t.integer "site_id"
    t.string "status", default: "active"
    t.decimal "stockout_probability", precision: 5, scale: 2
    t.integer "threshold_quantity"
    t.datetime "updated_at", null: false
    t.integer "warehouse_id"
    t.index ["alert_type"], name: "index_stock_alerts_on_alert_type"
    t.index ["inventory_position_id"], name: "index_stock_alerts_on_inventory_position_id"
    t.index ["product_code", "status"], name: "index_stock_alerts_on_product_code_and_status"
    t.index ["severity"], name: "index_stock_alerts_on_severity"
    t.index ["site_id"], name: "index_stock_alerts_on_site_id"
    t.index ["status"], name: "index_stock_alerts_on_status"
    t.index ["warehouse_id"], name: "index_stock_alerts_on_warehouse_id"
  end

  create_table "storage_zones", force: :cascade do |t|
    t.integer "capacity_pallets"
    t.datetime "created_at", null: false
    t.integer "current_occupancy"
    t.decimal "max_temp"
    t.decimal "min_temp"
    t.string "name"
    t.string "status"
    t.datetime "updated_at", null: false
    t.integer "warehouse_id", null: false
    t.string "zone_type"
    t.index ["warehouse_id"], name: "index_storage_zones_on_warehouse_id"
  end

  create_table "supply_chain_nodes", force: :cascade do |t|
    t.decimal "capacity"
    t.datetime "created_at", null: false
    t.decimal "demand"
    t.string "node_type"
    t.integer "truck_id", null: false
    t.datetime "updated_at", null: false
    t.index ["truck_id"], name: "index_supply_chain_nodes_on_truck_id"
  end

  create_table "telemetry_readings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "humidity"
    t.decimal "latitude"
    t.decimal "longitude"
    t.json "raw_payload"
    t.datetime "recorded_at"
    t.decimal "speed_kph"
    t.decimal "temperature_c"
    t.integer "truck_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recorded_at"], name: "idx_telemetry_recorded_at"
    t.index ["truck_id", "recorded_at"], name: "idx_telemetry_truck_time"
    t.index ["truck_id"], name: "index_telemetry_readings_on_truck_id"
  end

  create_table "trucks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "max_temp"
    t.decimal "min_temp"
    t.string "name"
    t.string "risk_level"
    t.decimal "risk_score"
    t.integer "site_id"
    t.string "status"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["site_id", "status"], name: "idx_trucks_site_status"
    t.index ["site_id"], name: "index_trucks_on_site_id"
    t.index ["user_id"], name: "index_trucks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "warehouse_readings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "humidity"
    t.datetime "recorded_at"
    t.string "sensor_id"
    t.integer "storage_zone_id", null: false
    t.decimal "temperature"
    t.datetime "updated_at", null: false
    t.integer "warehouse_id", null: false
    t.index ["storage_zone_id", "recorded_at"], name: "idx_zone_readings_time"
    t.index ["storage_zone_id"], name: "index_warehouse_readings_on_storage_zone_id"
    t.index ["warehouse_id", "recorded_at"], name: "idx_warehouse_readings_time"
    t.index ["warehouse_id"], name: "index_warehouse_readings_on_warehouse_id"
  end

  create_table "warehouse_tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "priority"
    t.string "robot_id"
    t.string "status"
    t.datetime "updated_at", null: false
  end

  create_table "warehouses", force: :cascade do |t|
    t.string "address"
    t.integer "capacity_pallets"
    t.string "city"
    t.string "code"
    t.datetime "created_at", null: false
    t.integer "current_occupancy"
    t.decimal "latitude"
    t.decimal "longitude"
    t.decimal "max_temp"
    t.decimal "min_temp"
    t.string "name"
    t.integer "site_id"
    t.string "state"
    t.string "status"
    t.datetime "updated_at", null: false
    t.string "warehouse_type"
    t.string "zip"
    t.index ["site_id"], name: "index_warehouses_on_site_id"
  end

  create_table "waypoints", force: :cascade do |t|
    t.datetime "arrival_time"
    t.datetime "created_at", null: false
    t.datetime "departure_time"
    t.integer "position"
    t.integer "route_id", null: false
    t.integer "site_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["route_id"], name: "index_waypoints_on_route_id"
    t.index ["site_id"], name: "index_waypoints_on_site_id"
  end

  create_table "webhook_subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "events"
    t.integer "failure_count"
    t.datetime "last_triggered_at"
    t.integer "portal_user_id", null: false
    t.string "secret"
    t.string "status"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["portal_user_id"], name: "index_webhook_subscriptions_on_portal_user_id"
  end

  add_foreign_key "ai_feedbacks", "ai_insights"
  add_foreign_key "ai_insights", "ai_requests"
  add_foreign_key "ai_requests", "ai_prompts"
  add_foreign_key "ai_requests", "ai_providers"
  add_foreign_key "anomalies", "trucks"
  add_foreign_key "capacity_plan_items", "capacity_plans"
  add_foreign_key "capacity_plan_items", "regions"
  add_foreign_key "capacity_plan_items", "sites"
  add_foreign_key "consumption_rates", "regions"
  add_foreign_key "consumption_rates", "sites"
  add_foreign_key "demand_forecasts", "regions"
  add_foreign_key "demand_forecasts", "sites"
  add_foreign_key "dock_appointments", "trucks"
  add_foreign_key "dock_appointments", "warehouses"
  add_foreign_key "inventory_items", "storage_zones"
  add_foreign_key "inventory_movements", "inventory_positions"
  add_foreign_key "inventory_positions", "sites"
  add_foreign_key "inventory_positions", "storage_zones"
  add_foreign_key "inventory_positions", "warehouses"
  add_foreign_key "monitorings", "trucks"
  add_foreign_key "packages", "trucks"
  add_foreign_key "replenishment_orders", "sites", column: "destination_site_id"
  add_foreign_key "replenishment_orders", "sites", column: "source_site_id"
  add_foreign_key "replenishment_orders", "warehouses", column: "destination_warehouse_id"
  add_foreign_key "replenishment_orders", "warehouses", column: "source_warehouse_id"
  add_foreign_key "routes", "trucks"
  add_foreign_key "shipment_events", "routes"
  add_foreign_key "shipment_events", "trucks"
  add_foreign_key "shipment_events", "waypoints"
  add_foreign_key "shipment_shares", "portal_users"
  add_foreign_key "shipment_shares", "routes"
  add_foreign_key "simulation_events", "simulations"
  add_foreign_key "sites", "regions"
  add_foreign_key "stock_alerts", "inventory_positions"
  add_foreign_key "stock_alerts", "sites"
  add_foreign_key "stock_alerts", "warehouses"
  add_foreign_key "storage_zones", "warehouses"
  add_foreign_key "supply_chain_nodes", "trucks"
  add_foreign_key "telemetry_readings", "trucks"
  add_foreign_key "trucks", "sites"
  add_foreign_key "trucks", "users"
  add_foreign_key "warehouse_readings", "storage_zones"
  add_foreign_key "warehouse_readings", "warehouses"
  add_foreign_key "warehouses", "sites"
  add_foreign_key "waypoints", "routes"
  add_foreign_key "waypoints", "sites"
  add_foreign_key "webhook_subscriptions", "portal_users"
end
