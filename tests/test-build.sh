#!/bin/sh
# test-build.sh — source integrity + build artifacts sanity. No sudo.
set -u
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"; fail=0
ok()  { echo "  PASS  $*"; }
bad() { echo "  FAIL  $*"; fail=1; }

echo "== sources.lock hash verification =="
while read -r name ver sha url; do
  case "$name" in ''|'#'*) continue;; esac
  f="sources/$name-$ver.tar.xz"
  if [ ! -f "$f" ]; then bad "missing $f (run make fetch)"; continue; fi
  got=$(shasum -a 256 "$f" | awk '{print $1}')
  [ "$got" = "$sha" ] && ok "$name-$ver sha256" || bad "$name-$ver hash mismatch: $got"
done < sources.lock

echo "== staged payload exists =="
P="stage/payload/Library/Printers/HP1022-Gutenprint"
for f in libexec/rastertogutenprint.5.3 libexec/cups-genppd.5.3 \
         share/doc/payload-manifest.txt share/doc/payload-sha256sums.txt \
         share/doc/COPYING.gutenprint; do
  [ -f "$P/$f" ] && ok "$f" || bad "missing $P/$f"
done
[ -d "$P/share/gutenprint/5.3" ] && ok "gutenprint XML data" || bad "missing share/gutenprint/5.3"
[ -f "$P/share/gutenprint/5.3/xml/printers/pcl.xml" ] && ok "pcl.xml present" || bad "pcl.xml missing"

echo "== arm64 binaries =="
for f in "$P"/libexec/*; do
  file "$f" | grep -q arm64 && ok "$(basename "$f") arm64" || bad "$(basename "$f") not arm64"
  file "$f" | grep -q x86_64 && bad "$(basename "$f") contains x86_64"
done

echo "== cups-genppd lists hp-lj_1022 =="
GEN="stage/raw/usr/sbin/cups-genppd.5.3"
if [ -x "$GEN" ]; then
  STP_DATA_PATH="$ROOT/stage/raw/Library/Printers/HP1022-Gutenprint/share/gutenprint/5.3/xml" \
    "$GEN" -M 2>/dev/null | grep -q '^hp-lj_1022' \
    && ok "genppd -M lists hp-lj_1022" || bad "hp-lj_1022 not in genppd model list"
else
  bad "cups-genppd.5.3 not staged"
fi

echo "== manifest/sha256sums consistency =="
M="dist/payload-manifest.txt"; S="dist/payload-sha256sums.txt"
if [ -f "$M" ] && [ -f "$S" ]; then
  while IFS= read -r rel; do
    [ -f "stage/payload/$rel" ] || bad "manifest lists missing file: $rel"
  done < "$M"
  ok "every manifest entry exists in payload"
  # every payload file except the manifest itself is hashed
  missing=$(cd stage/payload && find . -type f ! -name payload-sha256sums.txt \
    ! -name payload-manifest.txt | sed 's|^\./||' | while IFS= read -r r; do
      grep -q "  $r\$" "$ROOT/$S" || echo "$r"; done)
  [ -z "$missing" ] && ok "all payload files hashed" || { bad "unhashed files:"; echo "$missing" | sed 's/^/    /'; }
else
  bad "dist manifest/sums missing"
fi

echo; [ "$fail" -eq 0 ] && echo "test-build: PASS" || { echo "test-build: FAIL"; exit 1; }
