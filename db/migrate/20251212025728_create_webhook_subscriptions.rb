class CreateWebhookSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_subscriptions do |t|
      t.references :portal_user, null: false, foreign_key: true
      t.string :url
      t.text :events
      t.string :secret
      t.string :status
      t.datetime :last_triggered_at
      t.integer :failure_count

      t.timestamps
    end
  end
end
