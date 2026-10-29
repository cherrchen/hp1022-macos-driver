# Troubleshooting

## Diagnosing what the printer understands (do this FIRST)

Before assuming the driver is broken, check what the printer advertises:

```sh
system_profiler SPUSBDataType | grep -A 8 -i 'laserjet 1022'
```

Look for the IEEE-1284 Device ID string / `CMD` field. If it shows only
`ACL` (host-based) and no `PCL`, the printer likely speaks **ZjStream only**
— the expected failure mode for the Gutenprint PCL path
(`docs/technical-feasibility.md`).

## "Printer software is not compatible" / driver missing

The PPD must point at an existing filter. Check:

```sh
grep cupsFilter "/Library/Printers/PPDs/Contents/Resources/HP1022-Gutenprint-hp-lj_1022.ppd"
ls -l /Library/Printers/HP1022-Gutenprint/libexec/rastertogutenprint.5.3
```

If either is missing, reinstall via `scripts/install.sh`.

## Job accepted, nothing prints (the expected PCL-incompatibility case)

Symptoms: `lp` accepts the job, queue shows "Printing", printer stays silent
or wakes then stops. This is the documented risk: the 1022 is probably
ZjStream-only and discards PCL 5e data.

Collect evidence:

```sh
lpstat -o
tail -50 /var/log/cups/error_log          # filter/backend errors
sudo cupsctl --debug-logging              # then retry once, then --no-debug-logging
```

If the filter ran cleanly (`rastertogutenprint.5.3` finished, `usb` backend
sent bytes) and the printer produced nothing → strong evidence for the
ZjStream-only hypothesis. Report it in `docs/testing.md` terms; that result
flips the project to the foo2zjs fallback path.

## Job stuck in queue / "filter failed"

```sh
tail -100 /var/log/cups/error_log | grep -i 'gutenprint\|filter'
```

- `Unable to execute /Library/Printers/HP1022-Gutenprint/...` → file missing
  or unsigned/blocked: check `codesign -v` and reinstall.
- `rastertogutenprint` + "PPD from another version" → the PPD was generated
  by a different Gutenprint version; regenerate with our `cups-genppd.5.3`.

## PPD shows empty/broken Printer Features sheet

Fixed upstream-workaround already applied at build: `*CustomStp*`/
`*ParamCustomStp*` blocks are stripped from the generated PPD. If you
regenerate the PPD manually with `cups-genppd.5.3`, re-apply the same
`perl -pe` filter as in `scripts/build.sh` (and use `LC_ALL=C`).

## PageSize / "Unknown operator" errors

Caused by a comma-decimal locale during PPD generation. Our build forces
`LC_ALL=C`; if you regenerate the PPD by hand, do the same.

## macOS says the package is unsigned/damaged

Expected: the pkg is ad-hoc–signed binaries in an **unsigned** package.
Install explicitly via `sudo installer -pkg … -target /` or
`scripts/install.sh`. Do not disable Gatekeeper globally for this.

## Removing everything

```sh
sudo scripts/uninstall.sh --dry-run && sudo scripts/uninstall.sh --remove-queue
```
