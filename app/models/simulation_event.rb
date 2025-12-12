class SimulationEvent < ApplicationRecord
  belongs_to :simulation

  EVENT_TYPES = %w[
    temperature_reading
    telemetry_update
    power_change
    route_progress
    alert_triggered
    waypoint_status
    excursion_start
    excursion_end
    simulation_tick
  ].freeze

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :timestamp, presence: true

  serialize :data, coder: JSON

  scope :for_truck, ->(truck_id) { where(truck_id: truck_id) }
  scope :for_route, ->(route_id) { where(route_id: route_id) }
  scope :chronological, -> { order(timestamp: :asc) }
  scope :by_type, ->(type) { where(event_type: type) }

  def data_hash
    data || {}
  end

  def truck
    Truck.find_by(id: truck_id) if truck_id
  end

  def route
    Route.find_by(id: route_id) if route_id
  end
end
