#!/bin/sh
# uninstall.sh — remove exactly what the package installed, verifiably.
#
#   sudo scripts/uninstall.sh --dry-run        # show the plan (recommended first)
#   sudo scripts/uninstall.sh                  # remove files, keep queues
#   sudo scripts/uninstall.sh --remove-queue   # also delete OUR queue(s)
#   sudo scripts/uninstall.sh --force          # also remove user-modified files
#
# Safety model:
#   * removal list comes from the payload manifest written at build time
#     (installed copy first, repo dist/ copy as fallback) — not from guesses
#   * files whose content changed since install are skipped unless --force
#   * directories are removed only when empty, only inside our prefix
#   * queues are preserved by default; --remove-queue deletes only queues
#     whose PPD references our filter
set -u

PREFIX=/Library/Printers/HP1022-Gutenprint
PPDDIR=/Library/Printers/PPDs/Contents/Resources
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
DRYRUN=0 FORCE=0 RMQ=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRYRUN=1;; --force) FORCE=1;; --remove-queue) RMQ=1;;
    -h|--help) sed -n '2,15p' "$0"; exit 0;;
    *) echo "unknown arg: $a" >&2; exit 2;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }
MANIFEST="$PREFIX/share/doc/payload-manifest.txt"
HASHES="$PREFIX/share/doc/payload-sha256sums.txt"
[ -f "$MANIFEST" ] || MANIFEST="$ROOT/dist/payload-manifest.txt"
[ -f "$HASHES" ]   || HASHES="$ROOT/dist/payload-sha256sums.txt"
[ -f "$MANIFEST" ] || die "no manifest found — cannot prove what was installed; nothing removed"
echo "manifest: $MANIFEST"

SKIP=0 RM=0
remove_file() {
  f=$1
  [ -e "$f" ] || { echo "  absent   $f"; return; }
  # user-modification guard
  if [ "$FORCE" -eq 0 ] && [ -f "$HASHES" ]; then
    want=$(awk -v p="$f" '{ sub(/^\.\//,"",$2); if ("/"$2==p) print $1 }' "$HASHES" | head -1)
    if [ -n "$want" ]; then
      got=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
      if [ "$got" != "$want" ]; then
        echo "  MODIFIED $f (left in place; --force to remove)"; SKIP=$((SKIP+1)); return
      fi
    fi
  fi
  if [ "$DRYRUN" -eq 1 ]; then echo "  would rm $f"; else
    rm -f "$f" && echo "  removed  $f" && RM=$((RM+1))
  fi
}

echo "files:"
while IFS= read -r rel; do
  case "$rel" in
    Library/Printers/HP1022-Gutenprint/*|Library/Printers/PPDs/Contents/Resources/HP1022-Gutenprint-*)
      remove_file "/$rel";;
    *) echo "  refuse   /$rel (outside expected scope)"; SKIP=$((SKIP+1));;
  esac
done < "$MANIFEST"

# remove only empty directories, deepest first, only inside our own prefix
echo "directories:"
if [ -d "$PREFIX" ]; then
  find "$PREFIX" -type d -depth | while IFS= read -r d; do
    if [ -z "$(ls -A "$d" 2>/dev/null)" ]; then
      if [ "$DRYRUN" -eq 1 ]; then echo "  would rmdir $d"; else
        rmdir "$d" && echo "  rmdir    $d"
      fi
    else
      echo "  kept     $d (not empty)"
    fi
  done
  # the prefix root itself
  if [ -z "$(ls -A "$PREFIX" 2>/dev/null)" ]; then
    if [ "$DRYRUN" -eq 1 ]; then echo "  would rmdir $PREFIX"; else rmdir "$PREFIX" && echo "  rmdir    $PREFIX"; fi
  fi
else
  echo "  $PREFIX already gone"
fi

# ---- queues ---------------------------------------------------------------
echo "print queues:"
if [ "$RMQ" -eq 1 ]; then
  for f in /etc/cups/ppd/*.ppd; do
    [ -f "$f" ] || continue
    grep -q "HP1022-Gutenprint" "$f" || continue
    q=$(basename "$f" .ppd)
    if [ "$DRYRUN" -eq 1 ]; then echo "  would delete queue $q"; else
      lpadmin -x "$q" && echo "  deleted queue $q"
    fi
  done
else
  echo "  (kept — pass --remove-queue to delete queues using our PPD)"
fi

if [ "$DRYRUN" -eq 0 ] && [ "$(id -u)" = 0 ]; then
  pkgutil --forget org.hp1022macos.driver.gutenprint >/dev/null 2>&1 || true
fi

echo
echo "summary: ${RM} removed, ${SKIP} skipped/refused, dry-run=$DRYRUN"
[ "$DRYRUN" -eq 1 ] && echo "re-run with sudo and without --dry-run to apply."
exit 0
