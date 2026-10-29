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

## Hardware matrix — DO NOT mark done without a real printout

Legend: ☐ untested / ☑ pass / ✘ fail — fill in with date + macOS build.

| # | Case | Steps | Expected | Result |
|---|---|---|---|---|
| H1 | USB enumeration | plug in, power on; `system_profiler SPUSBDataType` | printer listed; record IEEE-1284 `CMD:` field | ☐ |
| H2 | Device URI | `lpinfo -v` | `usb://HP/LaserJet%201022?serial=…` present | ☐ |
| H3 | Queue add | `sudo scripts/add-printer.sh` | queue `HP_LaserJet_1022` created, enabled | ☐ |
| H4 | **Single text page** | `lp -d HP_LaserJet_1022 /etc/cups/cupsd.conf` | page prints cleanly (not blank, not garbage) | ☐ |
| H5 | Multi-page PDF | print 3-page PDF via any app | all pages, correct order | ☐ |
| H6 | CJK text | print document with 中文 | glyphs render, no tofu | ☐ |
| H7 | Image/grayscale | print photo-heavy PDF | halftone shading sane | ☐ |
| H8 | A4 paper | `lp -o PageSize=A4 …` | correct page geometry | ☐ |
| H9 | 600 dpi | Printer Features → 600 dpi | job completes | ☐ |
| H10 | Cancel job | `cancel -a HP_LaserJet_1022` mid-job | job cancels, printer recovers | ☐ |
| H11 | Reboot+replug | restart Mac, replug USB | queue still prints, no re-add needed | ☐ |
| H12 | **Protocol verdict** | evaluate H4 | PCL accepted → stay on Gutenprint; garbage/silent → switch to foo2zjs path | ☐ |

**H4 and H12 are the gating tests.** If the first page is garbage or the
printer never wakes, the PCL path is dead and `technical-feasibility.md` §4
fallback applies.

## Recording results

File an issue/PR updating this table with: macOS build (`sw_vers`), printer
firmware-ish info (`system_profiler` dump), PPD name used, per-row result,
and `error_log` excerpts for failures.
