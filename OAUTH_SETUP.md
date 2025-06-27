# OAuth Integration with WorkOS AuthKit

This Rails application has been successfully translated from the Node.js/Cloudflare Workers OAuth example to use WorkOS AuthKit for user authentication and permission-based access control for MCP (Model Context Protocol) tools.

## Overview

The OAuth integration provides:
- **User Authentication** via WorkOS AuthKit
- **Permission-based Access Control** for MCP tools
- **Secure Session Management** using Rails sessions and database storage
- **Complete OAuth 2.0 Authorization Code Flow**

## Architecture

### Core Components

1. **User Model** (`app/models/user.rb`)
   - Stores WorkOS user data (workos_id, email, name, organization)
   - Manages relationship with OAuth sessions

2. **OAuthSession Model** (`app/models/o_auth_session.rb`)
   - Stores access tokens, refresh tokens, and user permissions
   - Handles session expiration and validation
   - Decodes JWT tokens to extract permissions

3. **OAuthController** (`app/controllers/o_auth_controller.rb`)
   - Implements OAuth 2.0 authorization code flow
   - Handles authorize, callback, and token endpoints
   - Integrates with WorkOS AuthKit API

4. **MCP Authentication Middleware** (`app/middleware/mcp_auth_middleware.rb`)
   - Protects MCP endpoints with OAuth authentication
   - Validates access tokens for API requests
   - Provides user context to downstream middleware

5. **Permission-based Tools** (`app/tools/`)
   - ApplicationTool with permission checking
   - ImageGenerationTool as example of permission-gated functionality

## Setup Instructions

### 1. WorkOS Configuration

