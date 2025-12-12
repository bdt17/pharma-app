class CreateShipmentShares < ActiveRecord::Migration[8.1]
  def change
    create_table :shipment_shares do |t|
      t.references :route, null: false, foreign_key: true
      t.references :portal_user, null: false, foreign_key: true
      t.string :share_token
      t.string :access_level
      t.datetime :expires_at
      t.integer :accessed_count
      t.datetime :last_accessed_at

      t.timestamps
    end
  end
end
