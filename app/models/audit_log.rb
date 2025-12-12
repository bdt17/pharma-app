class AuditLog < ApplicationRecord
  ACTIONS = %w[
    create update delete
    view export
    login logout
    approve reject
    sign verify
    temperature_excursion deviation_reported
    chain_break chain_verified
    compliance_check compliance_violation
  ].freeze

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :auditable_type, presence: true
  validates :recorded_at, presence: true

  serialize :change_data, coder: JSON
  serialize :metadata, coder: JSON

  scope :for_record, ->(type, id) { where(auditable_type: type, auditable_id: id) }
  scope :by_actor, ->(actor_id) { where(actor_id: actor_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :recent, ->(hours = 24) { where('recorded_at > ?', hours.hours.ago) }
  scope :chronological, -> { order(recorded_at: :asc) }
  scope :reverse_chronological, -> { order(recorded_at: :desc) }

  before_validation :set_recorded_at

  class << self
    def log(action:, auditable:, actor: nil, changes: nil, metadata: nil, request: nil)
      create!(
        action: action,
        auditable_type: auditable.class.name,
        auditable_id: auditable.id,
        actor_type: actor.is_a?(String) ? 'system' : actor&.class&.name,
        actor_id: actor.is_a?(String) ? actor : actor&.id&.to_s,
        actor_name: actor.is_a?(String) ? actor : actor&.try(:name) || actor&.try(:email),
        change_data: changes,
        ip_address: request&.remote_ip,
        user_agent: request&.user_agent,
        metadata: metadata,
        recorded_at: Time.current
      )
    end

    def log_temperature_excursion(truck:, temperature:, threshold:, metadata: nil)
      log(
        action: 'temperature_excursion',
        auditable: truck,
        actor: 'system',
        changes: { temperature: temperature, threshold: threshold },
        metadata: metadata
      )
    end

    def log_chain_verification(truck:, verified:, actor: nil, metadata: nil)
      log(
        action: verified ? 'chain_verified' : 'chain_break',
        auditable: truck,
        actor: actor || 'system',
        metadata: metadata
      )
    end

    def log_compliance_check(record:, passed:, actor: nil, findings: nil)
      log(
        action: passed ? 'compliance_check' : 'compliance_violation',
        auditable: record,
        actor: actor || 'system',
        metadata: { passed: passed, findings: findings }
      )
    end
  end

  def change_data_hash
    change_data || {}
  end

  def metadata_hash
    metadata || {}
  end

  private

  def set_recorded_at
    self.recorded_at ||= Time.current
  end
end
