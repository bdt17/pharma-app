class Signature < ApplicationRecord
  belongs_to :signable, polymorphic: true

  ROLES = %w[driver dispatcher warehouse_operator quality_manager recipient witness].freeze

  validates :signer_name, presence: true
  validates :signer_role, inclusion: { in: ROLES }
  validates :signed_at, presence: true

  before_create :generate_verification_code
  after_create :log_signature

  scope :for_record, ->(type, id) { where(signable_type: type, signable_id: id) }
  scope :by_role, ->(role) { where(signer_role: role) }
  scope :recent, ->(hours = 24) { where('signed_at > ?', hours.hours.ago) }

  def verify(code)
    return false unless verification_code.present?
    ActiveSupport::SecurityUtils.secure_compare(verification_code, code)
  end

  def signature_hash
    Digest::SHA256.hexdigest([
      signable_type,
      signable_id,
      signer_name,
      signer_email,
      signed_at.iso8601
    ].join('|'))
  end

  def display_info
    "#{signer_name} (#{signer_role}) - #{signed_at.strftime('%Y-%m-%d %H:%M:%S')}"
  end

  private

  def generate_verification_code
    self.verification_code ||= SecureRandom.hex(16)
  end

  def log_signature
    AuditLog.log(
      action: 'sign',
      auditable: signable,
      actor: signer_name,
      metadata: {
        signer_role: signer_role,
        signer_email: signer_email,
        signature_hash: signature_hash
      }
    )
  end
end
