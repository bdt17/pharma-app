class CreateShipmentEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :shipment_events do |t|
      t.references :truck, null: false, foreign_key: true
      t.references :route, foreign_key: true
      t.references :waypoint, foreign_key: true
      t.string :event_type, null: false
      t.text :description
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.decimal :temperature_c, precision: 5, scale: 2
      t.text :metadata
      t.datetime :recorded_at, null: false
      t.string :recorded_by
      t.string :signature
      t.string :previous_hash

      t.timestamps
    end

    add_index :shipment_events, [:truck_id, :recorded_at]
    add_index :shipment_events, :event_type
  end
end
