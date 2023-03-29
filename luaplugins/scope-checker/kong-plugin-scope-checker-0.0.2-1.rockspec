local plugin_name = "scope-checker"
local package_name = "kong-plugin-" .. plugin_name
local package_version = "0.0.2"
local rockspec_revision = "1"

local github_account_name = "Kong"
local github_repo_name = "kong-plugin"
local git_checkout = package_version == "dev" and "master" or package_version


package = package_name
version = package_version .. "-" .. rockspec_revision
supported_platforms = { "linux", "macosx" }
source = {
  url = "https://github.com/guruhebbar2"
}
description = {
  summary = "Kong is a scalable and customizable API Management Layer built on top of Nginx.",
  license = "Apache 2.0",
}

dependencies = {
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins."..plugin_name..".handler"] = "plugins/"..plugin_name.."/handler.lua",
    ["kong.plugins."..plugin_name..".schema"] = "plugins/"..plugin_name.."/schema.lua",
    ["kong.plugins."..plugin_name..".filter"] = "plugins/"..plugin_name.."/filter.lua",
  }
}
