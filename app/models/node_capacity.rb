class NodeCapacity < ApplicationRecord
  belongs_to :capacitable, polymorphic: true, optional: true

  STATUSES = %w[active inactive planned].freeze

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: 'active') }
  scope :current, -> { where('effective_date IS NULL OR effective_date <= ?', Date.current).where('end_date IS NULL OR end_date >= ?', Date.current) }
  scope :for_node, ->(node) { where(capacitable: node) }

  def total_capacity
    (cold_storage_capacity || 0) + (frozen_capacity || 0) + (ambient_capacity || 0)
  end

  def available_capacity
    total = storage_capacity_pallets || total_capacity
    return total unless utilization_percent
    (total * (100 - utilization_percent) / 100).to_i
  end

  def capacity_status
    return 'unknown' unless utilization_percent
    case utilization_percent
    when 0..70 then 'available'
    when 70..90 then 'moderate'
    else 'constrained'
    end
  end
end
