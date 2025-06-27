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
  
  def initialize(context: {})
    super
    @current_user = context[:current_user]
    @oauth_session = context[:oauth_session] 
    @user_permissions = context[:permissions] || []
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
  
  attr_reader :current_user, :oauth_session, :user_permissions
  
  class PermissionError < StandardError; end
end
