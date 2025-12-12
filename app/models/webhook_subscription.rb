class WebhookSubscription < ApplicationRecord
  belongs_to :portal_user

  EVENTS = %w[
    shipment.started
    shipment.completed
    shipment.delayed
    temperature.excursion
    temperature.warning
    location.updated
    delivery.arrived
    delivery.completed
    delivery.refused
    alert.triggered
  ].freeze

  STATUSES = %w[active paused disabled failed].freeze
  MAX_FAILURES = 5

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :status, inclusion: { in: STATUSES }

  serialize :events, coder: JSON

  before_create :generate_secret

  scope :active, -> { where(status: 'active') }
  scope :for_event, ->(event) { active.select { |w| w.subscribed_to?(event) } }

  def subscribed_to?(event)
    events_list.include?(event.to_s) || events_list.include?('*')
  end

  def events_list
    events || []
  end

  def subscribe_to(event)
    return unless EVENTS.include?(event.to_s) || event == '*'
    self.events = (events_list + [event.to_s]).uniq
    save!
  end

  def unsubscribe_from(event)
    self.events = events_list - [event.to_s]
    save!
  end

  def record_success!
    update!(
      last_triggered_at: Time.current,
      failure_count: 0,
      status: 'active'
    )
  end

  def record_failure!
    new_count = (failure_count || 0) + 1
    new_status = new_count >= MAX_FAILURES ? 'failed' : status

    update!(
      last_triggered_at: Time.current,
      failure_count: new_count,
      status: new_status
    )
  end

  def failed?
    status == 'failed'
  end

  def regenerate_secret!
    generate_secret
    save!
    secret
  end

  def signature_for(payload)
    OpenSSL::HMAC.hexdigest('SHA256', secret, payload.to_json)
  end

  private

  def generate_secret
    self.secret ||= SecureRandom.hex(32)
  end
end
