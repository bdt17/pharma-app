class CreateAiIntegrationTables < ActiveRecord::Migration[8.0]
  def change
    # AI Provider configurations
    create_table :ai_providers do |t|
      t.string :name, null: false
      t.string :provider_type, null: false  # openai, anthropic, azure, custom
      t.string :endpoint_url
      t.string :api_key_encrypted
      t.string :model_name
      t.text :settings  # JSON stored as text for SQLite compatibility
      t.string :status, default: 'active'
      t.integer :rate_limit_per_minute
      t.integer :max_tokens
      t.decimal :cost_per_1k_tokens, precision: 10, scale: 6
      t.timestamps
    end

    # AI Prompts/Templates
    create_table :ai_prompts do |t|
      t.string :name, null: false
      t.string :prompt_type, null: false  # risk_assessment, route_optimization, anomaly_detection, etc.
      t.text :system_prompt
      t.text :user_prompt_template
      t.text :variables  # JSON stored as text
      t.string :version
      t.boolean :active, default: true
      t.timestamps
    end

    # AI Requests log
    create_table :ai_requests do |t|
      t.references :ai_provider, foreign_key: true
      t.references :ai_prompt, foreign_key: true
      t.string :request_type, null: false
      t.string :requestable_type
      t.bigint :requestable_id
      t.text :input_data  # JSON stored as text
      t.text :response_data  # JSON stored as text
      t.string :status, default: 'pending'  # pending, processing, completed, failed
      t.text :error_message
      t.integer :tokens_used
      t.decimal :cost, precision: 10, scale: 6
      t.integer :latency_ms
      t.timestamps
    end

    # AI Insights generated
    create_table :ai_insights do |t|
      t.references :ai_request, foreign_key: true
      t.string :insight_type, null: false  # risk_prediction, route_recommendation, anomaly_alert, etc.
      t.string :insightable_type
      t.bigint :insightable_id
      t.string :title
      t.text :summary
      t.text :details  # JSON stored as text
      t.decimal :confidence_score, precision: 5, scale: 4
      t.string :severity  # low, medium, high, critical
      t.string :status, default: 'active'  # active, acknowledged, resolved, dismissed
      t.datetime :acknowledged_at
      t.string :acknowledged_by
      t.timestamps
    end

    # AI Model feedback for continuous improvement
    create_table :ai_feedbacks do |t|
      t.references :ai_insight, foreign_key: true
      t.string :feedback_type, null: false  # accurate, inaccurate, helpful, not_helpful
      t.integer :rating  # 1-5
      t.text :comments
      t.string :submitted_by
      t.boolean :used_for_training, default: false
      t.timestamps
    end

    add_index :ai_providers, :provider_type
    add_index :ai_providers, :status
    add_index :ai_prompts, :prompt_type
    add_index :ai_prompts, [:prompt_type, :active]
    add_index :ai_requests, :request_type
    add_index :ai_requests, :status
    add_index :ai_requests, [:requestable_type, :requestable_id]
    add_index :ai_insights, :insight_type
    add_index :ai_insights, :severity
    add_index :ai_insights, :status
    add_index :ai_insights, [:insightable_type, :insightable_id]
  end
end
