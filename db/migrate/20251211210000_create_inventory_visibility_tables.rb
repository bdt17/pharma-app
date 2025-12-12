class CreateInventoryVisibilityTables < ActiveRecord::Migration[8.0]
  def change
    create_table :inventory_positions do |t|
      t.string :product_code, null: false
      t.string :product_name
      t.string :lot_number
      t.references :site, foreign_key: true
      t.references :warehouse, foreign_key: true
      t.references :storage_zone, foreign_key: true
      t.integer :quantity_on_hand, default: 0
      t.integer :quantity_allocated, default: 0
      t.integer :quantity_available, default: 0
      t.integer :quantity_in_transit, default: 0
      t.integer :reorder_point
      t.integer :safety_stock
      t.integer :max_stock_level
      t.date :expiration_date
      t.string :temperature_requirement
      t.string :status, default: 'available'
      t.datetime :last_movement_at
      t.timestamps
    end

    add_index :inventory_positions, :product_code
    add_index :inventory_positions, :lot_number
    add_index :inventory_positions, :status
    add_index :inventory_positions, :expiration_date
    add_index :inventory_positions, [:product_code, :site_id]
    add_index :inventory_positions, [:product_code, :warehouse_id]

    create_table :inventory_movements do |t|
      t.references :inventory_position, foreign_key: true
      t.string :movement_type, null: false
      t.integer :quantity, null: false
      t.string :reference_type
      t.bigint :reference_id
      t.string :from_location_type
      t.bigint :from_location_id
      t.string :to_location_type
      t.bigint :to_location_id
      t.string :reason
      t.string :performed_by
      t.text :notes
      t.timestamps
    end

    add_index :inventory_movements, :movement_type
    add_index :inventory_movements, [:reference_type, :reference_id]
    add_index :inventory_movements, :created_at

    create_table :stock_alerts do |t|
      t.references :inventory_position, foreign_key: true
      t.string :product_code
      t.references :site, foreign_key: true
      t.references :warehouse, foreign_key: true
      t.string :alert_type, null: false
      t.string :severity, default: 'medium'
      t.string :status, default: 'active'
      t.integer :current_quantity
      t.integer :threshold_quantity
      t.date :expiration_date
      t.integer :days_until_stockout
      t.decimal :stockout_probability, precision: 5, scale: 2
      t.text :message
      t.text :recommended_action
      t.datetime :acknowledged_at
      t.string :acknowledged_by
      t.datetime :resolved_at
      t.string :resolved_by
      t.timestamps
    end

    add_index :stock_alerts, :alert_type
    add_index :stock_alerts, :severity
    add_index :stock_alerts, :status
    add_index :stock_alerts, [:product_code, :status]

    create_table :consumption_rates do |t|
      t.string :product_code, null: false
      t.references :site, foreign_key: true
      t.references :region, foreign_key: true
      t.string :period_type, default: 'daily'
      t.decimal :average_daily_consumption, precision: 10, scale: 2
      t.decimal :peak_daily_consumption, precision: 10, scale: 2
      t.decimal :consumption_variance, precision: 10, scale: 2
      t.integer :lead_time_days
      t.date :calculated_from
      t.date :calculated_to
      t.timestamps
    end

    add_index :consumption_rates, :product_code
    add_index :consumption_rates, [:product_code, :site_id]
    add_index :consumption_rates, [:product_code, :region_id]

    create_table :replenishment_orders do |t|
      t.string :order_number, null: false
      t.string :product_code, null: false
      t.references :destination_site, foreign_key: { to_table: :sites }
      t.references :destination_warehouse, foreign_key: { to_table: :warehouses }
      t.references :source_site, foreign_key: { to_table: :sites }
      t.references :source_warehouse, foreign_key: { to_table: :warehouses }
      t.integer :quantity_ordered, null: false
      t.integer :quantity_shipped, default: 0
      t.integer :quantity_received, default: 0
      t.string :status, default: 'pending'
      t.string :priority, default: 'normal'
      t.string :order_type, default: 'replenishment'
      t.date :requested_date
      t.date :expected_arrival_date
      t.date :actual_arrival_date
      t.string :created_by
      t.text :notes
      t.timestamps
    end

    add_index :replenishment_orders, :order_number, unique: true
    add_index :replenishment_orders, :product_code
    add_index :replenishment_orders, :status
    add_index :replenishment_orders, :priority
  end
end
