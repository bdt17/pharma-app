class DockAppointment < ApplicationRecord
  belongs_to :warehouse
  belongs_to :truck, optional: true

  TYPES = %w[inbound outbound cross_dock].freeze
  STATUSES = %w[scheduled confirmed arrived loading unloading completed cancelled no_show].freeze

  validates :appointment_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :scheduled_at, presence: true

  scope :today, -> { where(scheduled_at: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :upcoming, -> { where('scheduled_at > ?', Time.current).order(scheduled_at: :asc) }
  scope :inbound, -> { where(appointment_type: 'inbound') }
  scope :outbound, -> { where(appointment_type: 'outbound') }
  scope :active, -> { where(status: %w[arrived loading unloading]) }
  scope :pending, -> { where(status: %w[scheduled confirmed]) }

  def arrive!
    update!(arrived_at: Time.current, status: 'arrived')
  end

  def start_loading!
    update!(status: 'loading')
  end

  def start_unloading!
    update!(status: 'unloading')
  end

  def complete!
    update!(departed_at: Time.current, status: 'completed')
  end

  def cancel!
    update!(status: 'cancelled')
  end

  def mark_no_show!
    update!(status: 'no_show')
  end

  def on_time?
    return nil unless arrived_at && scheduled_at
    arrived_at <= scheduled_at + 15.minutes
  end

  def wait_time_minutes
    return nil unless arrived_at
    end_time = departed_at || Time.current
    ((end_time - arrived_at) / 60).round
  end

  def dwell_time_minutes
    return nil unless arrived_at && departed_at
    ((departed_at - arrived_at) / 60).round
  end

  def late_by_minutes
    return nil unless arrived_at && scheduled_at
    return 0 if on_time?
    ((arrived_at - scheduled_at) / 60).round
  end

  def inbound?
    appointment_type == 'inbound'
  end

  def outbound?
    appointment_type == 'outbound'
  end
end
