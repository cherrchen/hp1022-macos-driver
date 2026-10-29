# hp1022-macos-driver

**English** · [中文](#中文说明)

A minimal, auditable driver package that tries to make the **HP LaserJet
1022** (USB) print on Apple-Silicon macOS, built from upstream
**Gutenprint 5.3.5** source — no prebuilt blobs, no SIP changes, no kernel
extensions, no Rosetta.

> ⚠️ **Status: Experimental — hardware testing required.**
> The LaserJet 1022 is most likely a host-based **ZjStream** printer and
> Gutenprint's `hp-lj_1022` entry emits **PCL 5e**. Whether the hardware
> accepts PCL is unresolved — the evidence leans towards *no*. Everything
> builds and installs correctly; actual printing is unverified. Details and
> the foo2zjs fallback plan: [`docs/technical-feasibility.md`](docs/technical-feasibility.md).

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
- PCL-path printing unverified on hardware — may produce no output at all
  (then the ZjStream/foo2zjs path becomes necessary).
- Package unsigned; notarization requires an Apple Developer ID (CI hook
  exists, keys not provisioned).

---

## 中文说明

一个最小化、可审计的驱动包,尝试让 **HP LaserJet 1022**(USB)在
Apple Silicon macOS 上打印 —— 从 **Gutenprint 5.3.5** 官方源码构建,
不使用预编译二进制,不改 SIP,不装内核扩展,不需要 Rosetta。

> ⚠️ **当前状态:实验性 —— 需要实机验证。**
> LaserJet 1022 很可能只支持 host-based **ZjStream** 协议,而 Gutenprint
> 的 `hp-lj_1022` 输出的是 **PCL 5e**。硬件是否接受 PCL 尚无定论(证据
> 偏向“不支持”)。构建、安装流程可用,但能否真正打印未经验证。详见
> [`docs/technical-feasibility.md`](docs/technical-feasibility.md),备选
> 方案为 foo2zjs。

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
