.PHONY: install test test-watch fmt fmt-check

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
