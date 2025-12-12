class AddConstraintsToRoutes < ActiveRecord::Migration[8.1]
  def change
    add_column :routes, :max_transit_hours, :integer
    add_column :routes, :preferred_carrier, :string
    add_column :routes, :allowed_detours, :boolean, default: true
    add_column :routes, :temperature_sensitivity, :string, default: 'standard'
    add_column :routes, :priority, :integer, default: 5
    add_column :routes, :cost_estimate, :decimal, precision: 10, scale: 2
    add_column :routes, :lane_risk_factor, :decimal, precision: 5, scale: 2
    add_column :routes, :time_window_start, :datetime
    add_column :routes, :time_window_end, :datetime
  end
end
