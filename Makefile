ADDON := FroschglibberRepair
VERSION := $(shell sed -n 's/^.. Version: *//p' $(ADDON).toc)
# Build timestamp so every produced zip has a unique name (CurseForge requires it).
STAMP := $(shell date +%Y-%m-%d_%H%M%S)
DIST := dist
FILES := $(ADDON).toc $(ADDON).lua frog.tga
ZIPNAME := $(ADDON)-$(VERSION)-$(STAMP).zip
LUA ?= lua
LUAC ?= luac

.PHONY: test zip clean changelog

# Syntax-checks the addon and runs the behaviour tests against a WoW API stub.
test:
	@command -v $(LUAC) >/dev/null 2>&1 || { echo "luac not found (install Lua, e.g. 'brew install lua')"; exit 1; }
	@command -v $(LUA) >/dev/null 2>&1 || { echo "lua not found (install Lua, e.g. 'brew install lua')"; exit 1; }
	@$(LUAC) -p $(ADDON).lua && echo "Syntax OK ($(LUAC))"
	@$(LUA) tests/run.lua $(ADDON).lua

changelog:
	@awk '/^## \[$(VERSION)\]/{found=1; next} /^## \[/{if(found) exit} found' CHANGELOG.md

zip:
	@mkdir -p $(DIST)/$(ADDON)
	@cp $(FILES) $(DIST)/$(ADDON)/
	@cd $(DIST) && zip -r $(ZIPNAME) $(ADDON)
	@rm -rf $(DIST)/$(ADDON)
	@echo "Created $(DIST)/$(ZIPNAME)"
	@echo "--- Changelog for $(VERSION) (paste into the CurseForge upload form) ---"
	@$(MAKE) --no-print-directory changelog

clean:
	rm -rf $(DIST)
