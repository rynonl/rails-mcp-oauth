class OAuthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:token]
  before_action :validate_oauth_params, only: [:authorize]

  def authorize
    # Generate unique state for CSRF protection
    state = SecureRandom.urlsafe_base64(32)
    session[:oauth_state] = state
    session[:oauth_client_id] = params[:client_id]
    session[:oauth_redirect_uri] = params[:redirect_uri]

    # Redirect to WorkOS authorization URL
    auth_url = WorkOS::UserManagement.authorization_url(
      provider: 'authkit',
      client_id: workos_client_id,
      redirect_uri: callback_url,
      state: state
    )

    redirect_to auth_url, allow_other_host: true
  end

  def callback
    # Validate state to prevent CSRF attacks
    unless params[:state] == session[:oauth_state]
      render json: { error: 'Invalid state parameter' }, status: :bad_request
      return
    end

    unless params[:code]
      render json: { error: 'Missing authorization code' }, status: :bad_request
      return
    end

    begin
      # Exchange code for access token
      auth_response = WorkOS::UserManagement.authenticate_with_code(
        client_id: workos_client_id,
        code: params[:code]
      )

      # Find or create user (minimal database usage)
      user = User.from_workos_user(auth_response.user, auth_response.organization_id)

      # Store tokens in session for OAuth flow completion
      # In WorkOS pattern, we primarily use the JWT access token, not database sessions
      session[:workos_access_token] = auth_response.access_token
      session[:workos_refresh_token] = auth_response.refresh_token
      session[:workos_user_id] = user.workos_id

      # Generate authorization code for MCP client
      authorization_code = SecureRandom.urlsafe_base64(32)
      session[:authorization_code] = authorization_code

      # Redirect back to original client
      redirect_uri = session[:oauth_redirect_uri]
      if redirect_uri
        redirect_to "#{redirect_uri}?code=#{authorization_code}&state=#{session[:oauth_state]}", allow_other_host: true
      else
        # Return access token directly (stateless approach)
        render json: { 
          access_token: auth_response.access_token,
          user: user.as_json(except: [:created_at, :updated_at])
        }
      end

    rescue WorkOS::APIError => e
      Rails.logger.error "WorkOS authentication error: #{e.message}"
      render json: { error: 'Authentication failed' }, status: :unauthorized
    end
  end

  def token
    unless params[:grant_type] == 'authorization_code'
      render json: { error: 'unsupported_grant_type' }, status: :bad_request
      return
    end

    unless params[:code]
      render json: { error: 'Missing authorization code' }, status: :bad_request
      return
    end

    # Validate authorization code
    if session[:authorization_code] != params[:code]
      render json: { error: 'invalid_grant' }, status: :bad_request
      return
    end

    # Return stored WorkOS access token (stateless approach)
    access_token = session[:workos_access_token]
    unless access_token
      render json: { error: 'Session expired' }, status: :unauthorized
      return
    end

    # Decode JWT to get expiration and permissions
    begin
      token_data = JWT.decode(access_token, nil, false).first
      expires_in = token_data['exp'] ? (token_data['exp'] - Time.current.to_i) : 3600
      permissions = token_data['permissions'] || []
      
      render json: {
        access_token: access_token,
        token_type: 'Bearer',
        expires_in: expires_in,
        scope: permissions.join(' '),
        user_id: session[:workos_user_id]
      }
    rescue JWT::DecodeError
      render json: { error: 'Invalid token' }, status: :unauthorized
    end
  end

  private

  def validate_oauth_params
    required_params = %w[client_id redirect_uri response_type]
    missing_params = required_params.select { |param| params[param].blank? }

    if missing_params.any?
      render json: { error: "Missing required parameters: #{missing_params.join(', ')}" }, 
             status: :bad_request
      return
    end

    unless params[:response_type] == 'code'
      render json: { error: 'Only authorization code flow is supported' }, status: :bad_request
      return
    end
  end

  def workos_api_key
    Rails.application.credentials.workos_api_key || ENV['WORKOS_API_KEY']
  end

  def workos_client_id
    Rails.application.credentials.workos_client_id || ENV['WORKOS_CLIENT_ID']
  end

  def callback_url
    request.base_url + '/callback'
  end
end
