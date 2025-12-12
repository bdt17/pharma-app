class Truck < ApplicationRecord
  belongs_to :site, optional: true
  has_many :monitorings, dependent: :destroy
  has_many :telemetry_readings, dependent: :destroy
  has_many :shipment_events, dependent: :destroy
  has_many :routes, dependent: :nullify

  delegate :region, to: :site, allow_nil: true

  def out_of_range?(temperature)
    return false if temperature.nil?
    return false if min_temp.nil? && max_temp.nil?

    (min_temp.present? && temperature < min_temp) ||
      (max_temp.present? && temperature > max_temp)
  end

  def latest_telemetry
    telemetry_readings.recent.first
  end

  def latest_position
    telemetry_readings.where.not(latitude: nil, longitude: nil).recent.first
  end

  def current_temperature
    latest_telemetry&.temperature_c || monitorings.order(recorded_at: :desc).first&.temperature
  end

  def temperature_status
    temp = current_temperature
    return 'unknown' unless temp
    return 'in_range' unless out_of_range?(temp)
    temp < min_temp.to_f ? 'too_cold' : 'too_hot'
  end
end
