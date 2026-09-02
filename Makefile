APP      := AgentBar
SCHEME   := AgentBar
CONFIG   ?= Debug
DD       := build/DerivedData
APP_PATH := $(DD)/Build/Products/$(CONFIG)/$(APP).app
XCB      := xcodebuild -project $(APP).xcodeproj -scheme $(SCHEME) -destination 'platform=macOS' -derivedDataPath $(DD)
PKG      := Packages/$(APP)Kit
SUBSYSTEM := com.greatpixels.$(APP)

.PHONY: help generate spec build run stop test test-kit test-app screenshots icon install site site-build open logs clean release release-dry

help:                ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

generate:            ## Generate $(APP).xcodeproj (+ Info.plist/entitlements) from project.yml
	xcodegen generate --use-cache --quiet

spec:                ## Validate and summarize the resolved project spec
	xcodegen dump --type summary

build: generate      ## Build (CONFIG=Debug|Release)
	$(XCB) -configuration $(CONFIG) build -quiet

run: build           ## Relaunch the app (kills any running instance first)
	-pkill -x $(APP) 2>/dev/null; sleep 0.3
	open "$(APP_PATH)"

stop:                ## Quit the running app
	-pkill -x $(APP)

test: test-kit test-app   ## Run all tests

test-kit:            ## Run $(APP)Kit package tests (headless, fast)
	swift test --package-path $(PKG)

test-app: generate   ## Run app-layer tests via xcodebuild
	$(XCB) -configuration Debug test -only-testing:$(APP)Tests -quiet

screenshots: generate ## Render README screenshots into docs/screenshots from the real views
	mkdir -p docs/screenshots build
	echo "$(abspath docs/screenshots)" > build/screenshot-dir
	$(XCB) -configuration Debug test -only-testing:$(APP)Tests/ScreenshotTests -quiet; status=$$?; rm -f build/screenshot-dir; exit $$status
	@ls docs/screenshots

icon:                ## Regenerate the AppIcon set from scripts/make-icon.swift
	swift scripts/make-icon.swift

install:             ## Build Release, sign ad-hoc and install into /Applications
	./scripts/install-local.sh

site:                ## Run the landing page dev server (site/)
	cd site && npm run dev

site-build:          ## Build the static landing page into site/out
	cd site && npm run build

open: generate       ## Open the project in Xcode
	open $(APP).xcodeproj

logs:                ## Follow $(APP) OSLog output
	log stream --level debug --predicate 'subsystem == "$(SUBSYSTEM)"'

clean:               ## Remove build output and generated project files
	rm -rf build dist $(APP).xcodeproj Supporting/Info.plist Supporting/$(APP).entitlements $(PKG)/.build site/.next site/out

release:             ## Publish a release: make release VERSION=1.2.3 [NOTES=notes.md] [FLAGS=--draft]
	@test -n "$(VERSION)" || (echo "usage: make release VERSION=1.2.3 [NOTES=notes.md] [FLAGS=...]"; exit 2)
	./scripts/release.sh $(VERSION) $(if $(NOTES),--notes $(NOTES)) $(FLAGS)

release-dry:         ## Build the release artifacts into dist/ without touching git, R2 or GitHub
	@test -n "$(VERSION)" || (echo "usage: make release-dry VERSION=1.2.3"; exit 2)
	./scripts/release.sh $(VERSION) --dry-run $(FLAGS)
