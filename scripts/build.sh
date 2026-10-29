#!/bin/sh
# build.sh — compile Gutenprint 5.3.5 from the pinned tarball into a minimal
# staging payload for HP LaserJet 1022. Unprivileged; writes only under
# build/, stage/ and dist/ inside this repository.
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

VER=5.3.5
REL=5.3                                        # release suffix used in binary names
TARBALL="sources/gutenprint-$VER.tar.xz"
SRCDIR="build/gutenprint-$VER"
PREFIX=/Library/Printers/HP1022-Gutenprint     # compiled into the binaries
RAW="stage/raw"                                # full `make install` DESTDIR
PAYLOAD="stage/payload"                        # exact pkg contents
MODEL=hp-lj_1022
PPDNAME="HP1022-Gutenprint-$MODEL"

log() { printf '==> %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

[ -f "$TARBALL" ] || { log "fetching sources"; ./scripts/fetch-source.sh; }
[ -f "$TARBALL" ] || die "missing $TARBALL"

# Re-verify the tarball hash at build time as well (cheap, catches edits).
WANT=$(awk -v n=gutenprint -v v="$VER" '$1==n && $2==v {print $3}' sources.lock)
GOT=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
[ "$WANT" = "$GOT" ] || die "sources.lock hash mismatch on $TARBALL"

command -v clang >/dev/null || die "Xcode Command Line Tools required (xcode-select --install)"
command -v perl  >/dev/null || die "perl required for PPD post-processing"

# ---------------------------------------------------------------- configure
if [ ! -d "$SRCDIR" ]; then
  log "extracting $TARBALL"
  mkdir -p build
  tar -xJf "$TARBALL" -C build
fi
for p in patches/*.patch; do
  [ -f "$p" ] || continue
  grep -q "$(basename "$p")" "$SRCDIR/.applied-patches" 2>/dev/null && continue
  log "applying patch $p"
  (cd "$SRCDIR" && patch -p1 < "$ROOT/$p")
  basename "$p" >> "$SRCDIR/.applied-patches"
done

cd "$SRCDIR"
if [ ! -f Makefile ]; then
  log "configuring (prefix=$PREFIX)"
  ./configure \
    --prefix="$PREFIX" \
    --with-cups \
    --without-gimp2 \
    --disable-libgutenprintui2 \
    --enable-cups-ppds \
    --disable-translated-cups-ppds \
    --disable-globalized-cups-ppds \
    --disable-nls \
    --without-readline \
    --disable-test \
    --disable-testpattern \
    --disable-shared \
    --enable-static \
    --enable-static-genppd \
    CFLAGS="-O2 -D_DARWIN_C_SOURCE"
fi

log "building"
make -j"$(sysctl -n hw.ncpu)"

cd "$ROOT"
rm -rf "$RAW" "$PAYLOAD"
log "installing to DESTDIR=$RAW"
make -C "$SRCDIR" install DESTDIR="$ROOT/$RAW" >/dev/null

# ------------------------------------------------------------------ payload
# Only what the HP 1022 path needs. Nothing else from `make install` ships.
FILTERDIR="$RAW/usr/libexec/cups/filter"
SBINDIR="$RAW/usr/sbin"
SHAREDIR="$RAW$PREFIX/share/gutenprint"
[ -x "$FILTERDIR/rastertogutenprint.$REL" ] || die "filter missing in $FILTERDIR"
[ -x "$SBINDIR/cups-genppd.$REL" ]          || die "cups-genppd missing in $SBINDIR"
[ -d "$SHAREDIR" ]                          || die "gutenprint data missing in $SHAREDIR"

log "assembling payload"
install -d "$PAYLOAD$PREFIX/libexec" \
           "$PAYLOAD$PREFIX/share/doc" \
           "$PAYLOAD/Library/Printers/PPDs/Contents/Resources"
install -m 0755 "$FILTERDIR/rastertogutenprint.$REL" "$PAYLOAD$PREFIX/libexec/"
install -m 0755 "$SBINDIR/cups-genppd.$REL"          "$PAYLOAD$PREFIX/libexec/"
cp -R "$SHAREDIR" "$PAYLOAD$PREFIX/share/"
# Trim what the payload clearly does not need (keeps audit surface small).
rm -rf "$PAYLOAD$PREFIX/share/gutenprint/doc" \
       "$PAYLOAD$PREFIX/share/gutenprint/samples" 2>/dev/null || true
install -m 0644 LICENSES/GPL-2.0.txt   "$PAYLOAD$PREFIX/share/doc/"
install -m 0644 "$SRCDIR/COPYING"      "$PAYLOAD$PREFIX/share/doc/COPYING.gutenprint"
install -m 0644 "$SRCDIR/AUTHORS"      "$PAYLOAD$PREFIX/share/doc/AUTHORS.gutenprint"

# -------------------------------------------------------------- PPD + fixups
log "generating PPD for $MODEL (LC_ALL=C)"
TMPD=$(mktemp -d /tmp/hp1022-ppd.XXXXXX); trap 'rm -rf "$TMPD"' EXIT
STP_DATA_PATH="$ROOT/$SHAREDIR/$REL/xml" LC_ALL=C \
  "$RAW/usr/sbin/cups-genppd.$REL" -p "$TMPD" "$MODEL" >/dev/null
SRC_PPD=$(ls "$TMPD"/*.ppd* | head -1)
[ -n "$SRC_PPD" ] || die "genppd produced no PPD for $MODEL"
case "$SRC_PPD" in *.gz) gunzip -c "$SRC_PPD";; *) cat "$SRC_PPD";; esac \
| perl -pe '
    $_="" if /^\*(Param)?CustomStp/;                                  # breaks macOS Printer Features sheet
    s#(\*cupsFilter:\s*"application/vnd\.cups-raster \d+ )rastertogutenprint\.[\d.]+"#$1'"$PREFIX"'/libexec/rastertogutenprint.5.3"#;
  ' | grep -v '^\*cupsFilter:[^"]*"application/vnd\.cups-command' \
  > "$PAYLOAD/Library/Printers/PPDs/Contents/Resources/$PPDNAME.ppd"

# ------------------------------------------------------------- ad-hoc sign
# Integrity-only signature. NOT Apple notarization.
log "ad-hoc signing payload binaries"
codesign -s - -f "$PAYLOAD$PREFIX/libexec/"*

# ------------------------------------------------------------------ manifest
# sha256sums first (it must not list itself), then the manifest lists
# everything including both bookkeeping files.
( cd "$PAYLOAD" && find . -type f ! -name payload-sha256sums.txt \
    -exec shasum -a 256 {} + | LC_ALL=C sort -k2 | sed 's| \./|  |' ) \
  > "$PAYLOAD$PREFIX/share/doc/payload-sha256sums.txt"
( cd "$PAYLOAD" && find . -type f | LC_ALL=C sort | sed 's|^\./||' ) \
  > "$PAYLOAD$PREFIX/share/doc/payload-manifest.txt"
install -d dist
cp "$PAYLOAD$PREFIX/share/doc/payload-manifest.txt"    dist/payload-manifest.txt
cp "$PAYLOAD$PREFIX/share/doc/payload-sha256sums.txt"  dist/payload-sha256sums.txt

log "done. Payload tree:"
find "$PAYLOAD" -type f | sed "s|^$PAYLOAD/||" | LC_ALL=C sort | sed 's/^/  /'
log "run ./scripts/verify.sh to inspect, ./scripts/package.sh to build the pkg"
