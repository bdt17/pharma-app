class ChangeTruckIdNullableOnRoutes < ActiveRecord::Migration[8.1]
  def change
    change_column_null :routes, :truck_id, true
  end
end
