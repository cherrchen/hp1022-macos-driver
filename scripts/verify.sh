#!/bin/sh
# verify.sh — inspect the staged payload: architectures, library deps,
# PPD sanity, payload whitelist. No system changes. Exit != 0 on failure.
set -u
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
PREFIX=/Library/Printers/HP1022-Gutenprint
PAYLOAD="stage/payload"
fail=0
say() { printf '%s\n' "$*"; }
ok()   { say "  PASS  $*"; }
bad()  { say "  FAIL  $*"; fail=1; }

[ -d "$PAYLOAD$PREFIX/libexec" ] || { echo "error: $PAYLOAD missing — run scripts/build.sh first" >&2; exit 1; }

say "== architecture check (arm64 only) =="
for f in "$PAYLOAD$PREFIX"/libexec/*; do
  [ -e "$f" ] || { bad "no binaries in libexec"; continue; }
  if file "$f" | grep -q 'arm64'; then ok "$(basename "$f") is arm64"
  else bad "$(basename "$f"): $(file -b "$f")"; fi
done

say "== dynamic library dependencies =="
# Allowed: /usr/lib/*, /System/* only. Homebrew or build-machine paths = fail.
for f in "$PAYLOAD$PREFIX"/libexec/*; do
  deps=$(otool -L "$f" | tail -n +2 | awk '{print $1}')
  echo "$deps" | sed 's/^/    dep: /'
  if echo "$deps" | grep -qE '^/opt/homebrew|\.local|/Users/|/tmp/'; then
    bad "$f links against a non-system path"
  fi
done
[ "$fail" -eq 0 ] && ok "no non-system library references"

say "== code signature =="
for f in "$PAYLOAD$PREFIX"/libexec/*; do
  if codesign -v "$f" 2>/dev/null; then ok "$(basename "$f") signature valid (ad-hoc)"
  else bad "$(basename "$f") unsigned/invalid"; fi
done

say "== PPD check =="
PPD="$PAYLOAD/Library/Printers/PPDs/Contents/Resources/HP1022-Gutenprint-hp-lj_1022.ppd"
if [ -f "$PPD" ]; then
  grep -q "^\*cupsFilter:.*\"application/vnd.cups-raster [0-9]* $PREFIX/libexec/rastertogutenprint\.5\.3\"" "$PPD" \
    && ok "cupsFilter uses absolute in-prefix path" \
    || bad "cupsFilter does not use $PREFIX absolute path"
  grep -qE 'PageSize\[[0-9]+,[0-9]' "$PPD" && bad "comma-decimal PageSize present" || ok "no locale-broken PageSize"
  grep -qE '^\*(Param)?CustomStp' "$PPD" && bad "CustomStp block present" || ok "no CustomStp blocks"
  grep -q 'hp-lj_1022' "$PPD" && ok "PPD is for hp-lj_1022" || bad "PPD model mismatch"
else
  bad "PPD missing: $PPD"
fi

say "== payload whitelist =="
# Every installed file must live under our prefix or be our single PPD.
badfiles=$(cd "$PAYLOAD" 2>/dev/null && find . -type f | grep -v \
  -e "^\./Library/Printers/HP1022-Gutenprint/" \
  -e "^\./Library/Printers/PPDs/Contents/Resources/HP1022-Gutenprint-")
if [ -n "$badfiles" ]; then bad "unexpected payload files:"; echo "$badfiles" | sed 's/^/    /'
else ok "all payload files inside HP1022-Gutenprint/ or the single PPD"; fi

# No filters/tools for other vendors.
vend=$(find "$PAYLOAD" -type f | grep -iE 'canon|epson|brother|samsung|splix|brlaser|dyesub|lexmark|xerox|oki' | grep -v share/gutenprint)
[ -n "$vend" ] && { bad "other-vendor artifacts in payload:"; echo "$vend" | sed 's/^/    /'; } \
  || ok "no other-vendor filters/tools"

say "== SIP-touching paths =="
touchy=$(find "$PAYLOAD" -type f | grep -E '^\./(System|usr/libexec|usr/bin|usr/sbin|usr/lib|etc|private|bin|sbin|Library/Extensions)/' || true)
[ -n "$touchy" ] && { bad "payload reaches SIP/system paths:"; echo "$touchy" | sed 's/^/    /'; } \
  || ok "payload never touches SIP-protected or system dirs"

echo
if [ "$fail" -eq 0 ]; then say "verify: all checks passed"; else say "verify: FAILURES above"; exit 1; fi
