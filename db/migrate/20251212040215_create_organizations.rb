class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name
      t.string :plan
      t.integer :users_count

      t.timestamps
    end
  end
end
