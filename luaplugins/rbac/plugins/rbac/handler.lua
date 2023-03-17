-- Baseplugin deprecated in version 3.x.x
-- local BasePlugin = require "kong.plugins.base_plugin"
-- local RbacHandler = BasePlugin:extend()

local filter = require("kong.plugins.rbac.filter")
local kong = kong
local lunajson = require "lunajson"

local RbacHandler = {
    VERSION = "0.0.2",
    PRIORITY = 9
}

function RbacHandler:new()
    RbacHandler.super.new(self, "rbac")
end

local function check_rbac(conf)
    local token = kong.request.get_header("Authorization")
    local tenant_name = conf.tenant_name
    local custom_roles_flag = conf.use_custom_roles
    local include_client_role_flag = conf.include_client_role
    local request_method = kong.request.get_method()
    local tenant_header = kong.request.get_header(tenant_name)
    local client_name = conf.client_name

    local token_decoded = filter.decode(token)
    local jsonparse = lunajson.decode(token_decoded)
    local token_realm_roles = jsonparse["realm_access"]["roles"]
    local token_client_roles = nil

    if include_client_role_flag == true and client_name ~= nil then
        if jsonparse["resource_access"][client_name] == nil then
            return nil, {status = 403, message = "Client roles missing in token"}
        end
        token_client_roles = jsonparse["resource_access"][client_name]["roles"]
        if token_client_roles == nil then
            kong.log.err("Client access roles are missing !!!")
            return nil, {status = 403, message = "roles missing in token"}
        end
    end

    if token_realm_roles == nil then
        kong.log.err("Realm access roles are missing !!!")
        return nil, {status = 403, message = "roles missing in token"}
    end
       
    local role = nil
    if custom_roles_flag == false then
        if tenant_header == nil then 
            kong.log.err("tenant header is missing !!!")
            return nil, {status = 403, message = "tenant header missing for rbac"}
        end 
        role = tenant_header .. "_admin"
        if request_method == "GET" then
            role = tenant_header .. "_read"
        elseif request_method == "POST" or request_method == "PUT" or request_method == "PATCH" then
            role = tenant_header .. "_write"
        end
    else
        role = conf.admin_role
        if request_method == "GET" then
            role = conf.read_role
        elseif request_method == "POST" or request_method == "PUT" or request_method == "PATCH" then
            role = conf.write_role
        end
    end

    if include_client_role_flag and token_client_roles ~= nil then
        local arraylength = #token_client_roles
        for a = 1, arraylength do
            if role == token_client_roles[a] then
                return true
            end
        end
    else
        local arraylength = #token_realm_roles
        for a = 1, arraylength do
            if role == token_realm_roles[a] then
                return true
            end
        end
    end
    return false
end

function RbacHandler:access(conf)
    -- RbacHandler.super.access(self)
    local ok, err = check_rbac(conf)
    if not ok then
        return kong.response.error(403, "Permission denied !")
    else
        return
    end
end

return RbacHandler
