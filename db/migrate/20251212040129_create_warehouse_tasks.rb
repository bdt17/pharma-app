class CreateWarehouseTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :warehouse_tasks do |t|
      t.string :robot_id
      t.string :status
      t.integer :priority

      t.timestamps
    end
  end
end
