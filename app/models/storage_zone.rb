class StorageZone < ApplicationRecord
  belongs_to :warehouse
  has_many :inventory_items, dependent: :destroy
  has_many :warehouse_readings, dependent: :destroy

  ZONE_TYPES = %w[frozen refrigerated ambient controlled_room quarantine staging].freeze
  STATUSES = %w[active inactive maintenance full].freeze

  validates :name, presence: true
  validates :zone_type, inclusion: { in: ZONE_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :min_temp, :max_temp, numericality: true, allow_nil: true

  scope :active, -> { where(status: 'active') }
  scope :refrigerated, -> { where(zone_type: 'refrigerated') }
  scope :frozen, -> { where(zone_type: 'frozen') }
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

  def temp_range_label
    return 'N/A' unless min_temp && max_temp
    "#{min_temp}°C to #{max_temp}°C"
  end

  def suitable_for_product?(product_temp_requirement)
    case product_temp_requirement
    when 'frozen'
      zone_type == 'frozen'
    when 'refrigerated', 'cold_chain'
      zone_type.in?(%w[refrigerated frozen])
    when 'controlled'
      zone_type.in?(%w[refrigerated controlled_room])
    else
      true
    end
  end
end
