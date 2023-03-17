-- Baseplugin deprecated in version 3.x.x
-- local BasePlugin = require "kong.plugins.base_plugin"
-- local MultiTenancyHandler = BasePlugin:extend()

local MultiTenancyHandler = {
    VERSION = "0.0.2",
    PRIORITY = 10
}

local filter = require("kong.plugins.multi-tenancy.filter")
local kong = kong
local lunajson = require "lunajson"

function MultiTenancyHandler:new()
    MultiTenancyHandler.super.new(self, "multi-tenancy")
end

local function check_tenant(conf)
    local token = kong.request.get_header("Authorization")
    local tenant_name = conf.tenant_name
    kong.log.debug(" ##### Tenant name ", tenant_name)
    local tenant_header = kong.request.get_header(tenant_name)
    if token == nil or tenant_header == nil then
        kong.log.err("Cannot process Headers: ", err)
        return nil, {status = 403, message = "Headers missing !!"}
    end
    local token_decoded = filter.decode(token)
    local jsonparse = lunajson.decode(token_decoded)
    if jsonparse[tenant_name] == nil then
        kong.log.err("fiware-service missing in token")
        return nil, {status = 403, message = "fiware-service missing in token"}
    else
        arraylength = #jsonparse[tenant_name]
        for a = 1, arraylength do
            if jsonparse[tenant_name][a] == tenant_header then
                return true
            end
        end
    end
    return false
end

function MultiTenancyHandler:access(conf)
    -- MultiTenancyHandler.super.access(self)
    local ok, err = check_tenant(conf)
    if not ok then
        return kong.response.error(403, "Permission Denied !")
    else
        return
    end
end

return MultiTenancyHandler
