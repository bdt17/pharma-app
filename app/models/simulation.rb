class Simulation < ApplicationRecord
  has_many :simulation_events, dependent: :destroy

  STATUSES = %w[draft running paused completed failed].freeze
  SCENARIO_TYPES = %w[
    temperature_excursion
    power_failure
    route_delay
    multi_truck_stress
    weather_event
    equipment_degradation
    custom
  ].freeze

  validates :scenario_name, presence: true
  validates :status, inclusion: { in: STATUSES }

  serialize :configuration, coder: JSON
  serialize :results, coder: JSON

  scope :active, -> { where(status: %w[running paused]) }
  scope :completed, -> { where(status: 'completed') }

  def running?
    status == 'running'
  end

  def can_start?
    status.in?(%w[draft paused])
  end

  def can_pause?
    status == 'running'
  end

  def duration_seconds
    return nil unless started_at
    end_time = completed_at || Time.current
    (end_time - started_at).to_i
  end

  def event_count
    simulation_events.count
  end

  def configuration_hash
    configuration || {}
  end

  def results_hash
    results || {}
  end
end
