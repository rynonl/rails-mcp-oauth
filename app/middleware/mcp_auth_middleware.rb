# frozen_string_literal: true

class McpAuthMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # Only apply authentication to MCP endpoints
    if mcp_endpoint?(request.path)
      auth_result = authenticate_request(request)
      
      if auth_result[:success]
        # Add user and session info to env for downstream middleware
        env['mcp.current_user'] = auth_result[:user]
        env['mcp.oauth_session'] = auth_result[:session]
        env['mcp.permissions'] = auth_result[:permissions]
      else
        return unauthorized_response(auth_result[:error])
      end
    end

    @app.call(env)
  end

  private

  def mcp_endpoint?(path)
    path.start_with?('/mcp/')
  end

  def authenticate_request(request)
    # Check for Authorization header
    auth_header = request.get_header('HTTP_AUTHORIZATION')
    
    unless auth_header&.start_with?('Bearer ')
      return { success: false, error: 'Missing or invalid Authorization header' }
    end

    token = auth_header.split(' ', 2).last
    
    # Find active OAuth session with this access token
    oauth_session = OAuthSession.joins(:user)
                                .where(access_token: token)
                                .active
                                .first

    unless oauth_session
      return { success: false, error: 'Invalid or expired access token' }
    end

    {
      success: true,
      user: oauth_session.user,
      session: oauth_session,
      permissions: oauth_session.permissions
    }
  rescue StandardError => e
    Rails.logger.error "MCP Authentication error: #{e.message}"
    { success: false, error: 'Authentication failed' }
  end

  def unauthorized_response(error_message)
    [
      401,
      {
        'Content-Type' => 'application/json',
        'WWW-Authenticate' => 'Bearer realm="MCP Server"'
      },
      [{ error: 'unauthorized', message: error_message }.to_json]
    ]
  end
end