class CreateAnomalies < ActiveRecord::Migration[8.1]
  def change
    create_table :anomalies do |t|
      t.float :voltage_deviation
      t.float :temp_deviation
      t.references :truck, null: false, foreign_key: true
      t.string :severity

      t.timestamps
    end
  end
end
