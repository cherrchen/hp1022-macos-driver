#!/bin/sh
# package.sh — build the unsigned .pkg from stage/payload via pkgbuild.
# Pure payload: NO pre/postinstall scripts — zero install-time side effects.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
PAYLOAD="stage/payload"
VER="${1:-0.1.0}"
PKGID="org.hp1022macos.driver.gutenprint"
OUT="dist/HP1022-Gutenprint-$VER.pkg"

[ -d "$PAYLOAD/Library/Printers/HP1022-Gutenprint" ] || {
  echo "error: $PAYLOAD missing — run scripts/build.sh first" >&2; exit 1; }

mkdir -p dist
xattr -cr "$PAYLOAD" 2>/dev/null || true
find "$PAYLOAD" -name "._*" -delete

# pkgbuild with no --scripts dir => pure payload, nothing executes at install.
pkgbuild --root "$PAYLOAD" --install-location / \
  --identifier "$PKGID" --version "$VER" \
  --ownership recommended \
  "$OUT"

( cd dist && shasum -a 256 "$(basename "$OUT")" > "$(basename "$OUT").sha256" )
shasum -a 256 "$OUT"
echo "-> $OUT"
echo "NOTE: unsigned, un-notarized package. Inspect before installing:"
echo "  pkgutil --check-signature $OUT   # expect: Status: unsigned"
echo "  pkgutil --payload-files $OUT     # audit file list"
