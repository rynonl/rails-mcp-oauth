require 'rails_helper'

RSpec.describe 'Tool OAuth Context Integration', type: :request do
  let(:user) { create(:user, first_name: 'Test', last_name: 'User', email: 'test@example.com') }
  let(:oauth_session) { create(:oauth_session, user: user, permissions: ['read', 'write']) }

  describe 'Tool context access' do
    it 'provides OAuth context to tools when authenticated' do
      # Test the context bridge directly
      context = {
        current_user: user,
        oauth_session: oauth_session,
        permissions: ['read', 'write'],
        access_token: oauth_session.access_token,
        refresh_token: oauth_session.refresh_token,
        organization_id: user.organization_id
      }

      McpContextBridge.with_context(context) do
        tool = UserInfoTool.new
        
        # Verify the tool has access to OAuth context
        expect(tool.send(:current_user)).to eq(user)
        expect(tool.send(:oauth_session)).to eq(oauth_session)
        expect(tool.send(:user_permissions)).to eq(['read', 'write'])
        expect(tool.send(:access_token)).to eq(oauth_session.access_token)
        expect(tool.send(:organization_id)).to eq(user.organization_id)
      end
    end

    it 'handles permission checking correctly' do
      context = {
        current_user: user,
        oauth_session: oauth_session,
        permissions: ['read'], # Only read permission
        access_token: oauth_session.access_token,
        refresh_token: oauth_session.refresh_token,
        organization_id: user.organization_id
      }

      McpContextBridge.with_context(context) do
        # ImageGenerationTool requires 'image_generation' permission
        tool = ImageGenerationTool.new
        
        expect {
          tool.call(prompt: "test image")
        }.to raise_error(ApplicationTool::PermissionError, /Missing required permissions: image_generation/)
      end
    end

    it 'allows tools without permission requirements' do
      context = {
        current_user: user,
        oauth_session: oauth_session,
        permissions: ['read'],
        access_token: oauth_session.access_token,
        refresh_token: oauth_session.refresh_token,
        organization_id: user.organization_id
      }

      McpContextBridge.with_context(context) do
        # AddTool has no permission requirements
        tool = AddTool.new
        result = tool.call(a: 5, b: 3)
        
        expect(result).to eq({
          content: [
            {
              type: "text",
              text: "8"
            }
          ]
        })
      end
    end
  end
end