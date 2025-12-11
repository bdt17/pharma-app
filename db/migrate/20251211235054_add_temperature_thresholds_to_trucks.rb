class AddTemperatureThresholdsToTrucks < ActiveRecord::Migration[8.1]
  def change
    add_column :trucks, :min_temp, :decimal
    add_column :trucks, :max_temp, :decimal
  end
end
