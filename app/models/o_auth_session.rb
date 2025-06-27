class OAuthSession < ApplicationRecord
  belongs_to :user

  validates :access_token, presence: true
  validates :state, presence: true, uniqueness: true

  serialize :permissions, coder: JSON

  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  def expired?
    return false if expires_at.nil?
    expires_at <= Time.current
  end

  def active?
    !expired?
  end

  def has_permission?(permission)
    permissions.include?(permission.to_s)
  end

  # Create session from WorkOS authentication response
  def self.create_from_workos_response(user, auth_response, state)
    # Decode JWT to extract permissions
    access_token_data = JWT.decode(auth_response.access_token, nil, false).first
    permissions = access_token_data['permissions'] || []

    create!(
      user: user,
      access_token: auth_response.access_token,
      refresh_token: auth_response.refresh_token,
      permissions: permissions,
      expires_at: Time.current + 1.hour, # Default to 1 hour expiry
      state: state
    )
  end

  # Clean up expired sessions
  def self.cleanup_expired
    expired.destroy_all
  end
end
