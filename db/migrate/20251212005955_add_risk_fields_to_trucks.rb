class AddRiskFieldsToTrucks < ActiveRecord::Migration[8.1]
  def change
    add_column :trucks, :risk_score, :decimal
    add_column :trucks, :risk_level, :string
  end
end
