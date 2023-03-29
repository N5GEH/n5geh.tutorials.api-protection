local typedefs = require "kong.db.schema.typedefs"

return {
  name = "multi-tenancy",
  fields = {
    { config = {
      type = "record",
      fields = {
        {client_secret = { type = "string", required = true }},
        {client_id = { type = "string", required = true }},
        {discovery = { type = "string", required = true, default = "https://.well-known/openid-configuration" }},
        {introspection_endpoint = { type = "string", required = false }},
        {bearer_only = { type = "string", required = true, default = "no" }},
        {realm = { type = "string", required = true, default = "kong" }},
        {scope = { type = "string", required = true, default = "openid" }},
        {response_type = { type = "string", required = true, default = "code" }},
        {token_endpoint_auth_method = { type = "string", required = true, default = "client_secret_post" }},
        {logout_path = { type = "string", required = false, default = '/logout' }},
      },
    },
  },
    
  }
  
}