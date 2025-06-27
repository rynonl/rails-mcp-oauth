# frozen_string_literal: true

class UserInfoTool < ApplicationTool
  description 'Get current authenticated user information'

  arguments do
    # No arguments needed - uses current OAuth context
  end

  def call
    # This tool demonstrates accessing OAuth context
    if current_user
      {
        content: [
          {
            type: "text",
            text: "Authenticated User Info:\n" +
                  "Name: #{current_user.display_name}\n" +
                  "Email: #{current_user.email}\n" +
                  "WorkOS ID: #{current_user.workos_id}\n" +
                  "Organization: #{organization_id || 'None'}\n" +
                  "Permissions: #{user_permissions.join(', ')}"
          }
        ]
      }
    else
      {
        content: [
          {
            type: "text", 
            text: "No authenticated user found"
          }
        ]
      }
    end
  end
end