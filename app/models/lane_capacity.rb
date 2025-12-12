class LaneCapacity < ApplicationRecord
  belongs_to :origin, polymorphic: true, optional: true
  belongs_to :destination, polymorphic: true, optional: true

  TRANSPORT_MODES = %w[truck air rail sea multimodal].freeze
  STATUSES = %w[active inactive planned suspended].freeze

  validates :lane_code, presence: true, uniqueness: true
  validates :transport_mode, inclusion: { in: TRANSPORT_MODES }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: 'active') }
  scope :current, -> { where('effective_date IS NULL OR effective_date <= ?', Date.current).where('end_date IS NULL OR end_date >= ?', Date.current) }
  scope :by_mode, ->(mode) { where(transport_mode: mode) }

  def daily_capacity
    shipments_per_day || 0
  end

  def capacity_status
    'available'
  end

  def estimated_cost(shipment_count)
    return 0 unless cost_per_shipment
    cost_per_shipment * shipment_count
  end
end
