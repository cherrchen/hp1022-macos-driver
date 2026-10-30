# hp1022-macos-driver

**中文** · [English](README.en.md)

一个最小化、可审计的驱动包,让 **HP LaserJet 1022**(USB)在
Apple Silicon macOS 上打印 —— 从 **Gutenprint 5.3.5** 官方源码构建,
不使用预编译二进制,不改 SIP,不装内核扩展,不需要 Rosetta。

> **当前状态:实机验证通过。**
> 2026-10-30 一台物理 1022(FWVER 20050401)经完整 CUPS 安装管道
> 打印成功,[`docs/testing.md`](docs/testing.md) 硬件矩阵全部通过
> (H1–H12 ☑)。仅验证过这一台设备,其他硬件版本可能不同。分析见
> [`docs/technical-feasibility.md`](docs/technical-feasibility.md)。

## 支持范围

| | |
|---|---|
| 打印机 | HP LaserJet 1022(USB)—— 仅单一型号,不自动探测其他型号 |
| Mac | Apple Silicon(arm64) |
| 系统 | macOS 15.x Sequoia(开发环境 15.8);14+ 大概率可用 |

## 构建与安装

克隆本仓库后:

```sh
make package                  # 拉取锁定源码 → 校验 SHA-256 → 编译 arm64
                              # → 审计 payload → 生成安装包到 dist/
./scripts/install.sh          # 列出将安装的文件,然后 sudo installer 安装
./scripts/add-printer.sh      # 创建打印队列(一般无需 sudo)
```

需要 Xcode Command Line Tools。构建全程在 `build/ stage/ dist/` 内
以普通权限进行,仅最后的 `installer` 步骤需要 sudo。

安装**仅复制文件,不含任何安装脚本**:除文件拷贝外不会以 root 身份
执行代码,不会创建打印队列,不会改默认打印机,不会动其他厂商的
驱动文件。

## 卸载

```sh
sudo ./scripts/uninstall.sh --dry-run        # 先查看移除计划
sudo ./scripts/uninstall.sh                  # 按清单移除文件
sudo ./scripts/uninstall.sh --remove-queue   # 同时移除本驱动的打印队列
```

## 仓库结构

```
scripts/      下载源码、构建、审计、打包、安装、建队列、卸载
tests/        源码哈希、payload 白名单、依赖、安全策略检查
docs/         可行性、架构、安全、安装、测试、排障文档
sources.lock  锁定的上游 tarball + SHA-256
LICENSES/     GPL-2.0 文本(Gutenprint 使用 GPL-2.0)
dist/         (生成)安装包 + 清单 + 哈希
```

## 许可与来源

- **Gutenprint 5.3.5** —— GPL-2.0-or-later,SourceForge 官方源码、未修改,
  哈希锁定。对应源码:`sources/` tarball 或 `make fetch`。
  版权/作者文件随 payload 安装在 `share/doc/` 下。
- **本项目脚本与文档** —— GPL-2.0-or-later(见 `LICENSE`)。
- 不包含、不分发任何 HP 或 Apple 专有文件。

**本项目与 HP、Apple 均无关联。**

## 已知限制

- 仅单一打印机型号;不支持网络打印机;仅 USB。
- 仅在一台物理 1022(FWVER 20050401)上验证过 —— 其他硬件版本未测
  (若某台设备不接受 PCL,文档中留有 foo2zjs/ZjStream 备选方案)。
- `lpadmin` 提示 PPD 类驱动在未来 CUPS 版本中将弃用 —— macOS 15.x
  上正常,日后可能需要迁移到 IPP-everywhere 方案。
