class CreateRules < ActiveRecord::Migration[8.1]
  def change
    create_table :rules do |t|
      t.string :condition
      t.string :action
      t.integer :priority
      t.boolean :active

      t.timestamps
    end
  end
end
