.PHONY: install test test-watch

install:
	./script/setup

test:
	./lua_modules/bin/busted

test-watch:
	./lua_modules/bin/busted --watch
