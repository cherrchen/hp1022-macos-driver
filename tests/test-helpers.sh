#!/bin/sh
# Exercise install helpers in a temporary filesystem with mocked CUPS commands.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d /tmp/hp1022-helpers.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

fail() { echo "  FAIL  $*" >&2; cat "$TMP/output" >&2; exit 1; }
ok() { echo "  PASS  $*"; }
: > "$TMP/output"

cat > "$TMP/bin/mock-command" <<'EOF'
#!/bin/sh
set -eu
name=$(basename "$0")
case "$name" in
  id) echo "$MOCK_ID";;
  lpinfo) cat "$MOCK_DEVICES";;
  lpstat) [ "$MOCK_EXISTING" -eq 1 ];;
  *)
    printf '%s\n' "$name $*" >> "$MOCK_LOG"
    if [ "$name" = "$MOCK_FAIL" ]; then
      echo "mock $name failed" >&2
      exit 1
    fi
    ;;
esac
EOF
chmod +x "$TMP/bin/mock-command"
for name in id lpinfo lpstat lpadmin cupsenable cupsaccept pkgutil; do
  ln -s mock-command "$TMP/bin/$name"
done
PATH="$TMP/bin:$PATH"
MOCK_LOG="$TMP/commands.log"
MOCK_DEVICES="$TMP/devices"
MOCK_ID=0 MOCK_EXISTING=0 MOCK_FAIL=
export PATH MOCK_LOG MOCK_DEVICES MOCK_ID MOCK_EXISTING MOCK_FAIL

reset_mocks() {
  : > "$MOCK_LOG"
  : > "$MOCK_DEVICES"
  MOCK_ID=0 MOCK_EXISTING=0 MOCK_FAIL=
}
add_ok() {
  if ! sh "$TMP/add-printer.sh" "$@" > "$TMP/output" 2>&1; then
    fail "add-printer unexpectedly failed"
  fi
}
add_fails() {
  if sh "$TMP/add-printer.sh" "$@" > "$TMP/output" 2>&1; then
    fail "add-printer unexpectedly succeeded"
  fi
  if grep -q 'created and enabled' "$TMP/output"; then
    fail "failed queue operation reported success"
  fi
}

# Redirect only the fixed PPD path in a copy; production paths stay fixed.
: > "$TMP/driver.ppd"
sed "s|^PPD=.*|PPD=$TMP/driver.ppd|" "$ROOT/scripts/add-printer.sh" \
  > "$TMP/add-printer.sh"
URI='usb://HP/LaserJet%201022?serial=target'

echo "== HP 1022 device selection =="
for model in LaserJet%201022 laserjet_1022 LaserJet1022; do
  reset_mocks
  selected="usb://HP/$model?serial=target"
  printf '%s\n' "direct $selected" 'direct usb://Canon/Other' \
    'direct usb://HP/LaserJet%201020?serial=1022' \
    'direct usb://HP/LaserJet%2010220?serial=other' \
    'network ipp://HP/LaserJet%201022' > "$MOCK_DEVICES"
  add_ok --dry-run
  grep -Fq "uri   : $selected" "$TMP/output" || fail "wrong device selected"
  [ ! -s "$MOCK_LOG" ] || fail "dry-run changed a queue"
done
ok "selects only the target model among unrelated devices and URI variants"

reset_mocks
printf '%s\n' 'direct usb://Canon/Other' > "$MOCK_DEVICES"
add_fails --dry-run
grep -q 'no HP LaserJet 1022' "$TMP/output" || fail "missing-device diagnostic"
printf '%s\n' "direct $URI" 'direct usb://HP/LaserJet%201022?serial=second' \
  > "$MOCK_DEVICES"
add_fails --dry-run
grep -q 'multiple candidates' "$TMP/output" || fail "ambiguous devices accepted"
[ ! -s "$MOCK_LOG" ] || fail "device selection changed a queue"
ok "rejects missing or ambiguous target devices"

echo "== queue operation failures =="
for operation in lpadmin cupsenable cupsaccept; do
  reset_mocks
  MOCK_FAIL=$operation
  add_fails -u "$URI"
  grep -q "mock $operation failed" "$TMP/output" || fail "failure not exercised"
  case "$operation" in
    lpadmin) expected=1;; cupsenable) expected=2;; cupsaccept) expected=3;;
  esac
  count=$(wc -l < "$MOCK_LOG" | tr -d ' ')
  [ "$count" -eq "$expected" ] || fail "continued after $operation failed"
