#!/bin/sh
# add-printer.sh — create ONE print queue for an explicitly identified
# HP LaserJet 1022 USB device. Run manually; never called by the installer.
#
#   sudo scripts/add-printer.sh                 # pick from detected 1022 URIs
#   sudo scripts/add-printer.sh -u 'usb://HP/LaserJet%201022?serial=...'
#   sudo scripts/add-printer.sh -n MyQueue -u 'usb://...'
#   scripts/add-printer.sh --dry-run -u 'usb://...'   # show what would happen
#
# Guarantees: never sets the default printer; refuses to overwrite an
# existing queue unless --force; only accepts usb:// URIs that look like an
# HP LaserJet 1022 (unless --force).
set -eu

PPD=/Library/Printers/PPDs/Contents/Resources/HP1022-Gutenprint-hp-lj_1022.ppd
QUEUE=HP_LaserJet_1022
URI=
DRYRUN=0
FORCE=0

usage() { sed -n '2,14p' "$0"; exit "${1:-0}"; }
die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    -u|--uri)   URI=$2; shift 2;;
    -n|--name)  QUEUE=$2; shift 2;;
    --dry-run)  DRYRUN=1; shift;;
    --force)    FORCE=1; shift;;
    -h|--help)  usage 0;;
    *) usage 2;;
  esac
done

case "$QUEUE" in *[!A-Za-z0-9_-]*) die "invalid queue name '$QUEUE' (A-Za-z0-9_- only)";; esac
[ -f "$PPD" ] || die "driver PPD missing ($PPD) — install the package first"

# ---- choose the device URI ----------------------------------------------
if [ -z "$URI" ]; then
  echo "detected USB printers:"
  lpinfo -v 2>/dev/null | awk '$2 ~ /^usb:\/\// {print "  " $2}' || true
  CAND=$(lpinfo -v 2>/dev/null | awk '
    tolower($2) ~ /^usb:\/\/(hp|hewlett-packard)\/laserjet(%20|_)?1022(\?|$)/ {print $2}')
  n=$(printf '%s\n' "$CAND" | grep -c . || true)
  if [ "$n" -eq 1 ]; then
    URI=$CAND
    echo "auto-selected the single HP 1022 candidate: $URI"
  elif [ "$n" -gt 1 ]; then
    echo "multiple candidates found; re-run with -u:" >&2
    printf '%s\n' "$CAND" | sed 's/^/  /' >&2
    exit 1
  else
    die "no HP LaserJet 1022 USB device found — pass -u 'usb://...' explicitly"
  fi
fi

case "$URI" in
  usb://*) : ;;
  *) die "only usb:// device URIs are supported (got '$URI')";;
esac
if [ "$FORCE" -eq 0 ]; then
  case "$(printf '%s' "$URI" | tr 'A-Z' 'a-z')" in
    *hp*1022*|*hewlett*1022*) : ;;
    *) die "URI does not look like an HP LaserJet 1022: $URI (use --force to override)";;
  esac
fi

# ---- refuse to clobber an existing queue ---------------------------------
if lpstat -p "$QUEUE" >/dev/null 2>&1; then
  if [ "$FORCE" -eq 1 ]; then
    # lpadmin -p updates an existing queue; keep it if reconfiguration fails.
    echo "queue '$QUEUE' exists — updating it (--force)"
  else
    die "queue '$QUEUE' already exists — choose another -n name or pass --force"
  fi
fi

echo "plan:"
echo "  queue : $QUEUE"
echo "  uri   : $URI"
echo "  ppd   : $PPD"
echo "  default printer: NOT changed"
if [ "$DRYRUN" -eq 1 ]; then echo "dry-run: nothing done."; exit 0; fi
[ "$(id -u)" = 0 ] || die "run with sudo to create the queue"

lpadmin -p "$QUEUE" -E -v "$URI" -P "$PPD" \
  -D "HP LaserJet 1022 (Gutenprint arm64, experimental)" \
  -o printer-is-shared=false || die "could not configure queue '$QUEUE'"
cupsenable "$QUEUE" || die "could not enable queue '$QUEUE'"
cupsaccept "$QUEUE" || die "could not accept jobs for queue '$QUEUE'"
echo "queue '$QUEUE' created and enabled."
echo "test:   lp -d '$QUEUE' /etc/cups/cupsd.conf   # prints a text page"
echo "remove: sudo lpadmin -x '$QUEUE'"
