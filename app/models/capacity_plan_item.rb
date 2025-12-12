class CapacityPlanItem < ApplicationRecord
  belongs_to :capacity_plan
  belongs_to :region, optional: true
  belongs_to :site, optional: true

  ITEM_TYPES = %w[lane node region product].freeze
  PRIORITIES = %w[low medium high critical].freeze
  RECOMMENDATIONS = %w[increase_capacity add_carrier reduce_demand optimize_routing no_action].freeze

  validates :item_type, presence: true, inclusion: { in: ITEM_TYPES }
  validates :priority, inclusion: { in: PRIORITIES }, allow_nil: true
  validates :recommendation, inclusion: { in: RECOMMENDATIONS }, allow_nil: true

  scope :by_type, ->(type) { where(item_type: type) }
  scope :with_gap, -> { where('capacity_gap > 0') }
  scope :critical, -> { where(priority: 'critical') }
  scope :high_priority, -> { where(priority: %w[critical high]) }

  def has_capacity_gap?
    capacity_gap.present? && capacity_gap > 0
  end

  def gap_severity
    return 'none' unless has_capacity_gap?
    return 'critical' if utilization_percent && utilization_percent > 100
    return 'high' if utilization_percent && utilization_percent > 90
    return 'medium' if utilization_percent && utilization_percent > 80
    'low'
  end

  def details_hash
    return {} if details.blank?
    JSON.parse(details) rescue {}
  end

  def details_hash=(value)
    self.details = value.to_json
  end
end
