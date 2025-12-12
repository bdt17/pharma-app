class AddSiteToTrucks < ActiveRecord::Migration[8.1]
  def change
    add_reference :trucks, :site, null: true, foreign_key: true
  end
end
