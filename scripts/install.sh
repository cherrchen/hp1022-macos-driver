#!/bin/sh
# install.sh — install the driver package. Separates concerns:
#   (A) install driver files          <- this script, requires sudo
#   (B) create the print queue        <- scripts/add-printer.sh, run it yourself
# This script NEVER creates queues, never sets a default printer.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
PKG=$(ls "$ROOT"/dist/HP1022-Gutenprint-*.pkg 2>/dev/null | sort -V | tail -1)

usage() {
  cat <<'EOF'
usage: scripts/install.sh [--pkg PATH] [--dry-run]

Installs the HP LaserJet 1022 Gutenprint driver payload with sudo installer.
After it finishes, add the printer yourself:
  - System Settings -> Printers & Scanners -> Add Printer, choose the
    "HP1022-Gutenprint" software entry, or
  - run: sudo scripts/add-printer.sh
EOF
}

DRYRUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --pkg) PKG=$2; shift 2;;
    --dry-run) DRYRUN=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "unknown arg: $1" >&2; usage >&2; exit 2;;
  esac
done

[ -n "$PKG" ] && [ -f "$PKG" ] || { echo "error: no pkg found (build one with scripts/package.sh)" >&2; exit 1; }
PKG=$(CDPATH='' cd -- "$(dirname -- "$PKG")" && pwd)/$(basename "$PKG")

echo "package : $PKG"
echo "sha256  : $(shasum -a 256 "$PKG" | awk '{print $1}')"
echo "payload :"
# ._* entries are pkgbuild's encoding of macOS xattrs (com.apple.provenance
# is set by the system on every created file and cannot be stripped);
# they restore xattrs at install, they are not installed as visible files.
pkgutil --payload-files "$PKG" | grep -v '/\._' | sed 's/^/  /'
echo "signature:"
pkgutil --check-signature "$PKG" 2>&1 | sed 's/^/  /' || true

if [ "$DRYRUN" -eq 1 ]; then
  echo "dry-run: not installing."
  exit 0
fi

echo
echo "The next command runs 'sudo installer' and writes files under:"
echo "  /Library/Printers/HP1022-Gutenprint/"
echo "  /Library/Printers/PPDs/Contents/Resources/HP1022-Gutenprint-hp-lj_1022.ppd"
echo "Nothing else is changed (package has no install scripts)."
sudo installer -pkg "$PKG" -target / -verbose
echo "driver files installed. To create a queue: sudo scripts/add-printer.sh"
