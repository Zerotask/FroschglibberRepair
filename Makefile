ADDON := FroschglibberRepair
VERSION := $(shell sed -n 's/^.. Version: *//p' $(ADDON).toc)
DIST := dist
FILES := $(ADDON).toc $(ADDON).lua frog.tga

.PHONY: zip clean changelog

changelog:
	@awk '/^## \[$(VERSION)\]/{found=1; next} /^## \[/{if(found) exit} found' CHANGELOG.md

zip:
	@mkdir -p $(DIST)/$(ADDON)
	@cp $(FILES) $(DIST)/$(ADDON)/
	@cd $(DIST) && zip -r $(ADDON)-$(VERSION).zip $(ADDON)
	@rm -rf $(DIST)/$(ADDON)
	@echo "Created $(DIST)/$(ADDON)-$(VERSION).zip"
	@echo "--- Changelog for $(VERSION) (paste into the CurseForge upload form) ---"
	@$(MAKE) --no-print-directory changelog

clean:
	rm -rf $(DIST)
