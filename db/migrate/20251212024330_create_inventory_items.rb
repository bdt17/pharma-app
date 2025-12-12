class CreateInventoryItems < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_items do |t|
      t.references :storage_zone, null: false, foreign_key: true
      t.string :product_name
      t.string :lot_number
      t.integer :quantity
      t.string :unit
      t.datetime :arrival_time
      t.date :expiration_date
      t.string :status
      t.string :temperature_requirements

      t.timestamps
    end
  end
end
