class Route < ApplicationRecord
  belongs_to :truck, optional: true
  has_many :waypoints, -> { order(position: :asc) }, dependent: :destroy

  STATUSES = %w[draft planned in_progress completed cancelled].freeze

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  scope :active, -> { where(status: %w[planned in_progress]) }
  scope :pending, -> { where(status: 'planned') }

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
end
