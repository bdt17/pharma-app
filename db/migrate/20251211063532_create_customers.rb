class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.string :email
      t.string :hospital
      t.integer :trucks
      t.boolean :active

      t.timestamps
    end
  end
end
