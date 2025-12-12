class AiProvider < ApplicationRecord
  has_many :ai_requests, dependent: :destroy

  PROVIDER_TYPES = %w[openai anthropic azure bedrock google custom].freeze
  STATUSES = %w[active inactive testing].freeze

  validates :name, presence: true
  validates :provider_type, presence: true, inclusion: { in: PROVIDER_TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: 'active') }
  scope :by_type, ->(type) { where(provider_type: type) }

  def settings_hash
    return {} if settings.blank?
    JSON.parse(settings) rescue {}
  end

  def settings_hash=(value)
    self.settings = value.to_json
  end

  def available?
    status == 'active'
  end

  def simulation_mode?
    api_key_encrypted.blank?
  end

  def cost_estimate(tokens)
    return 0 unless cost_per_1k_tokens
    (tokens / 1000.0) * cost_per_1k_tokens
  end

  # Alias for the renamed column
  def model_identifier
    ai_model
  end
end
