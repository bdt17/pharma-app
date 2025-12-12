class ComplianceRecord < ApplicationRecord
  RECORD_TYPES = %w[
    gdp_certification
    temperature_validation
    calibration_certificate
    sop_acknowledgment
    training_record
    deviation_report
    capa_record
    batch_release
    shipment_release
    recall_notification
  ].freeze

  STATUSES = %w[pending in_review approved rejected expired].freeze

  validates :record_type, presence: true, inclusion: { in: RECORD_TYPES }
  validates :reference_id, presence: true
  validates :status, inclusion: { in: STATUSES }

  serialize :requirements, coder: JSON
  serialize :evidence, coder: JSON

  scope :active, -> { where(status: 'approved').where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :pending, -> { where(status: 'pending') }
  scope :expiring_soon, ->(days = 30) { where('expires_at BETWEEN ? AND ?', Time.current, days.days.from_now) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :by_type, ->(type) { where(record_type: type) }

  before_validation :set_default_status

  def approve!(verified_by:)
    update!(
      status: 'approved',
      verified_by: verified_by,
      verified_at: Time.current
    )

    AuditLog.log(
      action: 'approve',
      auditable: self,
      actor: verified_by,
      metadata: { record_type: record_type, reference_id: reference_id }
    )
  end

  def reject!(verified_by:, reason: nil)
    update!(
      status: 'rejected',
      verified_by: verified_by,
      verified_at: Time.current,
      notes: [notes, "Rejected: #{reason}"].compact.join("\n")
    )

    AuditLog.log(
      action: 'reject',
      auditable: self,
      actor: verified_by,
      metadata: { record_type: record_type, reason: reason }
    )
  end

  def expired?
    expires_at && expires_at < Time.current
  end

  def expiring_soon?(days = 30)
    return false unless expires_at
    !expired? && expires_at <= days.days.from_now
  end

  def days_until_expiration
    return nil unless expires_at
    (expires_at.to_date - Date.current).to_i
  end

  def requirements_list
    requirements || []
  end

  def evidence_list
    evidence || []
  end

  def add_evidence(evidence_item)
    self.evidence = evidence_list + [evidence_item.merge(added_at: Time.current)]
    save!
  end

  def meets_requirements?
    return true if requirements_list.empty?

    requirements_list.all? do |req|
      evidence_list.any? { |ev| ev['requirement_id'] == req['id'] && ev['verified'] }
    end
  end

  private

  def set_default_status
    self.status ||= 'pending'
  end
end
