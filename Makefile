SWIFTFORMAT := .nest/bin/swiftformat
SWIFTLINT := .nest/bin/swiftlint

.PHONY: install-commands format lint ast-lint format-lint hooks test check build release

install-commands:
	./scripts/nest.sh bootstrap nestfile.yaml

format:
	@test -f "$(SWIFTFORMAT)" || (echo "Run: make install-commands" && exit 1)
	"$(SWIFTFORMAT)" --config .swiftformat .

lint:
	@test -f "$(SWIFTLINT)" || (echo "Run: make install-commands" && exit 1)
	"$(SWIFTLINT)" lint --config .swiftlint.yml --strict

ast-lint:
	swift run --package-path swift-ast-linter swift-ast-lint ./Sources

format-lint: format lint

hooks:
	./scripts/setup-hooks.sh

test:
	swift test

build:
	swift build

release:
	swift build -c release

check: format lint ast-lint test
