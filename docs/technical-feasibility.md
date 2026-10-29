# Technical Feasibility — HP LaserJet 1022 on Apple Silicon macOS

Status: **UNVERIFIED on real hardware** — Phase 0 research document.
Last updated: 2026-10-29. Target platform: Mac (Apple Silicon, M2), macOS 15.8 Sequoia, USB.

This document answers the question required before implementation:

> Does building Gutenprint 5.3.5 and selecting its `hp-lj_1022` model produce
> print data that a physical HP LaserJet 1022 can actually print?

Short answer: **it cannot be confirmed from documentation alone, and the
weight of available evidence suggests it probably cannot.** The build and
packaging work proceeds anyway (it is needed either way), but the project
status is *Experimental — hardware testing required*, and the foo2zjs
fallback path stays on the table.

---

## 1. What Gutenprint ships for `hp-lj_1022`

Gutenprint 5.3.5 lists the printer. Verified directly in the release tarball
(`gutenprint-5.3.5.tar.xz`, SHA-256
`f5a9f47de28530b1ae2069cfbc647a9a641baeeabe809bb0ef2b3ec5b9668d70`):

```
src/xml/printers/pcl.xml:560:
  <printer name="HP LaserJet 1022" driver="hp-lj_1022"
           manufacturer="HP" model="6" parameters="pcl_laser_params" />
```

The entry lives in the **PCL family** (`<family name="pcl">`), and `model="6"`
resolves in `src/main/print-pcl.c` (`pcl_model_capabilities[]`, model 6,
comment: "LaserJet 4 series (except as above), 5 series, 6 series"):

| Capability | Value |
|---|---|
| Color | `PCL_COLOR_NONE` (monochrome) |
| Resolutions | 150, 300, 600 dpi |
| Printer type | `PCL_PRINTER_LJ` + `NEW_ERG` + `TIFF` + `BLANKLINE` + `DUPLEX` + `COPIES` |
| Paper | `ljsmall_papersizes` (Letter/Legal/A4/Executive + common small sizes) |

So Gutenprint's `rastertogutenprint.5.3` filter renders CUPS raster to a
**standard PCL 5e raster stream** (PCL escape sequences + `ESC * r # b`
PackBits/TIFF-compressed raster graphics). The listing is genuine — not added
by third parties (the theshiver project's `pcl-extra-printers.xml` patch only
adds Brother HL-2170W, HP M201/M202/M225/M226 and Xerox 8560N — *not* the
1022, confirming the 1022 entry is upstream).

**Verified with real bytes on this machine** (2026-10-29, macOS 15.8 arm64):
running the actual built filter the way cupsd does —

```
cupsfilter -m application/vnd.cups-raster -p <our-PPD> in.txt > job.raster
PPD=<our-PPD> STP_DATA_PATH=<xml> rastertogutenprint.5.3 1 u t 1 opts < job.raster > out.pcl
```

