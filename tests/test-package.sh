#!/bin/sh
# test-package.sh — audit the built .pkg itself (not just the staging dir):
# install-path whitelist applied to real package contents, required payload
# files, BOM↔manifest consistency, BOM ownership/modes, zero install scripts,
# sha256 sidecar. Skipped when no pkg exists; REQUIRE_PKG=1 (CI, after
# packaging) turns a missing pkg into a hard failure.
set -u
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"; fail=0
ok()  { echo "  PASS  $*"; }
bad() { echo "  FAIL  $*"; fail=1; }

PKG=$(ls dist/HP1022-Gutenprint-*.pkg 2>/dev/null | sort -V | tail -1)
if [ -z "$PKG" ]; then
  if [ "${REQUIRE_PKG:-0}" = "1" ]; then
    echo "error: no dist/HP1022-Gutenprint-*.pkg — run scripts/package.sh" >&2
    exit 1
  fi
  echo "test-package: no pkg built — skipped"
  exit 0
fi
echo "package: $PKG"
pkgutil --check-signature "$PKG" 2>&1 | sed 's/^/  sig: /' || true

echo "== install-path whitelist =="
# What `installer` will actually write. Allowed: our prefix, the single PPD,
# and the ancestor dirs needed to reach them (re-created with their normal
# system ownership). ./_* entries are pkgbuild appledouble xattr carriers —
# they restore xattrs, they are not installed as visible files.
files=$(pkgutil --payload-files "$PKG" | grep -v '/\._')
[ -n "$files" ] || bad "pkgutil reports an empty payload"
off=$(printf '%s\n' "$files" | grep -v \
  -e '^\.$' \
  -e '^\./Library$' \
  -e '^\./Library/Printers$' \
  -e '^\./Library/Printers/PPDs$' \
  -e '^\./Library/Printers/PPDs/Contents$' \
  -e '^\./Library/Printers/PPDs/Contents/Resources$' \
  -e '^\./Library/Printers/HP1022-Gutenprint$' \
  -e '^\./Library/Printers/HP1022-Gutenprint/' \
  -e '^\./Library/Printers/PPDs/Contents/Resources/HP1022-Gutenprint-hp-lj_1022\.ppd$' \
  || true)
[ -z "$off" ] && ok "all install paths inside our prefix / the single PPD" \
  || { bad "out-of-scope install paths:"; printf '%s\n' "$off" | sed 's/^/    /'; }

echo "== required payload contents =="
for f in \
  './Library/Printers/HP1022-Gutenprint/libexec/rastertogutenprint.5.3' \
  './Library/Printers/HP1022-Gutenprint/libexec/cups-genppd.5.3' \
  './Library/Printers/HP1022-Gutenprint/share/doc/payload-manifest.txt' \
  './Library/Printers/HP1022-Gutenprint/share/doc/payload-sha256sums.txt' \
  './Library/Printers/PPDs/Contents/Resources/HP1022-Gutenprint-hp-lj_1022.ppd'
do
  printf '%s\n' "$files" | grep -qxF "$f" && ok "$f" || bad "missing from pkg: $f"
done

TMP=$(mktemp -d /tmp/hp1022-pkg.XXXXXX); trap 'rm -rf "$TMP"' EXIT
if pkgutil --expand "$PKG" "$TMP/x" >/dev/null 2>&1 && [ -f "$TMP/x/Bom" ]; then

  echo "== BOM file list vs payload manifest =="
  lsbom "$TMP/x/Bom" | awk '$2 ~ /^1/ && $1 !~ /\/\._/ {sub(/^\.\//,"",$1); print $1}' \
    | LC_ALL=C sort > "$TMP/bom-files"
  if [ -f dist/payload-manifest.txt ]; then
    LC_ALL=C sort dist/payload-manifest.txt > "$TMP/manifest"
    if diff -q "$TMP/bom-files" "$TMP/manifest" >/dev/null; then
      ok "BOM files == payload-manifest.txt ($(wc -l < "$TMP/bom-files" | tr -d ' ') files)"
    else
      bad "BOM/manifest mismatch:"; diff "$TMP/bom-files" "$TMP/manifest" | head -10 | sed 's/^/    /'
    fi
  else
    bad "dist/payload-manifest.txt missing — cannot compare BOM"
  fi

  echo "== BOM ownership and modes =="
  # lsbom columns: path  mode  uid/gid  size  cksum. --ownership recommended
  # must produce uid/gid 0/0 (root:wheel) and nothing world-writable.
  owners=$(lsbom "$TMP/x/Bom" | awk '{print $3}' | sort -u)
  [ "$owners" = "0/0" ] && ok "all BOM entries owned by 0/0 (root:wheel)" \
    || { bad "unexpected BOM owners: $owners"; }
  ww=$(lsbom "$TMP/x/Bom" | awk '$2 ~ /[2367]$/ {print $1}' | head -5)
  [ -z "$ww" ] && ok "nothing world-writable" \
    || { bad "world-writable entries:"; printf '%s\n' "$ww" | sed 's/^/    /'; }
  for exe in rastertogutenprint.5.3 cups-genppd.5.3; do
    m=$(lsbom "$TMP/x/Bom" | awk -v n="$exe" '$1 ~ "/"n"$" {print $2}')
    [ "$m" = "100755" ] && ok "$exe mode 0755" || bad "$exe BOM mode '$m' (want 100755)"
  done

  echo "== no install scripts =="
  if [ -d "$TMP/x/Scripts" ]; then
    bad "pkg has a Scripts component:"; find "$TMP/x/Scripts" -type f | sed 's/^/    /'
  elif find "$TMP/x" -type f \( -name preinstall -o -name postinstall -o -name 'preupgrade' -o -name 'postupgrade' \) | grep -q .; then
    bad "pkg contains pre/post-install scripts"
  else
    ok "no Scripts component (pure payload)"
  fi
else
  bad "pkgutil --expand failed — pkg corrupt or unreadable"
fi

echo "== sha256 sidecar =="
if [ -f "$PKG.sha256" ]; then
  want=$(awk '{print $1}' "$PKG.sha256")
  got=$(shasum -a 256 "$PKG" | awk '{print $1}')
  [ "$want" = "$got" ] && ok "sha256 sidecar matches pkg" || bad "sha256 sidecar mismatch"
else
  bad "missing $PKG.sha256"
fi

echo; [ "$fail" -eq 0 ] && echo "test-package: PASS" || { echo "test-package: FAIL"; exit 1; }
