return {
  no_consumer = true,
  fields = {
    tenant_name = { type = "string", required = true , default = "fiware-service" },
    include_client_role = { type = "boolean" , required = false , default = false },
    use_custom_roles = { type = "boolean" , required = false , default = false },
    read_role = { type = "string", required = false},
    write_role = { type = "string", required = false},
    admin_role = { type = "string", required = false},
    client_name = { type = "string", required = false},
  }
}