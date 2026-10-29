# hp1022-macos-driver — top-level entry points. Everything real lives in scripts/.
SHELL := /bin/sh
PKGVER ?= 0.1.0

.PHONY: all fetch build verify package test clean distclean

all: build verify package

fetch:
	./scripts/fetch-source.sh

build: fetch
	./scripts/build.sh

verify:
	./scripts/verify.sh

package: build verify
	./scripts/package.sh $(PKGVER)

test:
	./tests/test-build.sh
	./tests/test-payload.sh
	./tests/test-dependencies.sh
	./tests/test-security.sh

clean:
	rm -rf stage build/gutenprint-*/.build-stamp 2>/dev/null || true
	rm -rf stage

# wipe everything generated, including the gutenprint tree and dist/
distclean: clean
	rm -rf build dist
	rm -f sources/download.tmp
