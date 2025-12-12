class CreateNetworkPlanningTables < ActiveRecord::Migration[8.0]
  def change
    create_table :node_capacities do |t|
      t.string :capacitable_type
      t.bigint :capacitable_id
      t.string :name, null: false
      t.integer :storage_capacity_pallets
      t.integer :throughput_per_day
      t.integer :cold_storage_capacity
      t.integer :frozen_capacity
      t.integer :ambient_capacity
      t.decimal :utilization_percent, precision: 5, scale: 2
      t.date :effective_date
      t.date :end_date
      t.string :status, default: 'active'
      t.text :notes
      t.timestamps
    end

    create_table :lane_capacities do |t|
      t.string :lane_code, null: false
      t.string :origin_type
      t.bigint :origin_id
      t.string :destination_type
      t.bigint :destination_id
      t.string :transport_mode
      t.integer :shipments_per_day
      t.integer :pallets_per_day
      t.integer :weight_capacity_kg
      t.decimal :lead_time_hours, precision: 6, scale: 2
      t.decimal :cost_per_shipment, precision: 10, scale: 2
      t.string :carrier_name
      t.date :effective_date
      t.date :end_date
      t.string :status, default: 'active'
      t.timestamps
    end

    create_table :demand_forecasts do |t|
      t.string :product_code, null: false
      t.string :product_name
      t.references :region, foreign_key: true
      t.references :site, foreign_key: true
      t.date :forecast_date, null: false
      t.string :period_type, default: 'daily'
      t.integer :forecast_quantity, null: false
      t.integer :actual_quantity
      t.decimal :confidence_level, precision: 5, scale: 4
      t.string :forecast_source
      t.text :notes
      t.timestamps
    end

    create_table :capacity_plans do |t|
      t.string :name, null: false
      t.date :plan_start_date, null: false
      t.date :plan_end_date, null: false
      t.string :status, default: 'draft'
      t.text :summary
      t.text :recommendations
      t.string :created_by
      t.datetime :approved_at
      t.string :approved_by
      t.timestamps
    end

    create_table :capacity_plan_items do |t|
      t.references :capacity_plan, null: false, foreign_key: true
      t.string :item_type, null: false
      t.string :lane_code
      t.references :region, foreign_key: true
      t.references :site, foreign_key: true
      t.integer :forecast_demand
      t.integer :available_capacity
      t.integer :capacity_gap
      t.decimal :utilization_percent, precision: 5, scale: 2
      t.string :recommendation
      t.string :priority
      t.text :details
      t.timestamps
    end

    add_index :node_capacities, [:capacitable_type, :capacitable_id]
    add_index :node_capacities, :status
    add_index :lane_capacities, :lane_code, unique: true
    add_index :lane_capacities, [:origin_type, :origin_id]
    add_index :lane_capacities, [:destination_type, :destination_id]
    add_index :lane_capacities, :status
    add_index :demand_forecasts, [:product_code, :forecast_date]
    add_index :demand_forecasts, [:region_id, :forecast_date]
    add_index :demand_forecasts, [:site_id, :forecast_date]
    add_index :capacity_plans, :status
    add_index :capacity_plan_items, :item_type
  end
end
