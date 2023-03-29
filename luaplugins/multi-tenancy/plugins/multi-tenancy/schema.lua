local typedefs = require "kong.db.schema.typedefs"

return {
  name = "multi-tenancy",
  fields = {
    {
      config = {
        type = "record",
        fields = {
          {
            tenant_name = {type = "string", required = true, default = "fiware-service"}
          }
        }
      }
    }
  }
}
