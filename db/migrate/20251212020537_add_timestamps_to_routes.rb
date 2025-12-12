class AddTimestampsToRoutes < ActiveRecord::Migration[8.1]
  def change
    add_column :routes, :started_at, :datetime
    add_column :routes, :completed_at, :datetime
  end
end
