# frozen_string_literal: true

# This class bridges the Rack environment context to tool instances
class McpContextBridge
  def self.current_context
    Thread.current[:mcp_context] || {}
  end

  def self.set_context(context)
    Thread.current[:mcp_context] = context
  end

  def self.clear_context
    Thread.current[:mcp_context] = nil
  end

  def self.with_context(context)
    old_context = current_context
    set_context(context)
    yield
  ensure
    set_context(old_context)
  end
end