1. Create a WorkOS account at [dashboard.workos.com](https://dashboard.workos.com)
2. Set up AuthKit with your domain
3. Add callback URL: `http://localhost:3000/o_auth/callback` (for development)
4. Note your Client ID and API Key from the dashboard

### 2. Environment Variables

Create a `.env` file or configure Rails credentials:

```bash
# Option 1: Environment variables
WORKOS_API_KEY=your_workos_api_key_here
WORKOS_CLIENT_ID=your_workos_client_id_here

# Option 2: Rails credentials (recommended)
rails credentials:edit
```

Add to credentials:
```yaml
workos_api_key: your_workos_api_key_here
workos_client_id: your_workos_client_id_here
```

### 3. Database Setup

Run the migrations to create user and session tables:

```bash
rails db:migrate
```

### 4. Dependencies

The required gems are already in the Gemfile:
- `workos` - WorkOS Ruby SDK
- `omniauth` - OAuth framework
- `jwt` - JWT token handling

Install with:
```bash
bundle install
```

## OAuth Flow

### 1. Authorization Request
```
GET /o_auth/authorize?client_id=CLIENT_ID&redirect_uri=CALLBACK&response_type=code&state=STATE
```

### 2. User Authentication
- Redirects to WorkOS AuthKit login
- User authenticates with their credentials
- WorkOS redirects back with authorization code

### 3. Token Exchange
```
POST /o_auth/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&code=AUTH_CODE
```

### 4. API Access
Include access token in MCP requests:
```
Authorization: Bearer ACCESS_TOKEN
```

## MCP Integration

### Authentication Middleware

All requests to `/mcp/*` endpoints are automatically protected by OAuth authentication. The middleware:

1. Extracts Bearer token from Authorization header
2. Validates token against active OAuth sessions
3. Provides user context to MCP tools
4. Returns 401 for invalid/expired tokens

### Permission-based Tools

Tools can require specific permissions using the `requires_permission` class method:

```ruby
class MyTool < ApplicationTool
  requires_permission :read, :write
  
  def call
    # Tool implementation
    # Access current user via @current_user
    # Access permissions via @user_permissions
  end
end
```

### Available User Context

In MCP tools, you have access to:
- `@current_user` - User model instance
- `@oauth_session` - Active OAuth session
- `@user_permissions` - Array of permission strings

## API Endpoints

### OAuth Endpoints (Matching Context App)

- `GET /authorize` - Start OAuth flow
- `GET /callback` - Handle WorkOS callback  
- `POST /token` - Exchange code for token

### MCP Endpoints (Protected)

- `GET /mcp/sse` - Server-sent events for MCP
- `POST /mcp/messages` - MCP message endpoint

## Permission System

### Managing Permissions

Permissions are managed through WorkOS dashboard:
1. Navigate to User Management > Roles & Permissions
2. Create roles with specific permissions
3. Assign roles to users/organizations
4. Permissions are automatically included in JWT access tokens

### Example Permissions

- `read` - Read access to data
- `write` - Write access to data
- `image_generation` - Access to AI image generation tools
- `admin` - Administrative access

### Permission-gated Tool Example

The `ImageGenerationTool` demonstrates permission-based access:

```ruby
class ImageGenerationTool < ApplicationTool
  requires_permission :image_generation
  
  def call(prompt:, style: 'realistic')
    # Only users with image_generation permission can use this tool
    # Implementation here
  end
end
```

## Testing

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test suites
bundle exec rspec spec/models/
bundle exec rspec spec/requests/
bundle exec rspec spec/integration/
```

### Test Coverage

The implementation includes comprehensive tests for:
- **Models**: User and OAuthSession validation and behavior
- **Controllers**: OAuth flow endpoints and error handling
- **Integration**: Complete OAuth authorization flow
- **Middleware**: Authentication and authorization

### Mock Data

Tests use FactoryBot factories for creating test data:
- User factory with WorkOS attributes
- OAuthSession factory with tokens and permissions

## Security Features

### CSRF Protection
- State parameter validation prevents CSRF attacks
- Rails CSRF protection for web requests
- Secure token generation using `SecureRandom`

### Token Security
- Access tokens stored securely in database
- Session expiration handling
- Automatic cleanup of expired sessions

### Input Validation
- Comprehensive parameter validation
- Proper error responses for malformed requests
- SQL injection prevention through ActiveRecord

## Troubleshooting

### Common Issues

1. **Invalid WorkOS Configuration**
   - Verify API key and Client ID in credentials/environment
   - Check callback URL matches WorkOS dashboard settings

2. **Permission Errors**
   - Ensure user has required permissions in WorkOS
   - Check JWT token contains expected permissions
   - Verify permission strings match exactly

3. **Authentication Failures**
   - Check access token is included in Authorization header
   - Verify token hasn't expired
   - Ensure session exists in database

### Debugging

Enable detailed logging for OAuth flow:
```ruby
# In development.rb
config.log_level = :debug
```

Check logs for:
- WorkOS API responses
- JWT token decoding
- Session creation/validation
- Permission checks

## Production Deployment

### Environment Variables
Set the following in production:
- `WORKOS_API_KEY` (secret)
- `WORKOS_CLIENT_ID` (public)
- `RAILS_ENV=production`

### Database
Ensure production database includes:
- Users table with WorkOS integration
- OAuth sessions table for token storage
- Proper database backups and security

### Security Considerations
- Use HTTPS for all OAuth redirects
- Set secure callback URLs in WorkOS dashboard
- Configure appropriate CORS settings
- Regular security updates for dependencies

## Differences from Node.js Version

### Key Changes

1. **Session Management**
   - Node.js: In-memory with JWT state
   - Rails: Database-backed with Rails sessions

2. **Authentication Middleware**
   - Node.js: Cloudflare Workers OAuth Provider
   - Rails: Custom Rack middleware

3. **Data Persistence**
   - Node.js: Temporary/stateless
   - Rails: ActiveRecord with SQLite/PostgreSQL

4. **Error Handling**
   - Rails: Comprehensive error responses and logging
   - Better validation and security features

5. **Testing**
   - Rails: Full RSpec test suite with factories
   - More comprehensive integration testing

### Benefits of Rails Version

- **Persistent User Data**: Users and sessions stored in database
- **Better Security**: Rails CSRF protection and validation
- **Easier Maintenance**: Rails conventions and structure
- **Comprehensive Testing**: Full test coverage with RSpec
- **Scalability**: Database-backed sessions for multiple instances

## Support

For issues related to:
- **WorkOS**: Check [WorkOS documentation](https://workos.com/docs)
- **Rails OAuth**: Refer to this implementation and tests
- **MCP Integration**: See fast-mcp gem documentation

This implementation provides a robust, secure, and well-tested OAuth integration for Rails applications using WorkOS AuthKit.