done
ok "each CUPS failure returns nonzero and stops later operations"

reset_mocks
MOCK_EXISTING=1
add_fails -u "$URI"
[ ! -s "$MOCK_LOG" ] || fail "existing queue changed without --force"
add_ok --force --dry-run -u "$URI"
[ ! -s "$MOCK_LOG" ] || fail "forced dry-run changed an existing queue"
MOCK_ID=1000
add_fails --force -u "$URI"
[ ! -s "$MOCK_LOG" ] || fail "queue changed before checking privileges"
MOCK_ID=0 MOCK_FAIL=lpadmin
add_fails --force -u "$URI"
grep -q '^lpadmin -p ' "$MOCK_LOG" || fail "existing queue was not updated in place"
if grep -q '^lpadmin -x ' "$MOCK_LOG"; then fail "existing queue deleted"; fi
ok "forced updates preserve the existing queue when configuration fails"

reset_mocks
add_ok -u "$URI"
grep -q 'created and enabled' "$TMP/output" || fail "success not reported"
[ "$(wc -l < "$MOCK_LOG" | tr -d ' ')" -eq 3 ] || fail "missing queue operations"
ok "successful queue creation completes all three operations"

echo "== uninstall modification protection =="
for mode in dry-run actual force; do
  reset_mocks
  MOCK_ID=1000
  fixture="$TMP/$mode"
  prefix="$fixture/Library/Printers/HP1022-Gutenprint"
  doc="$prefix/share/doc"
  xml="$prefix/share/gutenprint/5.3/xml/printers/pcl.xml"
  ppd="$fixture/Library/Printers/PPDs/Contents/Resources/HP1022-Gutenprint-hp-lj_1022.ppd"
  mkdir -p "$fixture/scripts" "$doc" "$(dirname "$xml")" "$(dirname "$ppd")"
  printf 'original\n' > "$xml"
  printf 'original\n' > "$ppd"
  printf 'unchanged\n' > "$doc/AUTHORS.gutenprint"
  manifest="$doc/payload-manifest.txt"
  hashes="$doc/payload-sha256sums.txt"
  : > "$manifest"
  : > "$hashes"
  for file in "$xml" "$ppd" "$doc/AUTHORS.gutenprint"; do
    shasum -a 256 "$file" | awk -v p="${file#/}" '{print $1 "  " p}' >> "$hashes"
  done
  (cd "$fixture" && find Library -type f | LC_ALL=C sort) > "$manifest"
  printf 'modified\n' > "$xml"
  printf 'modified\n' > "$ppd"
  # Redirect every deletion to the fixture, retaining the manifest whitelist.
  sed -e "s|/Library/Printers|$fixture/Library/Printers|g" \
    -e "s|remove_file \"/\$rel\"|remove_file \"$fixture/\$rel\"|" \
    "$ROOT/scripts/uninstall.sh" > "$fixture/scripts/uninstall.sh"
  case "$mode" in dry-run) set -- --dry-run;; actual) set --;; force) set -- --force;; esac
  if ! sh "$fixture/scripts/uninstall.sh" "$@" > "$TMP/output" 2>&1; then
    fail "uninstall failed ($mode)"
  fi
  case "$mode" in
    dry-run)
      [ -f "$hashes" ] && [ -f "$doc/AUTHORS.gutenprint" ] || fail "dry-run deleted files"
      ;;
    actual|force)
      [ ! -e "$hashes" ] && [ ! -e "$manifest" ] || fail "bookkeeping files retained"
      [ ! -e "$doc/AUTHORS.gutenprint" ] || fail "unchanged file retained"
      ;;
  esac
  if [ "$mode" = force ]; then
    [ ! -e "$xml" ] && [ ! -e "$ppd" ] || fail "--force retained modified files"
  else
    [ "$(cat "$xml")" = modified ] && [ "$(cat "$ppd")" = modified ] \
      || fail "modified files deleted ($mode)"
    grep -Fq "MODIFIED $xml" "$TMP/output" || fail "XML modification guard skipped"
    grep -Fq "MODIFIED $ppd" "$TMP/output" || fail "PPD modification guard skipped"
  fi
  [ ! -s "$MOCK_LOG" ] || fail "uninstall unexpectedly changed queues or receipts"
  ok "$mode: XML and PPD protection remains correct after the hash-file entry"
done

echo "test-helpers: PASS"
