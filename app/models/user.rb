class User < ApplicationRecord
  has_many :oauth_sessions, class_name: 'OAuthSession', dependent: :destroy

  validates :workos_id, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.present? ? full_name : email
  end

  # Find or create user from WorkOS user data
  def self.from_workos_user(workos_user, organization_id = nil)
    find_or_create_by(workos_id: workos_user.id) do |user|
      user.email = workos_user.email
      user.first_name = workos_user.first_name
      user.last_name = workos_user.last_name
      user.profile_picture_url = workos_user.profile_picture_url
      user.organization_id = organization_id
    end
  end
end
