class MakeTruckUserIdNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :trucks, :user_id, true
  end
end
