class Warehouse < ApplicationRecord
  belongs_to :site, optional: true
  has_many :storage_zones, dependent: :destroy
  has_many :warehouse_readings, dependent: :destroy
  has_many :dock_appointments, dependent: :destroy
  has_many :inventory_items, through: :storage_zones

  TYPES = %w[distribution_center cold_storage cross_dock regional_hub].freeze
  STATUSES = %w[active inactive maintenance full].freeze

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
  validates :warehouse_type, inclusion: { in: TYPES }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }
  validates :min_temp, :max_temp, numericality: true, allow_nil: true
  validates :capacity_pallets, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(status: 'active') }
  scope :cold_storage, -> { where(warehouse_type: 'cold_storage') }
  scope :with_capacity, -> { where('capacity_pallets > current_occupancy OR current_occupancy IS NULL') }

  def available_capacity
    return nil unless capacity_pallets
    capacity_pallets - (current_occupancy || 0)
  end

  def occupancy_percentage
    return 0 unless capacity_pallets&.positive?
    ((current_occupancy || 0).to_f / capacity_pallets * 100).round(1)
  end

  def in_temp_range?(temp)
    return true unless min_temp && max_temp
    temp >= min_temp && temp <= max_temp
  end

  def latest_reading
    warehouse_readings.order(recorded_at: :desc).first
  end

  def current_temperature
    latest_reading&.temperature
  end

  def temperature_status
    temp = current_temperature
    return 'unknown' unless temp
    return 'in_range' if in_temp_range?(temp)
    temp < min_temp ? 'too_cold' : 'too_hot'
  end

  def coordinates
    return nil unless latitude && longitude
    { lat: latitude.to_f, lng: longitude.to_f }
  end

  def full_address
    [address, city, state, zip].compact.join(', ')
  end

  def today_appointments
    dock_appointments.where(scheduled_at: Time.current.beginning_of_day..Time.current.end_of_day)
  end

  def pending_arrivals
    dock_appointments.where(status: 'scheduled', appointment_type: 'inbound')
  end

  def pending_departures
    dock_appointments.where(status: 'scheduled', appointment_type: 'outbound')
  end
end
