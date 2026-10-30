# hp1022-macos-driver

**English** · [中文](#中文说明)

A minimal, auditable driver package that makes the **HP LaserJet
1022** (USB) print on Apple-Silicon macOS, built from upstream
**Gutenprint 5.3.5** source — no prebuilt blobs, no SIP changes, no kernel
extensions, no Rosetta.

> ⚠️ **Status: working on real hardware — still experimental distribution.**
> On 2026-10-30 a physical 1022 (FWVER 20050401) printed Gutenprint's PCL 5e
> output through the full installed CUPS pipeline, and the entire hardware
> matrix in [`docs/testing.md`](docs/testing.md) passed (H1–H12 ☑).
> Caveats: verified on a single unit; the package is unsigned/unnotarized;
> CUPS marks PPD-class drivers deprecated on future macOS.
> Analysis: [`docs/technical-feasibility.md`](docs/technical-feasibility.md).

## Supported

| | |
|---|---|
| Printer | HP LaserJet 1022 (USB) — single model, no auto-detection of others |
| Mac | Apple Silicon (arm64) |
| OS | macOS 15.x Sequoia (developed on 15.8); probably 14+ |

## Build

```sh
make package     # fetch pinned source, verify SHA-256, build arm64,
                 # audit payload, emit unsigned .pkg + SHA256SUMS into dist/
```

Requires Xcode Command Line Tools. Everything runs unprivileged inside
`build/ stage/ dist/`.

## Install

```sh
pkgutil --payload-files dist/HP1022-Gutenprint-0.1.0.pkg   # audit first
./scripts/install.sh                                      # sudo installer (files only)
sudo ./scripts/add-printer.sh                             # optional: create the queue
```

The package is **unsigned and not notarized** — install explicitly via
`installer`. It has **no install scripts**: nothing executes as root, no
queues are created, the default printer is never changed, and no other
vendor's driver files are touched.

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
- Package unsigned; notarization requires an Apple Developer ID (CI hook
  exists, keys not provisioned).
- `lpadmin` warns that PPD-class drivers are deprecated in a future CUPS
  release — fine on macOS 15.x, may need an IPP-everywhere revisit later.

---

## 中文说明

一个最小化、可审计的驱动包,让 **HP LaserJet 1022**(USB)在
Apple Silicon macOS 上打印 —— 从 **Gutenprint 5.3.5** 官方源码构建,
不使用预编译二进制,不改 SIP,不装内核扩展,不需要 Rosetta。

> ⚠️ **当前状态:实机可打印 —— 分发层面仍属实验性。**
> 2026-10-30 一台物理 1022(FWVER 20050401)经完整 CUPS 安装管道
> 打印成功,[`docs/testing.md`](docs/testing.md) 硬件矩阵全部通过
> (H1–H12 ☑)。注意:仅验证过这一台设备;pkg 未签名未公证;
> CUPS 已将 PPD 类驱动标记为弃用。分析见
> [`docs/technical-feasibility.md`](docs/technical-feasibility.md)。

### 支持范围

- 打印机:仅 HP LaserJet 1022(USB),不自动探测其他型号
- 硬件:Apple Silicon(arm64);系统:macOS 15.x(开发环境 15.8)

### 构建 / 安装 / 卸载

```sh
make package                        # 拉源码 → 校验哈希 → 编译 arm64 → 生成 pkg
./scripts/install.sh                # 安装驱动文件(sudo installer,仅文件)
sudo ./scripts/add-printer.sh       # 可选:手动创建打印队列
sudo ./scripts/uninstall.sh --dry-run   # 卸载前先看计划
sudo ./scripts/uninstall.sh             # 按清单卸载,保留打印队列
```

安装包**未签名、未公证**,且**不含任何安装脚本**:安装时不会以 root
身份执行代码,不会创建打印队列,不会改默认打印机,不会动其他厂商的
驱动文件。

### 许可

Gutenprint 为 GPL-2.0-or-later(未修改上游源码,锁定 SHA-256);本项目
脚本与文档同样采用 GPL-2.0-or-later(见 `LICENSE`)。
**本项目与 HP、Apple 均无关联。**
