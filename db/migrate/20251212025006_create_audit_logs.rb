class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.string :auditable_type
      t.integer :auditable_id
      t.string :action
      t.string :actor_type
      t.string :actor_id
      t.string :actor_name
      t.text :change_data
      t.string :ip_address
      t.string :user_agent
      t.datetime :recorded_at
      t.text :metadata

      t.timestamps
    end
  end
end
