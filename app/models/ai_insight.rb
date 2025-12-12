class AiInsight < ApplicationRecord
  belongs_to :ai_request, optional: true
  belongs_to :insightable, polymorphic: true, optional: true
  has_many :ai_feedbacks, dependent: :destroy

  INSIGHT_TYPES = %w[
    risk_prediction
    route_recommendation
    anomaly_alert
    temperature_forecast
    demand_prediction
    compliance_issue
    incident_report
    maintenance_alert
    optimization_suggestion
    custom
  ].freeze

  SEVERITIES = %w[low medium high critical].freeze
  STATUSES = %w[active acknowledged resolved dismissed].freeze

  validates :insight_type, presence: true, inclusion: { in: INSIGHT_TYPES }
  validates :severity, inclusion: { in: SEVERITIES }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: 'active') }
  scope :by_severity, ->(sev) { where(severity: sev) }
  scope :critical, -> { where(severity: 'critical') }
  scope :high_priority, -> { where(severity: %w[critical high]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :unacknowledged, -> { where(acknowledged_at: nil) }

  def details_hash
    return {} if details.blank?
    JSON.parse(details) rescue {}
  end

  def details_hash=(value)
    self.details = value.to_json
  end

  def acknowledge!(user)
    update!(acknowledged_at: Time.current, acknowledged_by: user, status: 'acknowledged')
  end

  def resolve!
    update!(status: 'resolved')
  end

  def dismiss!
    update!(status: 'dismissed')
  end

  def high_confidence?
    confidence_score && confidence_score >= 0.8
  end
end
