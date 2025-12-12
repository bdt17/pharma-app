class CreateDockAppointments < ActiveRecord::Migration[8.1]
  def change
    create_table :dock_appointments do |t|
      t.references :warehouse, null: false, foreign_key: true
      t.references :truck, null: false, foreign_key: true
      t.string :appointment_type
      t.datetime :scheduled_at
      t.datetime :arrived_at
      t.datetime :departed_at
      t.string :dock_number
      t.string :status
      t.text :notes

      t.timestamps
    end
  end
end
