# Security model

Everything the package and scripts do — and deliberately do **not** do.

## What the installer package does

The `.pkg` produced by `scripts/package.sh` is a **pure payload** package
(`pkgbuild --root …` with no `--scripts` directory — there is no
`preinstall`/`postinstall`, so nothing executes as root during install).

Installing it (via `sudo installer` or double-click) writes exactly:

```
/Library/Printers/HP1022-Gutenprint/**          (binaries, data, docs)
/Library/Printers/PPDs/Contents/Resources/HP1022-Gutenprint-hp-lj_1022.ppd
```

Verify before installing:

```sh
pkgutil --check-signature HP1022-Gutenprint-<ver>.pkg   # Status: unsigned (expected)
pkgutil --payload-files   HP1022-Gutenprint-<ver>.pkg   # audit the file list
pkgutil --expand          HP1022-Gutenprint-<ver>.pkg /tmp/x && ls /tmp/x   # no Scripts dir
shasum -a 256 HP1022-Gutenprint-<ver>.pkg               # compare with SHA256SUMS
```

## Explicit non-actions (project rules)

| Promise | Enforcement |
|---|---|
| No SIP changes | nothing under `/System`, `/usr/libexec/cups`, `/bin`, `/sbin`, `/private` is written; audited by `tests/test-security.sh` + `scripts/verify.sh` |
| No kernel extensions | nothing under `/Library/Extensions`; no `kmutil`/`kextload` anywhere |
| No Rosetta | binaries are arm64-only (`lipo`/`file` checks in `tests/`) |
| No other-vendor modification | no code references `/Library/Printers/Canon`, `/Library/Caches/Canon`, `BJUSBLoad.kext`, Brother/Samsung/Epson dirs |
| No queue scanning/rebuild | nothing iterates `lpstat`/system queues except `add-printer.sh` matching an explicit HP-1022 `usb://` URI |
| No default-printer changes | `lpadmin -d` / `lpoptions -d` absent; test asserts it |
| No remote code execution | fetch verifies SHA-256 *before* extraction; nothing pipes downloads to a shell |
| No sudo for download/build | build runs unprivileged under `build/`+`stage/`; sudo only wraps `installer`/`lpadmin`/uninstall |

## What needs admin rights (and why)

| Action | Command | Why |
|---|---|---|
| Install pkg | `sudo installer -pkg … -target /` | writes `/Library/Printers/**` |
| Create queue | `sudo scripts/add-printer.sh` | `lpadmin` needs admin |
| Uninstall | `sudo scripts/uninstall.sh` | removes files under `/Library` |

Nothing else requires elevation.

## Supply chain

- `sources.lock` pins `gutenprint-5.3.5.tar.xz` to SHA-256
  `f5a9f47de28530b1ae2069cfbc647a9a641baeeabe809bb0ef2b3ec5b9668d70`
  (SourceForge, HTTPS). Verified before extraction and again at build.
- Binaries get an **ad-hoc** `codesign -s -` signature for Mach-O integrity.
  This is *not* Developer ID signing and *not* notarization — the pkg is
  unsigned, and this README/docs say so plainly.
- `dist/payload-manifest.txt` + `dist/payload-sha256sums.txt` are emitted per
  build — the complete, sorted list of installed files and their hashes.
- No upstream source modifications. Patches, if ever needed, live in
  `patches/` and are applied + logged by `build.sh`.

## Uninstall safety

`uninstall.sh` removes only manifest-listed files, refuses entries outside
the expected scope, skips files modified since install (SHA-256 compare,
unless `--force`), removes directories only when empty, and keeps queues
unless `--remove-queue`. `--dry-run` shows the full plan first.
