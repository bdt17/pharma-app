class CapacityPlan < ApplicationRecord
  has_many :capacity_plan_items, dependent: :destroy

  STATUSES = %w[draft pending_approval approved rejected archived].freeze

  validates :name, presence: true
  validates :plan_start_date, presence: true
  validates :plan_end_date, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: %w[draft pending_approval approved]) }
  scope :approved, -> { where(status: 'approved') }

  def duration_days
    (plan_end_date - plan_start_date).to_i
  end

  def approve!(approver)
    update!(status: 'approved', approved_at: Time.current, approved_by: approver)
  end

  def reject!(approver)
    update!(status: 'rejected', approved_by: approver)
  end

  def total_capacity_gap
    capacity_plan_items.sum(:capacity_gap)
  end

  def critical_items
    capacity_plan_items.where(priority: 'critical')
  end

  def recommendations_list
    return [] if recommendations.blank?
    JSON.parse(recommendations) rescue [recommendations]
  end

  def recommendations_list=(value)
    self.recommendations = value.to_json
  end
end
