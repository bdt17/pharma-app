class CreateMonitorings < ActiveRecord::Migration[8.1]
  def change
    create_table :monitorings do |t|
      t.references :truck, null: false, foreign_key: true
      t.decimal :temperature
      t.string :power_status
      t.datetime :recorded_at

      t.timestamps
    end
  end
end
