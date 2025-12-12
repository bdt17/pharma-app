class CreateRoutes < ActiveRecord::Migration[8.1]
  def change
    create_table :routes do |t|
      t.string :name
      t.string :origin
      t.string :destination
      t.text :waypoints
      t.string :status
      t.references :truck, null: false, foreign_key: true
      t.integer :estimated_duration
      t.decimal :distance

      t.timestamps
    end
  end
end
