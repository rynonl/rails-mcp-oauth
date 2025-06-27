require 'rails_helper'

RSpec.describe 'OAuth Integration Flow', type: :request do
  let(:workos_user) do
    double('WorkOS::User',
      id: 'workos_123',
      email: 'integration@example.com',
      first_name: 'Integration',
      last_name: 'Test',
      profile_picture_url: 'https://example.com/avatar.jpg'
    )
  end
  
  let(:auth_response) do
    double('WorkOS::AuthenticationResponse',
      access_token: 'integration_access_token',
      refresh_token: 'integration_refresh_token',
      user: workos_user,
      organization_id: 'org_integration'
    )
  end

  before do
    # Mock WorkOS configuration
    allow(Rails.application.credentials).to receive(:workos_api_key).and_return('test_api_key')
    allow(Rails.application.credentials).to receive(:workos_client_id).and_return('test_client_id')
    
    # Mock JWT decoding
    allow(JWT).to receive(:decode).and_return([{ 'permissions' => ['read', 'write', 'image_generation'] }])
  end

  describe 'Complete OAuth authorization code flow' do
    it 'successfully authenticates a user through the complete flow' do
      # Step 1: Initial authorization request
      allow(WorkOS::UserManagement).to receive(:authorization_url)
        .and_return('https://workos.com/auth?client_id=test&redirect_uri=http://localhost/callback')

      get '/o_auth/authorize', params: {
        client_id: 'test_client_id',
        redirect_uri: 'https://example.com/callback',
        response_type: 'code',
        state: 'client_state'
      }

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('workos.com/auth')
      
      # Verify session state was stored
      oauth_state = session[:oauth_state]
      expect(oauth_state).to be_present
      expect(session[:oauth_client_id]).to eq('test_client_id')
      expect(session[:oauth_redirect_uri]).to eq('https://example.com/callback')

      # Step 2: WorkOS callback with authorization code
      allow(WorkOS::UserManagement).to receive(:authenticate_with_code)
        .and_return(auth_response)

      expect {
        get '/o_auth/callback', params: {
          code: 'workos_auth_code',
          state: oauth_state
        }
      }.to change(User, :count).by(1)
       .and change(OAuthSession, :count).by(1)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to match(/https:\/\/example\.com\/callback\?code=.+&state=#{oauth_state}/)

      # Extract the authorization code from redirect
      auth_code = URI.parse(response.location).query.match(/code=([^&]+)/)[1]
      
      # Verify user was created correctly
      user = User.last
      expect(user.workos_id).to eq('workos_123')
      expect(user.email).to eq('integration@example.com')
      expect(user.first_name).to eq('Integration')
      expect(user.last_name).to eq('Test')
      expect(user.organization_id).to eq('org_integration')

      # Verify OAuth session was created
      oauth_session = OAuthSession.last
      expect(oauth_session.user).to eq(user)
      expect(oauth_session.access_token).to eq('integration_access_token')
      expect(oauth_session.refresh_token).to eq('integration_refresh_token')
      expect(oauth_session.permissions).to eq(['read', 'write', 'image_generation'])
      expect(oauth_session.state).to eq(oauth_state)
      expect(oauth_session.active?).to be true

      # Step 3: Exchange authorization code for access token
      post '/o_auth/token', params: {
        grant_type: 'authorization_code',
        code: auth_code
      }

      expect(response).to have_http_status(:ok)
      
      token_response = JSON.parse(response.body)
      expect(token_response['access_token']).to eq('integration_access_token')
      expect(token_response['token_type']).to eq('Bearer')
      expect(token_response['expires_in']).to be > 0
      expect(token_response['scope']).to eq('read write image_generation')
      expect(token_response['user_id']).to eq('workos_123')
    end

    context 'when user already exists' do
      let!(:existing_user) { create(:user, workos_id: 'workos_123', email: 'old@example.com') }

      it 'reuses existing user but creates new session' do
        allow(WorkOS::UserManagement).to receive(:authorization_url)
          .and_return('https://workos.com/auth')
        allow(WorkOS::UserManagement).to receive(:authenticate_with_code)
          .and_return(auth_response)

        # Start OAuth flow
        get '/o_auth/authorize', params: {
          client_id: 'test_client_id',
          redirect_uri: 'https://example.com/callback',
          response_type: 'code'
        }

        oauth_state = session[:oauth_state]

        # Complete callback
        expect {
          get '/o_auth/callback', params: {
            code: 'workos_auth_code',
            state: oauth_state
          }
        }.not_to change(User, :count)
         .and change(OAuthSession, :count).by(1)

        # Verify existing user was found and used
        oauth_session = OAuthSession.last
        expect(oauth_session.user).to eq(existing_user)
      end
    end

    context 'with different permissions' do
      before do
        allow(JWT).to receive(:decode).and_return([{ 'permissions' => ['read'] }])
      end

      it 'creates session with limited permissions' do
        allow(WorkOS::UserManagement).to receive(:authorization_url)
          .and_return('https://workos.com/auth')
        allow(WorkOS::UserManagement).to receive(:authenticate_with_code)
          .and_return(auth_response)

        get '/o_auth/authorize', params: {
          client_id: 'test_client_id',
          redirect_uri: 'https://example.com/callback',
          response_type: 'code'
        }

        oauth_state = session[:oauth_state]

        get '/o_auth/callback', params: {
          code: 'workos_auth_code',
          state: oauth_state
        }

        oauth_session = OAuthSession.last
        expect(oauth_session.permissions).to eq(['read'])
        expect(oauth_session.has_permission?('read')).to be true
        expect(oauth_session.has_permission?('write')).to be false
        expect(oauth_session.has_permission?('image_generation')).to be false
      end
    end
  end

  describe 'Error handling in OAuth flow' do
    it 'handles WorkOS authentication errors gracefully' do
      allow(WorkOS::UserManagement).to receive(:authorization_url)
        .and_return('https://workos.com/auth')
      allow(WorkOS::UserManagement).to receive(:authenticate_with_code)
        .and_raise(WorkOS::APIError.new('Invalid authorization code'))

      get '/o_auth/authorize', params: {
        client_id: 'test_client_id',
        redirect_uri: 'https://example.com/callback',
        response_type: 'code'
      }

      oauth_state = session[:oauth_state]

      get '/o_auth/callback', params: {
        code: 'invalid_code',
        state: oauth_state
      }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['error']).to eq('Authentication failed')
    end

    it 'prevents CSRF attacks with invalid state' do
      allow(WorkOS::UserManagement).to receive(:authorization_url)
        .and_return('https://workos.com/auth')

      get '/o_auth/authorize', params: {
        client_id: 'test_client_id',
        redirect_uri: 'https://example.com/callback',
        response_type: 'code'
      }

      # Try to use different state in callback
      get '/o_auth/callback', params: {
        code: 'valid_code',
        state: 'malicious_state'
      }

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to eq('Invalid state parameter')
    end
  end
end