class WarehouseReading < ApplicationRecord
  belongs_to :warehouse
  belongs_to :storage_zone, optional: true

  validates :temperature, presence: true, numericality: true
  validates :recorded_at, presence: true
  validates :humidity, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  scope :recent, ->(hours = 24) { where('recorded_at > ?', hours.hours.ago) }
  scope :for_zone, ->(zone_id) { where(storage_zone_id: zone_id) }
  scope :chronological, -> { order(recorded_at: :asc) }

  after_create :check_for_excursion
  after_create :broadcast_reading

  def in_range?
    target = storage_zone || warehouse
    return true unless target&.min_temp && target&.max_temp
    temperature >= target.min_temp && temperature <= target.max_temp
  end

  def excursion?
    !in_range?
  end

  def deviation
    target = storage_zone || warehouse
    return 0 unless target&.min_temp && target&.max_temp

    if temperature < target.min_temp
      temperature - target.min_temp
    elsif temperature > target.max_temp
      temperature - target.max_temp
    else
      0
    end
  end

  private

  def check_for_excursion
    return unless excursion?

    # Could trigger alerts here
    Rails.logger.warn "Warehouse excursion detected: #{warehouse.name} - #{temperature}°C"
  end

  def broadcast_reading
    ActionCable.server.broadcast("warehouse_#{warehouse_id}", {
      type: 'reading',
      warehouse_id: warehouse_id,
      storage_zone_id: storage_zone_id,
      temperature: temperature,
      humidity: humidity,
      recorded_at: recorded_at,
      in_range: in_range?
    })
  rescue => e
    Rails.logger.debug "Broadcast skipped: #{e.message}"
  end
end
