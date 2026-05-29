.PHONY: install test test-watch fmt fmt-check lint update-emmylua

install:
	./script/setup

test:
	./lua_modules/bin/busted

test-watch:
	./lua_modules/bin/busted --watch

fmt:
	stylua .

fmt-check:
	stylua --check .

lint:
	./lua_modules/bin/luacheck hammerspoon spec

update-emmylua:
	./script/update-emmylua
