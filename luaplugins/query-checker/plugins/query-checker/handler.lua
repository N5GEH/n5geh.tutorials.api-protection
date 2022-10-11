local BasePlugin = require "kong.plugins.base_plugin"
local kong = kong

local QueryCheckerHandler = BasePlugin:extend()

function QueryCheckerHandler:new()
    QueryCheckerHandler.super.new(self, "query-checker")
end

local function do_query_check(conf)
    local path, err = kong.request.get_path_with_query()
    if err then
        kong.log.err("Cannot process request path: ", err)
        return EMPTY
    end
    if conf.path == path then 
        return true
    else 
        kong.log.err("Path does not match")
        return nil, { status = 403, message = "Path does not match" }
    end
end 


function QueryCheckerHandler:access(conf)
    QueryCheckerHandler.super.access(self)
    local ok, err = do_query_check(conf)
    if not ok then
        return kong.response.error(err.status, err.message)
    else 
        return
    end
end

return QueryCheckerHandler