class CreateTelemetryReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :telemetry_readings do |t|
      t.references :truck, null: false, foreign_key: true
      t.decimal :latitude
      t.decimal :longitude
      t.datetime :recorded_at
      t.decimal :temperature_c
      t.decimal :humidity
      t.decimal :speed_kph
      t.json :raw_payload

      t.timestamps
    end
  end
end
