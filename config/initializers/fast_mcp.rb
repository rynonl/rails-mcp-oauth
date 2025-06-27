# frozen_string_literal: true

# FastMcp - Model Context Protocol for Rails
# This initializer sets up the MCP middleware in your Rails application.
#
# In Rails applications, you can use:
# - ActionTool::Base as an alias for FastMcp::Tool
# - ActionResource::Base as an alias for FastMcp::Resource
#
# All your tools should inherit from ApplicationTool which already uses ActionTool::Base,
# and all your resources should inherit from ApplicationResource which uses ActionResource::Base.

# Mount the MCP middleware in your Rails application
# You can customize the options below to fit your needs.
require 'fast_mcp'

# Load the MCP authentication middleware
require_relative '../../app/middleware/mcp_auth_middleware'

# Add authentication middleware to the Rails stack
Rails.application.config.middleware.use McpAuthMiddleware

FastMcp.mount_in_rails(
  Rails.application,
  name: Rails.application.class.module_parent_name.underscore.dasherize,
  version: '1.0.0',
  path_prefix: '/mcp', # This is the default path prefix
  messages_route: 'messages', # This is the default route for the messages endpoint
  sse_route: 'sse', # This is the default route for the SSE endpoint
  # OAuth authentication is now handled by McpAuthMiddleware
  authenticate: false, # We handle authentication in middleware
  # Add allowed origins below, it defaults to Rails.application.config.hosts
  allowed_origins: ['localhost', '127.0.0.1', '[::1]', 'example.com', /.*\.example\.com/],
  localhost_only: false # Allow connections from other hosts with proper auth
  # whitelist specific ips to if you want to run on localhost and allow connections from other IPs
  # allowed_ips: ['127.0.0.1', '::1']
) do |server|
  Rails.application.config.after_initialize do
    # FastMcp will automatically discover and register:
    # - All classes that inherit from ApplicationTool (which uses ActionTool::Base)
    # - All classes that inherit from ApplicationResource (which uses ActionResource::Base)
    server.register_tools(*ApplicationTool.descendants)
    server.register_resources(*ApplicationResource.descendants)
    # alternatively, you can register tools and resources manually:
    # server.register_tool(MyTool)
    # server.register_resource(MyResource)
  end
end
