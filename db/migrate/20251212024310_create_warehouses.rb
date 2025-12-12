class CreateWarehouses < ActiveRecord::Migration[8.1]
  def change
    create_table :warehouses do |t|
      t.string :name
      t.string :code
      t.string :warehouse_type
      t.string :address
      t.string :city
      t.string :state
      t.string :zip
      t.decimal :latitude
      t.decimal :longitude
      t.decimal :min_temp
      t.decimal :max_temp
      t.integer :capacity_pallets
      t.integer :current_occupancy
      t.string :status
      t.references :site, null: false, foreign_key: true

      t.timestamps
    end
  end
end
