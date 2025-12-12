class CreateSimulations < ActiveRecord::Migration[8.1]
  def change
    create_table :simulations do |t|
      t.string :scenario_name
      t.text :description
      t.string :status
      t.datetime :started_at
      t.datetime :completed_at
      t.text :configuration
      t.text :results
      t.string :created_by

      t.timestamps
    end
  end
end
