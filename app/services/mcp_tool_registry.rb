# frozen_string_literal: true

class McpToolRegistry
  class << self
    def available_tools
      # Return all tools that should be registered
      # For now, we register all tools and handle permissions at execution time
      # This is simpler than dynamic registration and matches Rails patterns better
      [
        AddTool,           # Always available (no permissions required)
        ImageGenerationTool, # Permission-gated (checked at execution time)
        SampleTool         # Existing sample tool
      ]
    end

    # This method could be used for dynamic registration if needed in the future
    def tools_for_permissions(permissions)
      tools = [AddTool] # Always include basic tools
      
      # Add permission-gated tools based on user permissions
      tools << ImageGenerationTool if permissions.include?('image_generation')
      
      # Add more permission-gated tools as needed
      # tools << AdminTool if permissions.include?('admin')
      
      tools
    end

    # Get available tool names for a user (useful for debugging/introspection)
    def available_tool_names_for_user(permissions)
      tools_for_permissions(permissions).map(&:name)
    end
  end
end