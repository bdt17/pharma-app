class CreateWaypoints < ActiveRecord::Migration[8.1]
  def change
    create_table :waypoints do |t|
      t.references :route, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.integer :position
      t.datetime :arrival_time
      t.datetime :departure_time
      t.string :status

      t.timestamps
    end
  end
end
