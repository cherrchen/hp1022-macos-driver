#!/bin/sh
# test-security.sh — static audit of our own scripts and (if built) the pkg:
# the things this project promises NEVER to do must not appear in code.
set -u
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"; fail=0
ok()  { echo "  PASS  $*"; }
bad() { echo "  FAIL  $*"; fail=1; }

echo "== forbidden operations in scripts/ and Makefile =="
# Each pattern is something the project explicitly rules out.
check() { # label, egrep-pattern  (full-line comments are excluded)
  hits=$(grep -rnE "$2" scripts Makefile 2>/dev/null | grep -v "^Binary" \
       | grep -vE ':[0-9]+:[[:space:]]*#' || true)
  [ -z "$hits" ] && ok "$1" || { bad "$1 — found:"; echo "$hits" | sed 's/^/    /'; }
}
check "no Canon driver/cache/kext tampering" \
  'Canon|BJUSBLoad|/Library/Caches/Canon|kmutil'
check "no auto default-printer change" \
  'lpadmin +(-[^ ]* +)*-d |lpoptions +(-[^ ]* +)*-d '
check "no scanning/clearing of all queues" \
  'lpstat +-[^ ]*p[^ ]* *\||for .*in .*lpstat|/etc/cups/printers\.conf'
check "no rm -rf outside our own dirs" \
  'rm +-rf +/(Library|usr|etc|private|System|opt|var)'
check "no SIP/kext/system writes" \
  'csrutil|kextload|kextunload|/System/'
check "no writes/copies into the CUPS filter dir" \
  '(>|cp +|mv +|install +|rm +)[^#]*/usr/libexec/cups'
check "no remote code execution" \
  'curl[^|]*\| *(sudo *)?(sh|bash|zsh)|wget[^|]*\| *(sudo *)?(sh|bash|zsh)'
check "no sudo inside scripts (scripts run AS root, not via sudo)" \
  'sudo +(curl|make|./configure|patch|tar )'

echo "== uninstall.sh guardrails =="
grep -q 'manifest' scripts/uninstall.sh && ok "uninstall is manifest-driven" \
  || bad "uninstall does not use a manifest"
grep -q 'dry.run\|DRYRUN' scripts/uninstall.sh && ok "uninstall supports --dry-run" \
  || bad "uninstall lacks dry-run"
grep -qE 'rm +-rf +/Library/Printers/HP1022' scripts/uninstall.sh \
  && bad "uninstall rm -rf's the whole prefix blindly" \
  || ok "uninstall removes files individually, dirs only when empty"

echo "== add-printer.sh scope =="
grep -q 'lpadmin -d' scripts/add-printer.sh && bad "add-printer sets default" \
  || ok "never sets default printer"
grep -q 'usb://\*)\|usb://' scripts/add-printer.sh && ok "USB-URI restricted" \
  || bad "no URI scheme restriction"

echo "== pkg must carry no install scripts =="
PKG=$(ls dist/HP1022-Gutenprint-*.pkg 2>/dev/null | tail -1)
if [ -n "$PKG" ]; then
  E=/tmp/hp1022-secpkg.$$
  if pkgutil --expand "$PKG" "$E" >/dev/null 2>&1; then
    if [ -d "$E/Scripts" ] && [ -n "$(ls -A "$E/Scripts" 2>/dev/null)" ]; then
      bad "pkg contains scripts:"; find "$E/Scripts" -type f | sed 's/^/    /'
      grep -rlE 'lpadmin|Canon|BJUSBLoad|rm -rf' "$E/Scripts" | sed 's/^/    /'
    else
      ok "pkg has zero install scripts"
    fi
    rm -rf "$E"
  fi
else
  echo "  (no pkg yet — skipped)"
fi

echo; [ "$fail" -eq 0 ] && echo "test-security: PASS" || { echo "test-security: FAIL"; exit 1; }
