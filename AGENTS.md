# Agent notes — hp1022-macos-driver

## What this is

Single-model macOS printer driver package: HP LaserJet 1022 (USB) on
Apple Silicon, built from Gutenprint 5.3.5 source. **Status: Experimental —
real-hardware printing unverified.** Read `docs/technical-feasibility.md`
before touching anything — the PCL-vs-ZjStream question is the core risk.

## Commands

```sh
make fetch     # download + SHA-256 verify sources.lock entries
make build     # configure/make gutenprint -> stage/raw, assemble stage/payload
make verify    # arch/deps/PPD/whitelist inspection
make package   # unsigned .pkg into dist/
make test      # all tests in tests/ (no printer needed)
make clean     # rm stage/      (keeps build/ and dist/)
make distclean # rm build+dist+stage
```

## Hard rules (spec-enforced — do not violate)

- Payload writes ONLY to `/Library/Printers/HP1022-Gutenprint/` and the
  single PPD under `/Library/Printers/PPDs/Contents/Resources/`.
- Never modify `/System`, `/usr/libexec/cups`, other vendors' driver dirs.
- No pre/postinstall scripts in the pkg. No `lpadmin -d`. No queue scanning
  or creation except explicit `add-printer.sh` on a chosen 1022 URI.
- No sudo for download/build/test. No curl-pipe-shell. No remote repos
  created, no releases published.
- Never claim hardware support without a real printout; keep status
  "Experimental / hardware testing required" until `docs/testing.md` H4+H12
  pass on a physical 1022.
- Upstream source stays unmodified; needed changes go in `patches/`.

## Commit conventions

All commits use the form:

```
type(scope): short imperative description
```

- `type` — `feat` `fix` `docs` `build` `test` `ci` `refactor` `chore`
  `security`
- `scope` — the area touched, e.g. `scripts` `tests` `docs` `ci`
  `build` `ppd` `pkg` `install` `uninstall` `deps` `license`
- No attribution/trailer footers (no Co-Authored-By, no tool signatures).
- Body optional, wrapped at ~72 cols, explains the *why*.

Examples: `feat(install): add --dry-run mode`, `fix(ppd): force LC_ALL=C
in genppd call`, `docs(feasibility): record PCL output proof`.

## Conventions

- All scripts are POSIX `sh`, `set -eu`, resolve repo root from `$0`.
- Install prefix compiled into binaries: `/Library/Printers/HP1022-Gutenprint`.
- PPD `*cupsFilter` uses the absolute filter path under that prefix
  (SIP prevents shipping filters in `/usr/libexec/cups/filter`).
- `LC_ALL=C` whenever running `cups-genppd` (comma-decimal locale breaks PPDs).
- Strip `*CustomStp*`/`*ParamCustomStp*` blocks from generated PPDs.
- Ad-hoc `codesign -s -` on payload binaries; pkg is unsigned (never
  describe this as notarization).
