DEV_ROCKS = busted luacheck net-url
BUSTED_ARGS ?= -v

.PHONY: install dev clean doc lint test coverage

install:
	@luarocks make kong-plugin-upstream-redirect-*.rockspec \

dev: install
	@for rock in $(DEV_ROCKS) ; do \
		if ! luarocks list | grep $$rock > /dev/null ; then \
      echo $$rock not found, installing via luarocks... ; \
      luarocks install $$rock ; \
    else \
      echo $$rock already installed, skipping ; \
    fi \
	done;

lint:
	@luacheck -q . \
		--std 'busted' \
		--globals 'require' \
		--globals 'ngx' \
		--no-redefined \
		--no-unused-args

test:
	@busted -v spec
