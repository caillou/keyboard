.PHONY: install test test-watch coverage fmt fmt-check lint reload console update-emmylua

install:
	./script/setup

test:
	./lua_modules/bin/busted

test-watch:
	./lua_modules/bin/busted --watch

# Run the Engine spec under luacov and print the coverage report. Generates
# luacov.stats.out (raw) and luacov.report.out (human-readable); both gitignored.
coverage:
	./lua_modules/bin/busted --coverage
	./lua_modules/bin/luacov
	cat luacov.report.out

fmt:
	stylua .

fmt-check:
	stylua --check .

lint:
	./lua_modules/bin/luacheck hammerspoon spec
	shellcheck script/*

# Force a Hammerspoon config reload from the terminal (via the hs CLI).
reload:
	hs -c "hs.reload()"

# Open the Hammerspoon Console (debug log) from the terminal.
console:
	hs -c "hs.openConsole()"

update-emmylua:
	./script/update-emmylua
