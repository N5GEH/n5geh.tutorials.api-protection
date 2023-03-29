local typedefs = require "kong.db.schema.typedefs"

return {
  name = "rbac",
  fields = {
    {
      config = {
        type = "record",
        fields = {
          {tenant_name = {type = "string", required = true, default = "fiware-service"}},
          {include_client_role = {type = "boolean", required = false, default = false}},
          {use_custom_roles = {type = "boolean", required = false, default = false}},
          {read_role = {type = "string", required = false}},
          {write_role = {type = "string", required = false}},
          {admin_role = {type = "string", required = false}},
          {client_name = {type = "string", required = false}}
        }
      }
    }
  }
}
