local typedefs = require "kong.db.schema.typedefs"

return {
  name = "multi-tenancy",
  fields = {
    {
      config = {
        type = "record",
        fields = {
          {hash_allowed = {type = "boolean", required = false, default = false}},
          {plus_allowed = {type = "boolean", required = false, default = false}}
        }
      }
    }
  }
}
