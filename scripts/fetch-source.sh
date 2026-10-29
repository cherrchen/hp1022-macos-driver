#!/bin/sh
# fetch-source.sh — download every entry in sources.lock into sources/ and
# verify its SHA-256. Runs unprivileged; never touches the system.
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
SRC="$ROOT/sources"
LOCK="$ROOT/sources.lock"
[ -f "$LOCK" ] || { echo "error: $LOCK missing" >&2; exit 1; }
mkdir -p "$SRC"

fetch_one() {
  name=$1 ver=$2 want=$3 url=$4
  file="$SRC/$name-$ver.tar.xz"
  if [ -f "$file" ]; then
    got=$(shasum -a 256 "$file" | awk '{print $1}')
    if [ "$got" = "$want" ]; then
      echo "ok (cached): $name-$ver.tar.xz"
      return 0
    fi
    echo "warning: cached $file fails hash check — re-downloading" >&2
    rm -f "$file"
  fi
  tmp="$SRC/download.tmp"
  echo "downloading: $url"
  curl -fL --retry 3 --connect-timeout 30 -o "$tmp" "$url"
  got=$(shasum -a 256 "$tmp" | awk '{print $1}')
  if [ "$got" != "$want" ]; then
    rm -f "$tmp"
    echo "error: SHA-256 mismatch for $name-$ver" >&2
    echo "  want: $want" >&2
    echo "  got:  $got" >&2
    exit 1
  fi
  mv "$tmp" "$file"
  echo "ok: $name-$ver.tar.xz"
}

fail=0
while read -r name ver sha url; do
  case "$name" in ''|'#'*) continue;; esac
  fetch_one "$name" "$ver" "$sha" "$url" || fail=1
done < "$LOCK"

[ "$fail" -eq 0 ] || exit 1
echo "all sources verified"
