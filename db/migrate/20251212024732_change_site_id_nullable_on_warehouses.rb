class ChangeSiteIdNullableOnWarehouses < ActiveRecord::Migration[8.1]
  def change
    change_column_null :warehouses, :site_id, true
  end
end
