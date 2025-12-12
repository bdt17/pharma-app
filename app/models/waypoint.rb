class Waypoint < ApplicationRecord
  belongs_to :route
  belongs_to :site

  STATUSES = %w[pending arrived completed skipped].freeze

  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  scope :pending, -> { where(status: ['pending', nil]) }
  scope :completed, -> { where(status: 'completed') }

  def mark_arrived!
    update!(status: 'arrived', arrival_time: Time.current)
  end

  def mark_completed!
    update!(status: 'completed', departure_time: Time.current)
  end

  def mark_skipped!
    update!(status: 'skipped')
  end

  def completed?
    status == 'completed'
  end

  def site_risk_level
    site&.trucks&.maximum(:risk_score) || 0
  end
end
