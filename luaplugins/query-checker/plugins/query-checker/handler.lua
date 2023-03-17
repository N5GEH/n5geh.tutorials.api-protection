-- Baseplugin deprecated in version 3.x.x
-- local BasePlugin = require "kong.plugins.base_plugin"
-- local QueryCheckerHandler = BasePlugin:extend()

local kong = kong
local SPL_CHR = {"%(", "%)", "%.", "%+", "%-", "%*", "%?", "%[", "%]", "%^", "%$", "%%"}

local QueryCheckerHandler = {
    VERSION = "0.0.2",
    PRIORITY = 8
}

function QueryCheckerHandler:new()
    QueryCheckerHandler.super.new(self, "query-checker")
end

local function do_query_check(conf)
    local path, err = kong.request.get_path_with_query()
    if err then
        kong.log.err("Cannot process request path: ", err)
        return EMPTY
    end
    local conf_path = conf.path
    if string.find(conf.path, "%*") and conf.wilcard_allowed then
        local path_split = stringsplit(conf.path, "*")
        conf_path = replace_spl_path(path_split[1])
        if string.find(path, conf_path) then
            return true
        end
    else
        conf_path = replace_spl_path(conf.path)
        if conf_path == path then
            return true
        end
    end

    if string.find(conf.path, "%*") and conf.wilcard_allowed then
        local path_split = stringsplit(conf.path, "*")
        local path_val = path_split[1]
        if string.find(path_split[1], "%-") then
            path_val = replace_spl(path_split[1], "-", "%-")
        end
        if string.find(path, path_val) then
            return true
        end
    else
        if conf.path == path then
            return true
        end
    end
    kong.log.err("Path does not match")
    return nil, {status = 403, message = "Path does not match"}
end

function replace_spl(str, what, with)
    what = string.gsub(what, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1") -- escape pattern
    with = string.gsub(with, "[%%]", "%%%%") -- escape replacement
    return string.gsub(str, what, with)
end

function replace_spl_path(path)
    for i = 1, #SPL_CHR do
        if string.find(path, SPL_CHR[i]) then
            local s = SPL_CHR[i]
            path = replace_spl(path, s:gsub("%%", ""), SPL_CHR[i])
        end
    end
    return path
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

function QueryCheckerHandler:access(conf)
    -- QueryCheckerHandler.super.access(self)
    local ok, err = do_query_check(conf)
    if not ok then
        return kong.response.error(err.status, err.message)
    else
        return
    end
end

return QueryCheckerHandler
