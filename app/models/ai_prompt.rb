class AiPrompt < ApplicationRecord
  has_many :ai_requests, dependent: :nullify

  PROMPT_TYPES = %w[
    risk_assessment
    route_optimization
    anomaly_detection
    temperature_prediction
    demand_forecast
    compliance_review
    incident_analysis
    maintenance_prediction
    custom
  ].freeze

  validates :name, presence: true
  validates :prompt_type, presence: true, inclusion: { in: PROMPT_TYPES }

  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(prompt_type: type) }

  def variables_list
    return [] if variables.blank?
    JSON.parse(variables) rescue []
  end

  def variables_list=(value)
    self.variables = value.to_json
  end

  def render(context = {})
    rendered = user_prompt_template.dup
    context.each do |key, value|
      rendered.gsub!("{{#{key}}}", value.to_s)
    end
    rendered
  end

  def self.for_type(type)
    active.by_type(type).order(version: :desc).first
  end
end
