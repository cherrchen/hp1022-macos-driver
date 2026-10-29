#!/bin/sh
# test-payload.sh — audit the payload (and the built .pkg, if present):
# whitelist of install locations, no foreign-vendor files, PPD syntax.
set -u
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"; fail=0
ok()  { echo "  PASS  $*"; }
bad() { echo "  FAIL  $*"; fail=1; }
P="stage/payload"
[ -d "$P" ] || { echo "error: $P missing — build first"; exit 1; }

echo "== payload path whitelist =="
off=$(cd "$P" && find . -type f | grep -v \
  -e '^\./Library/Printers/HP1022-Gutenprint/' \
  -e '^\./Library/Printers/PPDs/Contents/Resources/HP1022-Gutenprint-hp-lj_1022\.ppd$' || true)
[ -z "$off" ] && ok "every file under our prefix / the single PPD" || { bad "out-of-scope files:"; echo "$off" | sed 's/^/    /'; }

echo "== forbidden SIP/system paths =="
sys=$(cd "$P" && find . -type f | grep -E '^\./(System|usr|bin|sbin|etc|private|Library/Extensions|Library/Printers/(Canon|Brother|Samsung|Epson|Lexmark))/' || true)
[ -z "$sys" ] && ok "no SIP/system/other-vendor dirs touched" || { bad "payload touches:"; echo "$sys" | sed 's/^/    /'; }

echo "== no other-vendor filters/backends =="
vend=$(find "$P" -type f \( -perm -0100 -o -name '*.so' -o -name '*.dylib' \) | \
  grep -viE 'rastertogutenprint|cups-genppd' || true)
[ -z "$vend" ] && ok "only our two executables" || { bad "extra executables:"; echo "$vend" | sed 's/^/    /'; }
vname=$(find "$P" -type f -name '*.ppd' | grep -vc 'HP1022-Gutenprint' || true)
[ "$vname" -eq 0 ] && ok "only the HP1022 PPD" || bad "$vname foreign PPD(s) in payload"

echo "== PPD syntax & filter path =="
PPD="$P/Library/Printers/PPDs/Contents/Resources/HP1022-Gutenprint-hp-lj_1022.ppd"
if [ -f "$PPD" ]; then
  grep -q '^\*PPD-Adobe:' "$PPD" && ok "PPD header" || bad "missing PPD-Adobe header"
  grep -q '^\*cupsFilter:.* /Library/Printers/HP1022-Gutenprint/libexec/rastertogutenprint\.5\.3"' "$PPD" \
    && ok "cupsFilter absolute path correct" || bad "cupsFilter path wrong"
  # cupsFilter target must exist inside the payload
  FT=$(sed -n 's/^\*cupsFilter:.*"application\/vnd\.cups-raster [0-9]* \([^"]*\)".*/\1/p' "$PPD")
  [ -f "$P$FT" ] && ok "cupsFilter target exists in payload" || bad "cupsFilter target absent: $FT"
  # no references to filters we do not ship
  grep -qE 'commandto(canon|epson|dyesub)' "$PPD" && bad "references unshipped commandto* filters" \
    || ok "no dangling filter references"
else
  bad "PPD missing"
fi

echo "== pkg audit (if dist/*.pkg exists) =="
PKG=$(ls dist/HP1022-Gutenprint-*.pkg 2>/dev/null | tail -1)
if [ -n "$PKG" ]; then
  pkgutil --payload-files "$PKG" | grep -qE 'HP1022-Gutenprint' \
    && ok "pkg contains payload" || bad "pkg payload wrong"
  # a package with no scripts has no Scripts component
  if pkgutil --expand "$PKG" /tmp/hp1022-pkgcheck.$$ >/dev/null 2>&1; then
    if [ -d "/tmp/hp1022-pkgcheck.$$/Scripts" ]; then
      bad "pkg contains install scripts:"; find "/tmp/hp1022-pkgcheck.$$/Scripts" -type f | sed 's/^/    /'
    else
      ok "pkg has no install scripts (pure payload)"
    fi
    rm -rf "/tmp/hp1022-pkgcheck.$$"
  fi
else
  echo "  (no pkg built yet — skipped)"
fi

echo; [ "$fail" -eq 0 ] && echo "test-payload: PASS" || { echo "test-payload: FAIL"; exit 1; }
