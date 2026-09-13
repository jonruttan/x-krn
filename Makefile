# x-krn -- the Kernel lang for x-lang
#
# Install copies this bundle to <share>/langs/krn, where `x -l` looks: a lang
# is installed when its files are there. No registry, no database.
#
#   make install                        into the x on PATH
#   PREFIX=$HOME/.local make install    into a particular prefix
#
# A pin (lang.pin.xon + Pin bundle) freezes a verified tarball for one project
# and is what a build should depend on. An install is one unversioned copy for
# the whole machine. Pin when the version matters; install to get `x -l krn`
# working.

X ?= x

# The version is derived from git describe, never committed: a version literal
# is true only at the commit it is tagged on and wrong on every commit after.
# lang.xon declares what this bundle requires; the installed artifact carries
# what it is, in a version stamp -- the same split as x-lang's own
# $(X_RELEASE) -> <lib>/contract/release.
LANG_VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
# PREFIX wins when given, so this matches x-lang's own `PREFIX=... make
# install`.  Otherwise ask the x on PATH where its tree is -- the question
# --share-dir exists to answer.
SHARE := $(if $(PREFIX),$(PREFIX)/share/x,$(shell $(X) --share-dir))
DEST  := $(SHARE)/langs/krn

# What a consumer needs to run the lang: the declaration, the entry, the
# modules. Not the suite, the tooling, or CI.
PAYLOAD := lang.xon run.x krn

.PHONY: install
install: ## Install into <share>/langs/krn
	@test -n "$(SHARE)" || { echo "x-krn: cannot find an x tree -- set PREFIX or X" >&2; exit 1; }
	@test -d "$(SHARE)" || { echo "x-krn: no x tree at $(SHARE)" >&2; exit 1; }
	rm -rf "$(DEST)"
	mkdir -p "$(DEST)"
	cp -R $(PAYLOAD) "$(DEST)/"
	printf '%s\n' '$(LANG_VERSION)' > "$(DEST)/version"
	@echo "x-krn: installed to $(DEST)"
	@echo "x-krn: writing the boot image"
	"$(X)" --image -l krn || true
	@echo "x-krn: try  x -l krn"

.PHONY: uninstall
uninstall: ## Remove it again
	rm -rf "$(DEST)"
	@echo "x-krn: removed $(DEST)"

.PHONY: test
test: ## Run the spec suite
	X="$(X)" sh tests/spec-runner.sh

.PHONY: bundle
bundle: ## Roll a release tarball and print its pin
	sh tools/bundle.sh

.PHONY: help
help: ## Show targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[32m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
