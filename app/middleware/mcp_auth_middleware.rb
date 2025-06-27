# frozen_string_literal: true

require_relative 'mcp_context_bridge'

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
        
        # Add context for MCP tools (matching context app props exactly)
        context = {
          current_user: auth_result[:user],
          permissions: auth_result[:permissions],
          access_token: auth_result[:access_token],
          organization_id: auth_result[:organization_id]
        }
        
        env['mcp.context'] = context
        
        # Set context in thread-local storage for tool access
        McpContextBridge.set_context(context)
      else
        return unauthorized_response(auth_result[:error])
      end
    end

    result = @app.call(env)
    
    # Clear context after request
    McpContextBridge.clear_context if mcp_endpoint?(Rack::Request.new(env).path)
    
    result
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

    access_token = auth_header.split(' ', 2).last
    
    # Validate JWT and extract claims (WorkOS stateless approach)
    begin
      # Decode JWT without verification for now (in production, verify signature)
      token_data = JWT.decode(access_token, nil, false).first
      
      # Check token expiration
      exp = token_data['exp']
      if exp && Time.at(exp) <= Time.current
        return { success: false, error: 'Access token expired' }
      end
      
      # Extract user info from JWT
      user_id = token_data['sub']
      permissions = token_data['permissions'] || []
      organization_id = token_data['org']
      
      # Find or create user from WorkOS ID (minimal database usage)
      user = User.find_by(workos_id: user_id)
      unless user
        # Could fetch user details from WorkOS API if needed
        return { success: false, error: 'User not found' }
      end

      {
        success: true,
        user: user,
        access_token: access_token,
        permissions: permissions,
        organization_id: organization_id
      }
    rescue JWT::DecodeError => e
      Rails.logger.error "JWT decode error: #{e.message}"
      { success: false, error: 'Invalid access token format' }
    end
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