class CreateWarehouseReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :warehouse_readings do |t|
      t.references :warehouse, null: false, foreign_key: true
      t.references :storage_zone, null: false, foreign_key: true
      t.decimal :temperature
      t.decimal :humidity
      t.datetime :recorded_at
      t.string :sensor_id

      t.timestamps
    end
  end
end
