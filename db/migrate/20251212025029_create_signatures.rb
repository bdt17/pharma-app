class CreateSignatures < ActiveRecord::Migration[8.1]
  def change
    create_table :signatures do |t|
      t.string :signable_type
      t.integer :signable_id
      t.string :signer_name
      t.string :signer_role
      t.string :signer_email
      t.text :signature_data
      t.datetime :signed_at
      t.string :ip_address
      t.string :device_info
      t.string :verification_code

      t.timestamps
    end
  end
end
