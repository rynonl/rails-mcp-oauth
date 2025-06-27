require 'rails_helper'

RSpec.describe "OAuth", type: :request do
  before do
    # Mock WorkOS configuration
    allow(Rails.application.credentials).to receive(:workos_api_key).and_return('test_api_key')
    allow(Rails.application.credentials).to receive(:workos_client_id).and_return('test_client_id')
  end

  describe "GET /o_auth/authorize" do
    let(:valid_params) do
      {
        client_id: 'test_client_id',
        redirect_uri: 'https://example.com/callback',
        response_type: 'code',
        state: 'test_state'
      }
    end

    context 'with valid parameters' do
      before do
        allow(WorkOS::UserManagement).to receive(:authorization_url).and_return('https://workos.com/auth')
      end

      it 'redirects to WorkOS authorization URL' do
        get '/o_auth/authorize', params: valid_params
        
        expect(response).to have_http_status(:redirect)
        expect(response.location).to eq('https://workos.com/auth')
      end

      it 'stores OAuth state and client info in session' do
        get '/o_auth/authorize', params: valid_params
        
        expect(session[:oauth_state]).to be_present
        expect(session[:oauth_client_id]).to eq('test_client_id')
        expect(session[:oauth_redirect_uri]).to eq('https://example.com/callback')
      end
    end

    context 'with missing required parameters' do
      it 'returns bad request for missing client_id' do
        get '/o_auth/authorize', params: valid_params.except(:client_id)
        
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to include('Missing required parameters')
      end

      it 'returns bad request for missing redirect_uri' do
        get '/o_auth/authorize', params: valid_params.except(:redirect_uri)
        
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to include('Missing required parameters')
      end

      it 'returns bad request for invalid response_type' do
        get '/o_auth/authorize', params: valid_params.merge(response_type: 'token')
        
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('Only authorization code flow is supported')
      end
    end
  end

  describe "GET /o_auth/callback" do
    let(:workos_user) do
      double('WorkOS::User',
        id: 'workos_123',
        email: 'test@example.com',
        first_name: 'Test',
        last_name: 'User',
        profile_picture_url: 'https://example.com/avatar.jpg'
      )
    end
    
    let(:auth_response) do
      double('WorkOS::AuthenticationResponse',
        access_token: 'access_token_123',
        refresh_token: 'refresh_token_123',
        user: workos_user,
        organization_id: 'org_123'
      )
    end

    before do
      session[:oauth_state] = 'test_state'
      session[:oauth_redirect_uri] = 'https://example.com/callback'
      
      # Mock JWT decoding
      allow(JWT).to receive(:decode).and_return([{ 'permissions' => ['read', 'write'] }])
    end

    context 'with valid callback' do
      before do
        allow(WorkOS::UserManagement).to receive(:authenticate_with_code).and_return(auth_response)
      end

      it 'creates user and OAuth session' do
        expect {
          get '/o_auth/callback', params: { code: 'auth_code_123', state: 'test_state' }
        }.to change(User, :count).by(1)
         .and change(OAuthSession, :count).by(1)

        user = User.last
        expect(user.workos_id).to eq('workos_123')
        expect(user.email).to eq('test@example.com')

        oauth_session = OAuthSession.last
        expect(oauth_session.user).to eq(user)
        expect(oauth_session.access_token).to eq('access_token_123')
        expect(oauth_session.permissions).to eq(['read', 'write'])
      end

      it 'redirects to client callback URL with authorization code' do
        get '/o_auth/callback', params: { code: 'auth_code_123', state: 'test_state' }
        
        expect(response).to have_http_status(:redirect)
        expect(response.location).to match(/https:\/\/example\.com\/callback\?code=.+&state=test_state/)
      end

      context 'when user already exists' do
        let!(:existing_user) { create(:user, workos_id: 'workos_123') }

        it 'does not create a new user' do
          expect {
            get '/o_auth/callback', params: { code: 'auth_code_123', state: 'test_state' }
          }.not_to change(User, :count)
        end
      end
    end

    context 'with invalid state' do
      it 'returns bad request' do
        get '/o_auth/callback', params: { code: 'auth_code_123', state: 'invalid_state' }
        
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('Invalid state parameter')
      end
    end

    context 'with missing authorization code' do
      it 'returns bad request' do
        get '/o_auth/callback', params: { state: 'test_state' }
        
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('Missing authorization code')
      end
    end

    context 'when WorkOS authentication fails' do
      before do
        allow(WorkOS::UserManagement).to receive(:authenticate_with_code)
          .and_raise(WorkOS::APIError.new('Invalid code'))
      end

      it 'returns unauthorized' do
        get '/o_auth/callback', params: { code: 'invalid_code', state: 'test_state' }
        
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('Authentication failed')
      end
    end
  end

  describe "POST /o_auth/token" do
    let(:user) { create(:user) }
    let(:oauth_session) { create(:oauth_session, user: user, expires_at: 1.hour.from_now) }

    before do
      session[:authorization_code] = 'auth_code_123'
      session[:oauth_session_id] = oauth_session.id
    end

    context 'with valid token request' do
      it 'returns access token details' do
        post '/o_auth/token', params: {
          grant_type: 'authorization_code',
          code: 'auth_code_123'
        }
        
        expect(response).to have_http_status(:ok)
        
        token_response = JSON.parse(response.body)
        expect(token_response['access_token']).to eq(oauth_session.access_token)
        expect(token_response['token_type']).to eq('Bearer')
        expect(token_response['expires_in']).to be > 0
        expect(token_response['scope']).to eq(oauth_session.permissions.join(' '))
        expect(token_response['user_id']).to eq(user.workos_id)
      end
    end

    context 'with invalid grant type' do
      it 'returns bad request' do
        post '/o_auth/token', params: {
          grant_type: 'client_credentials',
          code: 'auth_code_123'
        }
        
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('unsupported_grant_type')
      end
    end

    context 'with missing authorization code' do
      it 'returns bad request' do
        post '/o_auth/token', params: {
          grant_type: 'authorization_code'
        }
        
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('Missing authorization code')
      end
    end

    context 'with invalid authorization code' do
      it 'returns bad request' do
        post '/o_auth/token', params: {
          grant_type: 'authorization_code',
          code: 'invalid_code'
        }
        
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('invalid_grant')
      end
    end

    context 'with expired session' do
      let(:expired_session) { create(:oauth_session, user: user, expires_at: 1.hour.ago) }

      before do
        session[:oauth_session_id] = expired_session.id
      end

      it 'returns unauthorized' do
        post '/o_auth/token', params: {
          grant_type: 'authorization_code',
          code: 'auth_code_123'
        }
        
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('Session expired')
      end
    end
  end
end
