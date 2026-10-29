#!/bin/sh
# test-dependencies.sh — binaries must resolve only against system libraries
# and locate their XML data. Also exercises the filter + genppd for real.
set -u
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"; fail=0
ok()  { echo "  PASS  $*"; }
bad() { echo "  FAIL  $*"; fail=1; }
PREFIX=/Library/Printers/HP1022-Gutenprint
P="stage/payload"
RAW="stage/raw"
[ -d "$P$PREFIX" ] || { echo "error: payload missing — build first"; exit 1; }

echo "== otool -L dependency audit =="
for f in "$P$PREFIX"/libexec/*; do
  deps=$(otool -L "$f" | tail -n +2 | awk '{print $1}' | grep -v ":(offset" || true)
  echo "  $(basename "$f"):"; echo "$deps" | sed 's/^/    /'
  bad_deps=$(echo "$deps" | grep -vE '^(/usr/lib/|/System/|@executable_path|@loader_path)' || true)
  [ -z "$bad_deps" ] && ok "$(basename "$f") system libs only" \
    || { bad "$(basename "$f") odd deps:"; echo "$bad_deps" | sed 's/^/    /'; }
  echo "$deps" | grep -q '/opt/homebrew' && bad "$(basename "$f") depends on Homebrew!"
done

echo "== rastertogutenprint runs =="
R="$P$PREFIX/libexec/rastertogutenprint.5.3"
if [ -x "$R" ]; then
  out=$("$R" 2>&1 | head -3 || true)
  echo "$out" | grep -qi 'gutenprint\|usage\|raster' && ok "filter executes" \
    || bad "filter output unexpected: $out"
fi

echo "== genppd resolves XML data via STP_DATA_PATH =="
GEN="$RAW/usr/sbin/cups-genppd.5.3"
SHARE="$ROOT/$RAW$PREFIX/share/gutenprint/5.3/xml"
if [ -x "$GEN" ]; then
  cnt=$(STP_DATA_PATH="$SHARE" LC_ALL=C "$GEN" -M 2>/dev/null | wc -l | tr -d ' ')
  [ "${cnt:-0}" -gt 100 ] && ok "genppd sees $cnt models" || bad "genppd sees only $cnt models"
  STP_DATA_PATH="$SHARE" LC_ALL=C "$GEN" -M 2>/dev/null | grep -q '^hp-lj_1022$' \
    && ok "hp-lj_1022 resolvable" || bad "hp-lj_1022 missing from genppd list"
fi

echo "== end-to-end: raster -> filter -> PCL smoke test =="
# Runs the real pipeline the way CUPS does: produce CUPS raster, then invoke
# rastertogutenprint with PPD/args/env as cupsd would. Proves the filter
# emits a PCL 5e stream — the deepest check possible without hardware.
PPD="$P/Library/Printers/PPDs/Contents/Resources/HP1022-Gutenprint-hp-lj_1022.ppd"
if [ -x "$R" ] && [ -f "$PPD" ] && command -v cupsfilter >/dev/null 2>&1; then
  TMP=$(mktemp -d /tmp/hp1022-cupsf.XXXXXX)
  printf 'HP1022 smoke test page\n' > "$TMP/in.txt"
  if STP_DATA_PATH="$SHARE" cupsfilter -m application/vnd.cups-raster \
       -p "$PPD" "$TMP/in.txt" > "$TMP/job.raster" 2>"$TMP/err.log"; then
    ok "cups raster stage produced $(stat -f%z "$TMP/job.raster") bytes"
    if PPD="$ROOT/$PPD" STP_DATA_PATH="$SHARE" "$R" 1 tester "smoke" 1 \
         "PageSize=Letter" < "$TMP/job.raster" > "$TMP/out.pcl" 2>"$TMP/ferr.log"; then
      sz=$(stat -f%z "$TMP/out.pcl")
      [ "$sz" -gt 50 ] || bad "PCL output suspiciously small ($sz B)"
      # PCL 5e jobs begin with ESC E (printer reset)
      if [ "$(head -c 2 "$TMP/out.pcl" | xxd -p)" = "1b45" ]; then
        ok "filter emitted PCL 5e stream (${sz}B, starts with ESC E reset)"
      else
        bad "filter output does not start with PCL reset: $(head -c 8 "$TMP/out.pcl" | xxd -p)"
      fi
    else
      bad "rastertogutenprint failed:"; sed 's/^/    /' "$TMP/ferr.log" | head -8
    fi
  else
    bad "cupsfilter raster stage failed:"; sed 's/^/    /' "$TMP/err.log" | head -8
  fi
else
  echo "  (skipped — cupsfilter or artifacts missing)"
fi

echo; [ "$fail" -eq 0 ] && echo "test-dependencies: PASS" || { echo "test-dependencies: FAIL"; exit 1; }
