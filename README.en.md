# hp1022-macos-driver

**English** · [中文](README.md)

A minimal, auditable driver package that makes the **HP LaserJet
1022** (USB) print on Apple-Silicon macOS, built from upstream
**Gutenprint 5.3.5** source — no prebuilt blobs, no SIP changes, no kernel
extensions, no Rosetta.

> **Status: verified on real hardware.**
> On 2026-10-30 a physical 1022 (FWVER 20050401) printed Gutenprint's PCL 5e
> output through the full installed CUPS pipeline, and the entire hardware
> matrix in [`docs/testing.md`](docs/testing.md) passed (H1–H12 ☑).
> Verified on a single unit — your mileage may vary on other 1022
> revisions. Analysis: [`docs/technical-feasibility.md`](docs/technical-feasibility.md).

## Supported

| | |
|---|---|
| Printer | HP LaserJet 1022 (USB) — single model, no auto-detection of others |
| Mac | Apple Silicon (arm64) |
| OS | macOS 15.x Sequoia (developed on 15.8); probably 14+ |

## Build & install

Clone this repo, then:

```sh
make package                  # fetch pinned source, verify SHA-256,
                              # build arm64, audit payload -> dist/
./scripts/install.sh          # shows payload list, then sudo installer
./scripts/add-printer.sh      # create the queue (no sudo needed on most Macs)
```

Requires Xcode Command Line Tools. Everything builds unprivileged inside
`build/ stage/ dist/`; only the final `installer` step needs sudo.

The installer is **payload-only, no install scripts**: nothing executes as
root beyond file copying, no queues are created, the default printer is
never changed, and no other vendor's driver files are touched.

## Uninstall

```sh
sudo ./scripts/uninstall.sh --dry-run        # review plan
sudo ./scripts/uninstall.sh                  # removes files (manifest-driven)
sudo ./scripts/uninstall.sh --remove-queue   # also removes our queue(s)
```

## Repository layout

```
scripts/    fetch-source, build, verify, package, install, add-printer, uninstall
tests/      source-hash, payload whitelist, deps, security-policy checks
docs/       feasibility, architecture, security, installation, testing, troubleshooting
sources.lock  pinned upstream tarball + SHA-256
LICENSES/   GPL-2.0 text (Gutenprint is GPL-2.0)
dist/       (generated) pkg + manifest + hashes
```

## Licenses & provenance

- **Gutenprint 5.3.5** — GPL-2.0-or-later, unmodified upstream source from
  SourceForge (hash-pinned). Corresponding source: `sources/` tarball or
  `make fetch`. Copyright/author files ship in the payload under
  `share/doc/`.
- **This project's scripts/docs** — GPL-2.0-or-later (see `LICENSE`).
- No HP or Apple proprietary files are included or redistributed.

**This project is not affiliated with HP or Apple.**

## Known limitations

- Single printer model; no network printers; USB only.
- Verified on one physical 1022 (FWVER 20050401) only — other hardware
  revisions untested (the foo2zjs/ZjStream fallback is documented if a
  different unit rejects PCL).
- `lpadmin` warns that PPD-class drivers are deprecated in a future CUPS
  release — fine on macOS 15.x, may need an IPP-everywhere revisit later.
