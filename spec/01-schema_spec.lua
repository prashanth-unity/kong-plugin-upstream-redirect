local schemas = require "kong.dao.schemas_validation"
local plugin_schema = require "kong.plugins.upstream-redirect.schema"
local validate_entity = schemas.validate_entity

describe("Plugin: upstream-redirect (schema)", function()
    it("should succeed on valid 'upstream_host_header'", function()
        local ok, err = validate_entity({ upstream_host_header = "Upstream-Host" }, plugin_schema)
        assert.is_nil(err)
        assert.True(ok)
    end)

    it("should fail on empty string 'upstream_host_header'", function()
        local ok, err = validate_entity({ upstream_host_header = "" }, plugin_schema)
        assert.are.same({["upstream_host_header"] = 'upstream_host_header is required' }, err)
        assert.False(ok)
    end)

    it("should fail on non-string 'upstream_host_header'", function()
        local ok, err = validate_entity({ upstream_host_header = 1234 }, plugin_schema)
        assert.are.same({["upstream_host_header"] = 'upstream_host_header is not a string' }, err)
        assert.False(ok)
    end)
end)
