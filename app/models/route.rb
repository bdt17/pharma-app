class Route < ApplicationRecord
  belongs_to :truck, optional: true
  has_many :waypoints, -> { order(position: :asc) }, dependent: :destroy
  has_many :shipment_events, dependent: :nullify
  has_many :signatures, as: :signable, dependent: :destroy
  has_many :audit_logs, -> { where(auditable_type: 'Route') }, foreign_key: :auditable_id

  STATUSES = %w[draft planned in_progress completed cancelled].freeze
  TEMPERATURE_SENSITIVITIES = %w[critical high standard low].freeze

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  validates :temperature_sensitivity, inclusion: { in: TEMPERATURE_SENSITIVITIES }, allow_nil: true
  validates :priority, numericality: { greater_than: 0, less_than_or_equal_to: 10 }, allow_nil: true

  scope :active, -> { where(status: %w[planned in_progress]) }
  scope :pending, -> { where(status: 'planned') }
  scope :by_priority, -> { order(priority: :desc) }

  def waypoint_sites
    waypoints.includes(:site).map(&:site).compact
  end

  def total_stops
    waypoints.count
  end

  def completed_stops
    waypoints.where(status: 'completed').count
  end

  def progress_percentage
    return 0 if total_stops.zero?
    (completed_stops.to_f / total_stops * 100).round
  end

  def in_progress?
    status == 'in_progress'
  end

  def can_start?
    status == 'planned' && truck.present?
  end

  def risk_assessment
    RouteRiskScorer.for_route(self)
  end

  def risk_score
    risk_assessment[:score]
  end

  def risk_level
    risk_assessment[:level]
  end

  def start!
    return false unless can_start?

    update!(status: 'in_progress', started_at: Time.current)
    true
  end

  def complete!
    return false unless status == 'in_progress'

    update!(status: 'completed', completed_at: Time.current)
    true
  end

  def optimization_score(constraints = {})
    DynamicRouteOptimizer.score_route(self, constraints)
  end

  def within_time_window?
    return true unless time_window_start || time_window_end

    now = Time.current
    (time_window_start.nil? || now >= time_window_start) &&
      (time_window_end.nil? || now <= time_window_end)
  end

  def estimated_arrival
    return nil unless estimated_duration && started_at

    started_at + estimated_duration.minutes
  end
end
