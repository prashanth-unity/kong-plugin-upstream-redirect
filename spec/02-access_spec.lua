local path = require "pl.path"
local helpers = require "spec.helpers"
local access = require "kong.plugins.upstream-redirect.access"

local UPSTREAM_HOST_HEADER = "x-upstream-host"

describe("Plugin: upstream-redirect (access)", function()
    local client

    setup(function()
        -- Register an API
        local api = assert(helpers.dao.apis:insert {
            name = "example-api",
            hosts = { "example.com" },
            upstream_url = "http://example.com"
        })

        -- Insert plugin on API
        assert(helpers.dao.plugins:insert {
            api_id = api.id,
            name = "upstream-redirect",
            config = {
                upstream_host_header = UPSTREAM_HOST_HEADER
            }

        })

        -- Start Kong with custom nginx.conf and make sure plugin is loaded
        assert(helpers.start_kong {
            custom_plugins="upstream-redirect",
            nginx_conf=path.abspath("custom_nginx.template")
        })
    end)

    teardown(function()
        helpers.stop_kong()
    end)

    before_each(function()
        client = helpers.proxy_client()
    end)

    after_each(function()
        if client then client:close() end
    end)

    describe("request", function()
        it("proxies the request to the 'UPSTREAM_HOST_HEADER' header value", function()
            local r = assert(client:send {
                method = "GET",
                path = "/request",
                headers = {
                    host = "example.com",
                    accept = "application/json",
                    [UPSTREAM_HOST_HEADER] = "http://mockbin.com",
                }
            })
            assert.response(r).has.status(200)
            assert.response(r).has.jsonbody()
        end)
    end)
end)

describe("Plugin: upstream-redirect (access unit)", function()

    setup(function()
        -- Mock ngx for the test context
        _G.ngx = {
            ctx = {},
            var = {},
            req = { headers = {} }
        }
        function ngx.req.set_header(name, value)
            _G.ngx.req.headers[name] = value
        end
        function ngx.req.get_headers()
            return _G.ngx.req.headers
        end

    end)

    it("should replace the host", function()
        local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
        ngx.req.set_header(UPSTREAM_HOST_HEADER, "https://example.com")
        ngx.ctx.upstream_url = "https://to-be-replaced.com/some/path"

        access.execute(conf)
        assert.equal("https://example.com/some/path", ngx.ctx.upstream_url)
    end)

    it("should replace the scheme", function()
        local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
        ngx.req.set_header(UPSTREAM_HOST_HEADER, "http://example.com")
        ngx.ctx.upstream_url = "https://to-be-replaced.com/some/path"

        access.execute(conf)
        assert.equal("http://example.com/some/path", ngx.ctx.upstream_url)
    end)

    it("should replace the host and port", function()
        local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
        ngx.req.set_header(UPSTREAM_HOST_HEADER, "https://example.com:8000")
        ngx.ctx.upstream_url = "https://to-be-replaced.com/some/path"

        access.execute(conf)
        assert.equal("https://example.com:8000/some/path", ngx.ctx.upstream_url)
    end)

    it("should update the host header", function()
        local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
        ngx.req.set_header(UPSTREAM_HOST_HEADER, "https://example.com")
        ngx.ctx.upstream_url = "https://to-be-replaced.com/some/path"
        ngx.var.upstream_host = "to-be-replaced.com"

        access.execute(conf)
        assert.equal("example.com", ngx.var.upstream_host)
    end)

    it("should replace the upstream_uri", function()
        local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
        ngx.req.set_header(UPSTREAM_HOST_HEADER, "https://example.com/path1")
        ngx.ctx.upstream_url = "https://to-be-replaced.com/path2"

        access.execute(conf)
        assert.equal("/path1/path2", ngx.var.upstream_uri)
    end)

    it("should maintain query parameters", function()
        local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
        ngx.req.set_header(UPSTREAM_HOST_HEADER, "https://example.com")
        ngx.ctx.upstream_url = "https://to-be-replaced.com/some/path?foo=bar&baz=qux"

        access.execute(conf)
        assert.equal("https://example.com/some/path?foo=bar&baz=qux", ngx.ctx.upstream_url)
    end)

    it("should support numerical paths", function()
        local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
        ngx.req.set_header(UPSTREAM_HOST_HEADER, "https://example.com")
        ngx.ctx.upstream_url = "https://to-be-replaced.com/1234"

        access.execute(conf)
        assert.equal("https://example.com/1234", ngx.ctx.upstream_url)
    end)

    it("should maintain fragment identifier", function()
        local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
        ngx.req.set_header(UPSTREAM_HOST_HEADER, "https://example.com")
        ngx.ctx.upstream_url = "https://to-be-replaced.com/path#top"

        access.execute(conf)
        assert.equal("https://example.com/path#top", ngx.ctx.upstream_url)
    end)

    it("should maintain upstream host path", function()
        local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
        ngx.req.set_header(UPSTREAM_HOST_HEADER, "https://example.com/path1/")
        ngx.ctx.upstream_url = "https://to-be-replaced.com/path2"

        access.execute(conf)
        assert.equal("https://example.com/path1/path2", ngx.ctx.upstream_url)
    end)

    it("should ignore trailing slashes on the upstream host path", function()
        local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
        ngx.req.set_header(UPSTREAM_HOST_HEADER, "https://example.com/path1/")
        ngx.ctx.upstream_url = "https://to-be-replaced.com/path2"

        access.execute(conf)
        assert.equal("https://example.com/path1/path2", ngx.ctx.upstream_url)
    end)

    it("should ensure there's a trailing slash if no path", function()
        local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
        ngx.req.set_header(UPSTREAM_HOST_HEADER, "https://example.com")
        ngx.ctx.upstream_url = "https://to-be-replaced.com"

        access.execute(conf)
        assert.equal("https://example.com/", ngx.ctx.upstream_url)
    end)

    describe("with just the upstream host having a trailing slash", function()
        it("should ensure that the result has only one trailing slash", function()
            local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
            ngx.req.set_header(UPSTREAM_HOST_HEADER, "https://example.com/")
            ngx.ctx.upstream_url = "https://to-be-replaced.com"

            access.execute(conf)
            assert.equal("https://example.com/", ngx.ctx.upstream_url)
        end)
    end)

    describe("with just the upstream url having a trailing slash", function()
        it("should ensure that the result has only one trailing slash", function()
            local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
            ngx.req.set_header(UPSTREAM_HOST_HEADER, "https://example.com")
            ngx.ctx.upstream_url = "https://to-be-replaced.com/"

            access.execute(conf)
            assert.equal("https://example.com/", ngx.ctx.upstream_url)
        end)
    end)

    describe("with both upstream url and upstream host having a trailing slash", function()
        it("should ensure that the result has only one trailing slash", function()
            local conf = { upstream_host_header = UPSTREAM_HOST_HEADER }
            ngx.req.set_header(UPSTREAM_HOST_HEADER, "https://example.com/")
            ngx.ctx.upstream_url = "https://to-be-replaced.com/"

            access.execute(conf)
            assert.equal("https://example.com/", ngx.ctx.upstream_url)
        end)
    end)
end)
