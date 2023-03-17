local typedefs = require "kong.db.schema.typedefs"

return {
  name = "query-checker",
  fields = {
    {
      config = {
        type = "record",
        fields = {
          {path = {type = "string", required = true}}
        }
      }
    }
  }
}
