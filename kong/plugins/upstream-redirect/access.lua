local url = require "net.url"
local _M = {}

local function get_host(host)
    local u = url.parse(host)
    local host = u.host
    if u.port then
        host = host .. ":" .. u.port
    end
    return host
end

local function get_host_path(url, upstream_host)
    url = url or ""
    local path_index = url:find("[^/]/[^/]")

    if not path_index then
        if upstream_host:find("[^/]/[^/]") == nil and upstream_host:sub(#upstream_host) ~= "/" then
            return upstream_host, "/"
        end

        return upstream_host, ""
    end

    if upstream_host:sub(#upstream_host) == "/" then
        upstream_host = upstream_host:sub(1, -2)
    end

    local path = url:sub(path_index + 1)
    return upstream_host, path
end

function _M.execute(conf)
    local header_value = ngx.req.get_headers()[conf.upstream_host_header]
    if header_value then
        local upstream_host = get_host(header_value)
        local host, path = get_host_path(ngx.ctx.upstream_url, header_value)
        ngx.req.set_header("host", upstream_host)
        ngx.var.upstream_host = upstream_host
        ngx.var.upstream_scheme = url.parse(header_value).scheme
        ngx.ctx.upstream_url = host .. path

        -- calculate the $upstream_uri based on the new $upstream_url
        local _, uri = get_host_path(ngx.ctx.upstream_url, header_value)
        ngx.var.upstream_uri = uri

        -- store the header value in $upstream_redirect_host_header for nginx to inspect.
        ngx.ctx.upstream_redirect_host_header = header_value
    end
end

return _M
