require 'rails_helper'

RSpec.describe OAuthSession, type: :model do
  describe 'validations' do
    subject { build(:oauth_session) }

    it { should validate_presence_of(:access_token) }
    it { should validate_presence_of(:state) }
    it { should validate_uniqueness_of(:state) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:active_session) { create(:oauth_session, user: user, expires_at: 1.hour.from_now) }
    let!(:expired_session) { create(:oauth_session, user: user, expires_at: 1.hour.ago) }

    describe '.active' do
      it 'returns only active sessions' do
        expect(OAuthSession.active).to include(active_session)
        expect(OAuthSession.active).not_to include(expired_session)
      end
    end

    describe '.expired' do
      it 'returns only expired sessions' do
        expect(OAuthSession.expired).to include(expired_session)
        expect(OAuthSession.expired).not_to include(active_session)
      end
    end
  end

  describe '#expired?' do
    context 'when session has not expired' do
      let(:session) { build(:oauth_session, expires_at: 1.hour.from_now) }
      
      it 'returns false' do
        expect(session.expired?).to be false
      end
    end

    context 'when session has expired' do
      let(:session) { build(:oauth_session, expires_at: 1.hour.ago) }
      
      it 'returns true' do
        expect(session.expired?).to be true
      end
    end

    context 'when expires_at is nil' do
      let(:session) { build(:oauth_session, expires_at: nil) }
      
      it 'returns false' do
        expect(session.expired?).to be false
      end
    end
  end

  describe '#active?' do
    it 'returns the opposite of expired?' do
      active_session = build(:oauth_session, expires_at: 1.hour.from_now)
      expired_session = build(:oauth_session, expires_at: 1.hour.ago)

      expect(active_session.active?).to be true
      expect(expired_session.active?).to be false
    end
  end

  describe '#has_permission?' do
    let(:session) { build(:oauth_session, permissions: ['read', 'write', 'image_generation']) }

    it 'returns true for permissions the user has' do
      expect(session.has_permission?('read')).to be true
      expect(session.has_permission?(:write)).to be true
      expect(session.has_permission?('image_generation')).to be true
    end

    it 'returns false for permissions the user does not have' do
      expect(session.has_permission?('admin')).to be false
      expect(session.has_permission?('delete')).to be false
    end
  end

  describe '.create_from_workos_response' do
    let(:user) { create(:user) }
    let(:state) { 'test_state_123' }
    let(:access_token) { 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJwZXJtaXNzaW9ucyI6WyJyZWFkIiwid3JpdGUiLCJpbWFnZV9nZW5lcmF0aW9uIl0sImV4cCI6MTY3MDAwMDAwMH0.placeholder' }
    let(:auth_response) do
      double('WorkOS::AuthenticationResponse',
        access_token: access_token,
        refresh_token: 'refresh_token_123'
      )
    end

    before do
      # Mock JWT.decode to return test permissions
      allow(JWT).to receive(:decode).with(access_token, nil, false)
        .and_return([{ 'permissions' => ['read', 'write', 'image_generation'] }])
    end

    it 'creates a new OAuth session with decoded permissions' do
      expect {
        session = OAuthSession.create_from_workos_response(user, auth_response, state)
        
        expect(session.user).to eq(user)
        expect(session.access_token).to eq(access_token)
        expect(session.refresh_token).to eq('refresh_token_123')
        expect(session.permissions).to eq(['read', 'write', 'image_generation'])
        expect(session.state).to eq(state)
        expect(session.expires_at).to be_within(1.minute).of(1.hour.from_now)
      }.to change(OAuthSession, :count).by(1)
    end

    context 'when access token has no permissions' do
      before do
        allow(JWT).to receive(:decode).with(access_token, nil, false)
          .and_return([{}])
      end

      it 'creates session with empty permissions array' do
        session = OAuthSession.create_from_workos_response(user, auth_response, state)
        expect(session.permissions).to eq([])
      end
    end
  end

  describe '.cleanup_expired' do
    let(:user) { create(:user) }
    let!(:active_session) { create(:oauth_session, user: user, expires_at: 1.hour.from_now) }
    let!(:expired_session1) { create(:oauth_session, user: user, expires_at: 1.hour.ago) }
    let!(:expired_session2) { create(:oauth_session, user: user, expires_at: 2.hours.ago) }

    it 'destroys all expired sessions' do
      expect {
        OAuthSession.cleanup_expired
      }.to change(OAuthSession, :count).by(-2)

      expect(OAuthSession.exists?(active_session.id)).to be true
      expect(OAuthSession.exists?(expired_session1.id)).to be false
      expect(OAuthSession.exists?(expired_session2.id)).to be false
    end
  end
end
