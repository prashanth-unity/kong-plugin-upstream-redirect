local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.upstream-redirect.access"

local UpstreamRedirectHandler = BasePlugin:extend()

UpstreamRedirectHandler.PRIORITY = 2000


function UpstreamRedirectHandler:new()
    UpstreamRedirectHandler.super.new(self, "upstream-redirect")
end

function UpstreamRedirectHandler:access(conf)
    UpstreamRedirectHandler.super.access(self)
    access.execute(conf)
end


return UpstreamRedirectHandler
