-- Baseplugin deprecated in version 3.x.x
-- local BasePlugin = require "kong.plugins.base_plugin"
-- local ScopeCheckerHandler = BasePlugin:extend()

local filter = require("kong.plugins.scope-checker.filter")
local kong = kong
local lunajson = require "lunajson"

local ScopeCheckerHandler = {
    VERSION = "0.0.2",
    PRIORITY = 7
}

function ScopeCheckerHandler:new()
    ScopeCheckerHandler.super.new(self, "scope-checker")
end

local function scoper_check(conf)
    local token = kong.request.get_header("Authorization")
    local hash_allowed = conf.hash_allowed
    local plus_allowed = conf.plus_allowed
    local scope_header = kong.request.get_header("scopes")
    if token == nil or scope_header == nil then
        kong.log.err("Cannot process Headers: ", err)
        return nil, {status = 403, message = "Headers missing !!"}
    end
    local token_decoded = filter.decode(token)
    local jsonparse = lunajson.decode(token_decoded)
    if jsonparse["scopes"] == nil then
        kong.log.err("scope missing in token")
        return nil, {status = 403, message = "scope missing in token"}
    else
        local result = check_scope_access(jsonparse["scopes"], scope_header, hash_allowed, plus_allowed)
        if result == true then
            return true
        end
    end
    return false
end

function stringsplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    local i = 1
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

function contains(table, val)
    for i = 1, #table do
        if table[i] == val then
            return true
        end
    end
    return false
end

function check_scope_access(token_scope, scope_header, hash_allowed, plus_allowed)
    if string.find(token_scope, "%(") then
        return check_multi_scoped(token_scope, scope_header, hash_allowed, plus_allowed)
    else
        return check_single_scope(token_scope, scope_header, hash_allowed, plus_allowed)
    end
end

function check_single_scope(token_scope, scope_header, hash_allowed, plus_allowed)
    local scope_header_split = stringsplit(scope_header, "//")
    local token_scope_split = stringsplit(token_scope, "//")
    if #scope_header_split == #token_scope_split and contains(token_scope_split, "#") == false then
        local match = 0
        for j = 1, #token_scope_split do
            if token_scope_split[j] == scope_header_split[j] then
                match = match + 1
            elseif token_scope_split[j] == "+" and plus_allowed then
                match = match + 1
            else
                return nil, {status = 403, message = "scope permission denied"}
            end
        end
        if match == #token_scope_split then
            return true
        end
    elseif contains(token_scope_split, "#") == true and hash_allowed then
        local match = 0
        for j = 1, #token_scope_split - 1 do
            if token_scope_split[j] == scope_header_split[j] then
                match = match + 1
            else
                return nil, {status = 403, message = "scope permission denied"}
            end
        end
        if match == #token_scope_split - 1 then
            return true
        end
    end
    return nil, {status = 403, message = "no scope permission matched"}
end

function check_multi_scoped(token_scope, scope_header, hash_allowed, plus_allowed)
    if string.find(token_scope, "%|") or string.find(token_scope, "%,") then
        local or_scopes = ""
        if string.find(token_scope, "%|") then
            or_scopes = stringsplit(token_scope, "|")
        else
            or_scopes = stringsplit(token_scope, ",")
        end
        for i = 1, #or_scopes do
            local and_scope = or_scopes[i]
            local flag = check_and_scopes(and_scope, scope_header)
            if flag == true then
                return true
            end
        end
        return false
    else
        return check_and_scopes(token_scope, scope_header)
    end
end

function check_and_scopes(and_scope, scope_header)
    if string.find(and_scope, "%/") == false and string.find(scope_header, "%/") == true then
        and_scope = "%/" .. and_scope
    end
    if string.find(and_scope, "%(") then
        and_scope = and_scope:gsub("%(", "")
        and_scope = and_scope:gsub("%)", "")
    end
    return and_scope == scope_header
end

function ScopeCheckerHandler:access(conf)
    -- ScopeCheckerHandler.super.access(self)
    local ok, err = scoper_check(conf)
    if not ok then
        return kong.response.error(403, "Permission Denied !")
    else
        return
    end
end

return ScopeCheckerHandler
