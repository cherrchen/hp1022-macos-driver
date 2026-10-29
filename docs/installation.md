# Installation

Status: **Experimental — hardware testing required.** The driver builds and
installs cleanly; whether a real LaserJet 1022 accepts its PCL 5e output is
unverified (see `docs/technical-feasibility.md`).

## Requirements

- Apple Silicon Mac (tested target: M2), macOS 15.x Sequoia
- HP LaserJet 1022 connected by USB
- Xcode Command Line Tools (`xcode-select --install`) — build only
- Admin rights — install + queue creation only

## 1. Build

```sh
make package        # fetch -> verify hash -> build -> verify -> unsigned pkg
```

or step by step:

```sh
./scripts/fetch-source.sh   # downloads + SHA-256 verifies gutenprint 5.3.5
./scripts/build.sh          # compiles into stage/, assembles payload
./scripts/verify.sh         # arch/deps/PPD/whitelist checks
./scripts/package.sh        # dist/HP1022-Gutenprint-0.1.0.pkg + SHA256SUMS
```

## 2. Inspect before installing (recommended)

```sh
pkgutil --check-signature dist/HP1022-Gutenprint-0.1.0.pkg  # unsigned (expected)
pkgutil --payload-files   dist/HP1022-Gutenprint-0.1.0.pkg  # exact file list
./scripts/install.sh --dry-run                             # same info via script
```

## 3. Install driver files

```sh
./scripts/install.sh        # wraps: sudo installer -pkg <pkg> -target /
```

This only copies files. No queues are created, no system state is modified.

## 4. Add the printer (manual, separate step)

Option A — System Settings:

> System Settings → Printers & Scanners → Add Printer → select the USB
> printer → *Use*: Select Software… → pick "HP1022-Gutenprint".

Option B — helper script:

```sh
sudo ./scripts/add-printer.sh                          # auto-selects a sole 1022
sudo ./scripts/add-printer.sh -u 'usb://HP/LaserJet%201022?serial=…'
./scripts/add-printer.sh --dry-run -u 'usb://…'        # preview, no changes
```

The helper: accepts only `usb://` URIs, only ones that look like an HP
LaserJet 1022 (unless `--force`), refuses to overwrite an existing queue,
never changes the default printer.

## 5. First print

```sh
lp -d HP_LaserJet_1022 /etc/cups/cupsd.conf     # or print any document
lpstat -o                                       # watch the job
```

Then follow the checklist in `docs/testing.md` and report results — that is
how this project graduates from "experimental".

## 6. Uninstall

```sh
sudo ./scripts/uninstall.sh --dry-run        # review the plan first
sudo ./scripts/uninstall.sh                  # removes files, keeps queues
sudo ./scripts/uninstall.sh --remove-queue   # also removes our queue(s)
```
