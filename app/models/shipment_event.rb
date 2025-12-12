class ShipmentEvent < ApplicationRecord
  belongs_to :truck
  belongs_to :route, optional: true
  belongs_to :waypoint, optional: true
  has_many :signatures, as: :signable, dependent: :destroy

  EVENT_TYPES = %w[
    route_started
    route_completed
    stop_arrival
    stop_departure
    temperature_reading
    temperature_excursion
    door_opened
    door_closed
    geofence_enter
    geofence_exit
    signature_captured
    delivery_confirmed
    delivery_refused
    incident_reported
    manual_check
  ].freeze

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :recorded_at, presence: true

  before_create :set_chain_hash
  after_create_commit :broadcast_event

  scope :for_truck, ->(truck_id) { where(truck_id: truck_id).order(recorded_at: :desc) }
  scope :for_route, ->(route_id) { where(route_id: route_id).order(recorded_at: :asc) }
  scope :recent, -> { order(recorded_at: :desc) }
  scope :excursions, -> { where(event_type: 'temperature_excursion') }
  scope :custody_events, -> { where(event_type: %w[stop_arrival stop_departure signature_captured delivery_confirmed]) }

  def self.log_event(truck:, event_type:, **attributes)
    create!(
      truck: truck,
      event_type: event_type,
      recorded_at: Time.current,
      **attributes
    )
  end

  def self.chain_of_custody(truck_id, route_id = nil)
    scope = for_truck(truck_id).custody_events
    scope = scope.for_route(route_id) if route_id
    scope.order(:recorded_at)
  end

  def self.verify_chain(truck_id)
    events = where(truck_id: truck_id).order(recorded_at: :asc, created_at: :asc)
    return { valid: true, events: 0 } if events.empty?

    previous_hash = nil
    events.each_with_index do |event, index|
      if event.previous_hash != previous_hash
        return {
          valid: false,
          broken_at: index,
          event_id: event.id,
          expected: previous_hash,
          actual: event.previous_hash
        }
      end
      previous_hash = event.compute_hash
    end

    { valid: true, events: events.count }
  end

  def parsed_metadata
    return {} if metadata.blank?
    JSON.parse(metadata) rescue {}
  end

  def metadata_hash=(hash)
    self.metadata = hash.to_json
  end

  def compute_hash
    data = "#{id}|#{truck_id}|#{event_type}|#{recorded_at.to_i}|#{previous_hash}"
    Digest::SHA256.hexdigest(data)
  end

  def tamper_check
    return true if previous_hash.nil? && first_event?

    previous_event = ShipmentEvent.where(truck_id: truck_id)
                                  .where("recorded_at < ?", recorded_at)
                                  .order(recorded_at: :desc)
                                  .first

    return true if previous_event.nil? && previous_hash.nil?
    return false if previous_event.nil? && previous_hash.present?
    return false if previous_event.present? && previous_hash != previous_event.compute_hash

    true
  end

  private

  def set_chain_hash
    previous_event = ShipmentEvent.where(truck_id: truck_id)
                                  .order(created_at: :desc)
                                  .first

    self.previous_hash = previous_event&.compute_hash
  end

  def first_event?
    ShipmentEvent.where(truck_id: truck_id)
                .where("recorded_at < ?", recorded_at)
                .none?
  end

  def broadcast_event
    return unless defined?(ActionCable)

    ActionCable.server.broadcast("console_updates", {
      type: "shipment_event",
      truck_id: truck_id,
      truck_name: truck.name,
      event_type: event_type,
      description: description,
      recorded_at: recorded_at&.iso8601,
      route_id: route_id
    })
  end
end
