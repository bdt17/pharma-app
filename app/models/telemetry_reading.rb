class TelemetryReading < ApplicationRecord
  belongs_to :truck

  validates :recorded_at, presence: true
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validates :temperature_c, numericality: { greater_than_or_equal_to: -100, less_than_or_equal_to: 100 }, allow_nil: true
  validates :humidity, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :speed_kph, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 500 }, allow_nil: true
  validate :location_or_sensor_present

  scope :recent, -> { order(recorded_at: :desc) }
  scope :last_24h, -> { where("recorded_at > ?", 24.hours.ago) }

  after_create_commit :broadcast_and_alert

  def out_of_range?
    return false unless temperature_c.present? && truck.present?
    truck.out_of_range?(temperature_c)
  end

  def coordinates
    return nil unless latitude.present? && longitude.present?
    [latitude, longitude]
  end

  private

  def location_or_sensor_present
    has_location = latitude.present? && longitude.present?
    has_sensor = temperature_c.present? || humidity.present? || speed_kph.present?

    unless has_location || has_sensor
      errors.add(:base, "Must have location (lat/lng) or at least one sensor reading")
    end
  end

  def broadcast_and_alert
    TelemetryBroadcaster.broadcast(self)
    RiskScorer.for_truck(truck) if out_of_range?
  rescue StandardError => e
    Rails.logger.error("TelemetryReading broadcast error: #{e.message}")
  end
end
