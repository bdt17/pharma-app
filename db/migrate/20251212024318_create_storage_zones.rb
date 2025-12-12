class CreateStorageZones < ActiveRecord::Migration[8.1]
  def change
    create_table :storage_zones do |t|
      t.references :warehouse, null: false, foreign_key: true
      t.string :name
      t.string :zone_type
      t.decimal :min_temp
      t.decimal :max_temp
      t.integer :capacity_pallets
      t.integer :current_occupancy
      t.string :status

      t.timestamps
    end
  end
end
