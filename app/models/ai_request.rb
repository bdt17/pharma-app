class AiRequest < ApplicationRecord
  belongs_to :ai_provider, optional: true
  belongs_to :ai_prompt, optional: true
  belongs_to :requestable, polymorphic: true, optional: true
  has_many :ai_insights, dependent: :destroy

  STATUSES = %w[pending processing completed failed cancelled].freeze
  REQUEST_TYPES = %w[
    risk_assessment
    route_optimization
    anomaly_detection
    temperature_prediction
    demand_forecast
    compliance_review
    incident_analysis
    maintenance_prediction
    batch_analysis
    custom
  ].freeze

  validates :request_type, presence: true, inclusion: { in: REQUEST_TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { order(created_at: :desc) }

  def input_data_hash
    return {} if input_data.blank?
    JSON.parse(input_data) rescue {}
  end

  def input_data_hash=(value)
    self.input_data = value.to_json
  end

  def response_data_hash
    return {} if response_data.blank?
    JSON.parse(response_data) rescue {}
  end

  def response_data_hash=(value)
    self.response_data = value.to_json
  end

  def mark_processing!
    update!(status: 'processing')
  end

  def mark_completed!(response, tokens: nil, latency: nil)
    update!(
      status: 'completed',
      response_data: response.to_json,
      tokens_used: tokens,
      latency_ms: latency,
      cost: ai_provider&.cost_estimate(tokens || 0)
    )
  end

  def mark_failed!(error_msg)
    update!(status: 'failed', error_message: error_msg)
  end
end
