class InventoryItem < ApplicationRecord
  belongs_to :storage_zone

  STATUSES = %w[available reserved picked shipped quarantine expired damaged].freeze
  TEMP_REQUIREMENTS = %w[frozen refrigerated cold_chain controlled ambient].freeze

  validates :product_name, presence: true
  validates :lot_number, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :temperature_requirements, inclusion: { in: TEMP_REQUIREMENTS }, allow_nil: true

  scope :available, -> { where(status: 'available') }
  scope :expiring_soon, ->(days = 30) { where('expiration_date <= ?', days.days.from_now).where('expiration_date > ?', Date.current) }
  scope :expired, -> { where('expiration_date < ?', Date.current) }
  scope :cold_chain, -> { where(temperature_requirements: %w[frozen refrigerated cold_chain]) }

  delegate :warehouse, to: :storage_zone

  def days_until_expiration
    return nil unless expiration_date
    (expiration_date - Date.current).to_i
  end

  def expired?
    expiration_date && expiration_date < Date.current
  end

  def expiring_soon?(days = 30)
    return false unless expiration_date
    !expired? && expiration_date <= days.days.from_now
  end

  def in_correct_zone?
    return true unless temperature_requirements
    storage_zone.suitable_for_product?(temperature_requirements)
  end

  def current_zone_temperature
    storage_zone.current_temperature
  end

  def temperature_compliant?
    temp = current_zone_temperature
    return true unless temp && storage_zone.min_temp && storage_zone.max_temp
    storage_zone.in_temp_range?(temp)
  end

  def dwell_time_hours
    return nil unless arrival_time
    ((Time.current - arrival_time) / 1.hour).round(1)
  end
end
