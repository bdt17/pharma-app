class ShipmentShare < ApplicationRecord
  belongs_to :route
  belongs_to :portal_user

  ACCESS_LEVELS = %w[basic tracking full].freeze

  validates :share_token, presence: true, uniqueness: true
  validates :access_level, inclusion: { in: ACCESS_LEVELS }

  before_validation :generate_share_token, on: :create

  scope :active, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :by_token, ->(token) { where(share_token: token) }

  def expired?
    expires_at && expires_at <= Time.current
  end

  def record_access!
    increment!(:accessed_count)
    update!(last_accessed_at: Time.current)
  end

  def can_view_temperature?
    access_level.in?(%w[tracking full])
  end

  def can_view_location?
    access_level.in?(%w[tracking full])
  end

  def can_view_documents?
    access_level == 'full'
  end

  def can_view_compliance?
    access_level == 'full'
  end

  def public_url
    "/portal/track/#{share_token}"
  end

  private

  def generate_share_token
    self.share_token ||= SecureRandom.urlsafe_base64(16)
  end
end
