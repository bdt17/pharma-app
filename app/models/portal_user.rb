class PortalUser < ApplicationRecord
  has_many :shipment_shares, dependent: :destroy
  has_many :webhook_subscriptions, dependent: :destroy

  ROLES = %w[customer partner carrier admin].freeze
  ORGANIZATION_TYPES = %w[shipper receiver carrier 3pl distributor manufacturer].freeze
  STATUSES = %w[active suspended pending].freeze

  PERMISSIONS = %w[
    view_shipments
    view_temperature
    view_location
    view_documents
    receive_alerts
    create_appointments
    sign_deliveries
    view_analytics
    manage_webhooks
  ].freeze

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :organization_type, inclusion: { in: ORGANIZATION_TYPES }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }

  serialize :permissions, coder: JSON

  before_create :generate_api_key

  scope :active, -> { where(status: 'active') }
  scope :customers, -> { where(role: 'customer') }
  scope :partners, -> { where(role: 'partner') }
  scope :carriers, -> { where(role: 'carrier') }

  def has_permission?(permission)
    permissions_list.include?(permission.to_s)
  end

  def permissions_list
    permissions || []
  end

  def grant_permission(permission)
    return unless PERMISSIONS.include?(permission.to_s)
    self.permissions = (permissions_list + [permission.to_s]).uniq
    save!
  end

  def revoke_permission(permission)
    self.permissions = permissions_list - [permission.to_s]
    save!
  end

  def regenerate_api_key!
    generate_api_key
    save!
    api_key
  end

  def record_login!
    update!(last_login_at: Time.current)
  end

  def active?
    status == 'active'
  end

  def can_access_shipment?(route)
    return true if role == 'admin'
    shipment_shares.active.where(route: route).exists?
  end

  private

  def generate_api_key
    self.api_key = "portal_#{SecureRandom.hex(24)}"
  end
end