— produces a well-formed PCL 5e job: `1b45` (ESC E reset), `&l6D &k12H &l0O
&l2A &l66P`, `*t300R` (300 dpi raster res), `*b2M` (PackBits), `*r2400S
*r3200T *r1A`, `*b#W` raster rows. So the *software* path is fully proven
end-to-end; only the printer's acceptance of that stream is unknown.
(This pipeline is also `tests/test-dependencies.sh`'s smoke test.)

The same entry has existed since at least Gutenprint 5.2.0-rc1 (2008), per a
contemporaneous `lpinfo -m` dump in Ubuntu bug #250872.

## 2. What the printer physically speaks

The HP LaserJet 1022 is a low-end mono laser sold ~2006–2010 (18 ppm,
USB-only; `n`/`nw` add networking).

### 2.1 OpenPrinting / Foomatic database

`db/source/printer/HP-LaserJet_1022.xml` (OpenPrinting/foomatic-db, master):

```xml
<lang><pcl level="5e" /><proprietary /></lang>
<driver>foo2zjs-z1</driver>
IEEE-1284 ID: MFG:Hewlett-Packard;MDL:HP LaserJet 1022;CMD:ACL;CLS:PRINTER;...
Comment: "PCL 5e and ZjStream."  Functionality: A (best rating)
```

Two readings compete here:

- The `<lang>` element and the comment claim **PCL 5e** support.
- The **recommended driver is `foo2zjs-z1`** — the ZjStream host-based driver —
  and the comment itself says foo2zjs is "much faster and more reliable than
  HPIJS" (a PCL-class driver), implying PCL-class drivers work *if at all*
  only in a degraded mode. The IEEE-1284 `CMD` field advertises only `ACL`
  (HP's host-based command set for this generation), **not** `PCL` or `ZJS`.
  Foomatic `<lang>` entries for host-based printers are historically
  unreliable; they often reflect what marketing or a probe string suggested
  rather than verified wire behaviour.

### 2.2 foo2zjs upstream (Rick Richardson / OpenPrinting)

foo2zjs exists precisely because these printers are host-based:

> "These printers are often erroneously referred to as 'winprinters' or
> 'GDI printers'." — Free Software Directory entry for foo2zjs.

`foo2zjs-z1` covers HP LaserJet 1018, 1020, **1022**, M1319MFP, P2035
(foo2zjs ChangeLog, 2010-05-28: "foo2zjs-z1 - HP 1018, 1020, 1022, M1319MFP,
P2035"). The driver converts Ghostscript-rendered pages into the ZjStream
wire format.

### 2.3 Direct on-hardware statement (most relevant evidence)

The `edla/hp-laserjet-zjs-macos` project extracted HP's own
`hplaserjetzjs.bundle` CUPS filter from Apple's last HP driver package and
tested on real hardware (stated: LaserJet 1022 on macOS 26.4, Apple Silicon):

> "These printers are **host-based**: they have no PCL or PostScript
> interpreter of their own and can only print pages pre-rendered by the
> computer in HP's ZjStream (ZJS) format. … if you add one with a generic
> 'HP LaserJet' PCL driver, they print **garbage or nothing**."

This is the only statement located that is grounded in a real 1022 on
Apple-Silicon-era macOS, and it directly contradicts the Foomatic `pcl 5e`
language claim.

### 2.4 Firmware loading is NOT required for the 1022

Sibling ZjStream models (1018/1020/P1005/P1505…) need a `sihp*.dl` firmware
download at every power-on; foo2zjs ships `hplj10xx.conf`/`hplj1000` hotplug
rules for exactly: 1000, 1005, 1018, 1020, P1005–P1008, P1505 — **no 1022
entry**. The 1022's interpreter lives in flash; after power-on it is ready to
accept ZjStream jobs. This removes the hardest part of any foo2zjs port to
macOS (no privileged USB hotplug machinery needed — print data goes through
Apple's stock `usb` CUPS backend).

## 3. What third-party macOS packaging actually does

`theshiver/apple-silicon-printer-drivers` (v1.3.11 inspected) ships
Gutenprint 5.3.5 arm64 and lists `hp-lj_1022` as supported. Useful and
verified build facts borrowed from it:

- Configure prefix under `/Library/Printers/...`; filters installed via
  `cups-config --serverbin` (here: `/usr/libexec/cups`), so `make install
  DESTDIR=…` stages filters at `usr/libexec/cups/filter/`.
- Generated PPDs are rewritten so `*cupsFilter` uses an **absolute path**
  under `/Library/Printers/…` — proving modern macOS CUPS accepts absolute
  filter paths (avoids touching the SIP-protected `/usr/libexec/cups/filter`).
- `LC_ALL=C` must wrap `cups-genppd` (comma-decimal `PageSize[612,000 …]`
  broke every Gutenprint PPD on German/Turkish/French locales — their
  v1.3.11 changelog).
- `*CustomStp*`/`*ParamCustomStp*` PPD blocks are dropped because they break
  the Printer Features sheet on macOS 26/27 (their issue #1).
- Binaries are ad-hoc `codesign`ed when no Developer ID exists.

**Not adopted** (project rules forbid): their `postinstall` moves
`/Library/Extensions/BJUSBLoad.kext`, `/Library/Printers/Canon`,
`CanonIJ*.ppd.gz`, runs `rm -rf /Library/Caches/Canon`, deletes queues
referencing Canon filters, auto-detects every `usb://` device, creates
queues and runs `lpadmin -d` to set a default. This package is payload-only
and never touches other vendors' files or existing queues.

Note: theshiver's "supported" list is a model catalog derived from
Gutenprint's own XML — it is not evidence of an on-hardware print test for
this specific model.

## 4. Conclusion

| Claim | Verdict |
|---|---|
| Gutenprint 5.3.5 contains an `hp-lj_1022` model | **Confirmed** (pcl.xml:560) |
| Gutenprint emits PCL 5e raster for it | **Confirmed** (print-pcl.c model 6 + byte-level proof, §1) |
| Built filter runs as a CUPS filter on this Mac | **Confirmed** (real pipeline, §1) |
| The 1022 hardware accepts PCL 5e | **Contested — probably false** |
| The 1022 needs a firmware upload | **No** (not in foo2zjs firmware tables) |
| The 1022 accepts ZjStream | **Confirmed** (foo2zjs-z1 target device, Foomatic driver-of-record) |

**Verdict: proceed with the Gutenprint build as the primary (and only
in-scope) path, but do not claim hardware support.** Everything else in the
pipeline — packaging, PPD handling, queue setup, uninstall, tests — is
identical whichever raster filter is used, so no work is wasted if the
fallback is needed.

### Fallback path (foo2zjs) — only if hardware testing fails

If a real 1022 rejects the PCL stream, the alternative is a `foo2zjs-z1`
CUPS raster filter + 1022 PPD (GPL, OpenPrinting/foo2zjs). No firmware
upload needed for this model (§2.4). That swap is confined to: one extra
filter binary, one PPD, and the same install/uninstall machinery. It is
*not* built in this iteration — per project rules it is only added with
evidence that Gutenprint's PCL output fails on real hardware.

### How the question gets settled definitively (needs the printer)

1. `system_profiler SPUSBDataType` / USB probe: capture the IEEE-1284
   `CMD` field. `CMD:ACL` alone ⇒ no PCL interpreter advertised.
2. Send the built PPD + `rastertogutenprint.5.3` output to the printer.
   Page prints ⇒ PCL path works (Foomatic lang entry vindicated).
   Garbage/silence ⇒ ZjStream-only, move to foo2zjs.
3. Both steps are scripted in `docs/testing.md` and require the physical
   device.

## 5. Evidence index

| # | Source | Used for |
|---|---|---|
| 1 | `gutenprint-5.3.5/src/xml/printers/pcl.xml:560` | model entry exists upstream |
| 2 | `gutenprint-5.3.5/src/main/print-pcl.c:1326` (model 6 caps) | output = PCL 5e mono raster ≤600 dpi |
| 3 | `OpenPrinting/foomatic-db …/HP-LaserJet_1022.xml` | lang pcl5e+proprietary; driver=foo2zjs-z1; CMD:ACL |
| 4 | `OpenPrinting/foo2zjs` README + ChangeLog 2010-05-28 | 1022 = ZjStream (z1) family |
| 5 | `github.com/edla/hp-laserjet-zjs-macos` README | on-hardware: ZjStream-only, PCL→garbage/nothing |
| 6 | foo2zjs `hplj10xx.conf` / `hplj1000` | 1022 absent ⇒ no firmware upload needed |
| 7 | Ubuntu bug #250872 (2008) `lpinfo -m` | hp-lj_1022 listed since 5.2.0-rc1; foo2zjs "recommended" |
| 8 | theshiver repo v1.3.11 build/scripts | packaging techniques (adopted in part), install logic (rejected) |
| 9 | theshiver v1.3.11 release notes | LC_ALL=C genppd bug fix; *CustomStp* drop (issue #1) |
