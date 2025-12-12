class CreatePortalUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :portal_users do |t|
      t.string :email
      t.string :name
      t.string :role
      t.string :organization_name
      t.string :organization_type
      t.string :api_key
      t.text :permissions
      t.datetime :last_login_at
      t.string :status

      t.timestamps
    end
  end
end
