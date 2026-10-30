# Testing

Two layers: **automated** (runs without the printer) and **hardware**
(requires a physical HP LaserJet 1022). The project may only leave
"Experimental" status when the hardware matrix below is actually executed.

## Automated

```sh
make test          # runs everything in tests/
```

| Test | Covers |
|---|---|
| `tests/test-build.sh` | sources.lock SHA-256, staged artifacts exist, arm64-only, `cups-genppd` lists `hp-lj_1022`, manifest↔payload consistency |
| `tests/test-payload.sh` | install-path whitelist, no SIP/other-vendor paths, only our executables, PPD syntax + filter path resolves inside payload, pkg has zero install scripts |
| `tests/test-dependencies.sh` | `otool -L` audit (no Homebrew/user/tmp paths), filter executes, genppd resolves XML data, `cupsfilter` end-to-end chain smoke test |
| `tests/test-security.sh` | forbidden-operation grep audit (Canon paths, `lpadmin -d`, queue scans, `rm -rf` on shared dirs, curl-pipe-shell, SIP writes), uninstall guardrails |
| `tests/test-helpers.sh` | isolated uninstall modification protection, HP 1022 URI selection, queue command failures and safe forced updates (mocked CUPS; no admin rights) |
| `tests/test-package.sh` | built `.pkg` audit: install-path whitelist on `pkgutil --payload-files`, required contents, BOM↔manifest consistency, root:wheel ownership + modes, zero install scripts, sha256 sidecar (skips when no pkg; `REQUIRE_PKG=1` makes it mandatory — CI runs it after packaging) |

## Hardware matrix — DO NOT mark done without a real printout

Legend: ☐ untested / ☑ pass / ✘ fail — fill in with date + macOS build.

| # | Case | Steps | Expected | Result |
|---|---|---|---|---|
| H1 | USB enumeration | plug in, power on; `system_profiler SPUSBDataType` | printer listed; record IEEE-1284 `CMD:` field | ☑ 2026-10-30, macOS 15.8 (24H23): PID 0x2c17, S/N JM1ALN6, FWVER 20050401; 1284 `CMD:ACL` only (no PCL/ZJS advertised) |
| H2 | Device URI | `lpinfo -v` | `usb://HP/LaserJet%201022?serial=…` present | ☑ 2026-10-30: `usb://Hewlett-Packard/HP%20LaserJet%201022?serial=JM1ALN6` (URI form differs from Linux — detection regex fixed in add-printer.sh) |
| H3 | Queue add | `sudo scripts/add-printer.sh` | queue `HP_LaserJet_1022` created, enabled | ☑ 2026-10-30: queue created via `_lpadmin` group (no sudo needed); after `sudo installer` the queue was rebound to the installed PPD via `--force` |
| H4 | **Single text page** | `lp -d HP_LaserJet_1022 /etc/cups/cupsd.conf` | page prints cleanly (not blank, not garbage) | ☑ 2026-10-30: **clean text page printed.** Two ways: (a) `lp -o raw` of the exact 840,924-byte PCL stream rastertogutenprint.5.3 emits — printed; (b) full installed pipeline `lp` (cupsd→rastertogutenprint as _lp→usb backend, job 130) — printed. cupsd refused repo-path filters before install (uid=99, `noowners` volume) as expected |
| H5 | Multi-page PDF | print 3-page PDF via any app | all pages, correct order | ☑ 2026-10-30: 3-page PDF (job 131) — all pages in order |
| H6 | CJK text | print document with 中文 | glyphs render, no tofu | ☑ 2026-10-30: 简/繁中文+日文かな (job 132) rendered, no tofu |
| H7 | Image/grayscale | print photo-heavy PDF | halftone shading sane | ☑ 2026-10-30: 1.8MB screen-capture PNG (job 133) — grayscale/halftone sane |
| H8 | A4 paper | `lp -o PageSize=A4 …` | correct page geometry | ☑ 2026-10-30: `-o PageSize=A4` (job 134) on A4-loaded tray — correct geometry |
| H9 | 600 dpi | Printer Features → 600 dpi | job completes | ☑ 2026-10-30: `-o Resolution=600dpi` 3-page job (135) completed |
| H10 | Cancel job | `cancel -a HP_LaserJet_1022` mid-job | job cancels, printer recovers | ☑ 2026-10-30: cancel of image job accepted; already-buffered page still printed (expected — sent bytes can't be unsent); probe page (job 138) printed after — queue recovered |
| H11 | Reboot+replug | restart Mac, replug USB | queue still prints, no re-add needed | ☑ 2026-10-30: after reboot + USB replug, `lp` (job 139) printed immediately — queue persisted, no re-add |
| H12 | **Protocol verdict** | evaluate H4 | PCL accepted → stay on Gutenprint; garbage/silent → switch to foo2zjs path | ☑ 2026-10-30: **PCL accepted — stay on Gutenprint.** foo2zjs fallback not needed. Contradicts edla "ZJS-only" claim; Foomatic `pcl 5e` vindicated on real hardware (FWVER 20050401) |

**H4 and H12 are the gating tests.** If the first page is garbage or the
printer never wakes, the PCL path is dead and `technical-feasibility.md` §4
fallback applies.

## Recording results

File an issue/PR updating this table with: macOS build (`sw_vers`), printer
firmware-ish info (`system_profiler` dump), PPD name used, per-row result,
and `error_log` excerpts for failures.
