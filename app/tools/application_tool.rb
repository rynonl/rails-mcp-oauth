# frozen_string_literal: true

class ApplicationTool < ActionTool::Base
  # Permission-based access control for MCP tools
  
  class << self
    attr_accessor :required_permissions
    
    def requires_permission(*permissions)
      self.required_permissions = permissions.map(&:to_s)
    end
    
    def permission_required?
      required_permissions.present?
    end
  end
  
  def initialize(*args, **kwargs)
    # Remove context from kwargs before passing to super
    context = kwargs.delete(:context) || {}
    super(*args, **kwargs)
    
    # Extract context from middleware thread-local storage or passed parameters
    mcp_context = McpContextBridge.current_context.merge(context)
    @current_user = mcp_context[:current_user]
    @oauth_session = mcp_context[:oauth_session] 
    @user_permissions = mcp_context[:permissions] || []
    @access_token = mcp_context[:access_token]
    @refresh_token = mcp_context[:refresh_token]
    @organization_id = mcp_context[:organization_id]
  end
  
  def call(*args)
    # Check permissions before executing the tool
    if self.class.permission_required?
      missing_permissions = self.class.required_permissions - @user_permissions
      
      if missing_permissions.any?
        raise PermissionError, "Missing required permissions: #{missing_permissions.join(', ')}"
      end
    end
    
    super
  end
  
  private
  
  attr_reader :current_user, :oauth_session, :user_permissions, :access_token, :refresh_token, :organization_id
  
  class PermissionError < StandardError; end
end
