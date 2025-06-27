# frozen_string_literal: true

# WorkOS Configuration
# This initializer sets up WorkOS authentication for OAuth integration.
#
# Required environment variables:
# - WORKOS_API_KEY: Your WorkOS API key (secret)
# - WORKOS_CLIENT_ID: Your WorkOS client ID

require 'workos'

WorkOS.configure do |config|
  config.key = Rails.application.credentials.workos_api_key || ENV['WORKOS_API_KEY']
end

# Validate that required credentials are present
unless Rails.application.credentials.workos_api_key || ENV['WORKOS_API_KEY']
  Rails.logger.warn "WorkOS API key not configured. OAuth authentication will not work."
end

unless Rails.application.credentials.workos_client_id || ENV['WORKOS_CLIENT_ID']
  Rails.logger.warn "WorkOS Client ID not configured. OAuth authentication will not work."
end