class CreateTrucks < ActiveRecord::Migration[8.1]
  def change
    create_table :trucks do |t|
      t.string :name
      t.string :status
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
