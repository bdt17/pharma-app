class CreateSimulationEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :simulation_events do |t|
      t.references :simulation, null: false, foreign_key: true
      t.string :event_type
      t.integer :truck_id
      t.integer :route_id
      t.datetime :timestamp
      t.text :data

      t.timestamps
    end
  end
end
