# RhetSim 开发平台

[RhetSim](https://github.com/hetworld/rhetsim) 的源码/构建域：拉取固定版本的组件源码，
构建交叉工具链、模拟器、固件、内核和 initramfs，运行相互隔离的实例，并为
`rhetsim-software-dev-platform` 打包 SDK。

> **当前状态：P0 已完成。** 实例生命周期、实例锁、Linux 启动、SDK 打包和软浮点
> 工具链重建均已验证；模拟器/固件/initramfs/内核的完整流水线仍在验证（P2）。
> 迁移期间可以用 `./run.sh build <instance> --reuse-existing` 链接现有的 `rhet/`
> 构建产物。

## 目录

```text
env/        声明式环境定义（版本、配置、补丁、实例）
scripts/    可执行编排（构建、实例、打包、测试）
repos/      拉取的组件源码（gitignored；worktree 母体）
workspace/  实例与构建产物（gitignored）
sdk/        SDK 契约、示例和消费端脚本
docs/       架构/构建/SDK/发布文档以及 docs/memory/ 知识库
.claude/    项目 skill 和共享 Claude 配置
```

构建输入只放在 `env/`；`scripts/` 把定义变成 `workspace/` 下的产物。`repos/` 和
`workspace/` 永远不提交。

## 快速开始

```bash
./run.sh check-host
./run.sh fetch
./run.sh create riscv-virt-2hart
./run.sh build riscv-virt-2hart
./run.sh start riscv-virt-2hart
```

迁移阶段复用现有构建产物：

```bash
./run.sh create riscv-virt-2hart
./run.sh build riscv-virt-2hart --reuse-existing /home/leo/leo/workspace/rhet
./run.sh start riscv-virt-2hart --batch
```

`--reuse-existing` 会原样使用旧目录树（包括内嵌 initramfs 的旧内核）；要验证
外部 initrd 布局请用 `./run.sh build`。

`./run.sh help` 列出所有命令；`make` 只是薄别名。默认实例是 `riscv-virt-2hart`。

## 实例模型

每个实例都是一个可丢弃、自包含的环境：

```text
workspace/instances/<name>/
├── bin/      模拟器、固件、内核、DTB、initramfs
├── logs/     每次运行的 UART/sim/trace 日志（logs/latest 指向最近一次）
├── src/      按需为要修改的组件创建的 git worktree
├── config/   从 env/instances/<name>/ 物化而来
└── run/      持久磁盘 overlay 和每次运行的状态
```

- 实例定义版本化在 `env/instances/<name>/`。
- 同一实例默认只允许一个 active run（`run/lock`）；不同实例可以并行。
- 昂贵的构建产物放在 `workspace/shared/`，内容寻址、只读；实例 `bin/` 默认链接过去。
  根文件系统按输入集最多构建一次，不会因为创建新实例而重建；用
  `./run.sh build <name> --rootfs prebuilt` 可以直接使用已提交的 `initramfs.cpio`，
  用 `--copy` 则物化成独立副本。
- 内核不再内嵌根文件系统。rootfs 作为独立 initrd 通过模拟器的 `--initrd` 加载，
  修改 rootfs 不会触发内核重编。

## 构建与运行

- `./run.sh build <name>`：构建或链接启动栈。
- `./run.sh start <name>`：交互式启动模拟器。
- `./run.sh start <name> --batch`：非交互运行，日志写入
  `workspace/instances/<name>/logs/<run-id>/uart.log`。
- `./run.sh test boot <name>`：启动 Linux 并检查 `RHETSIM_INIT_OK` 标记。

详见 [docs/build.md](docs/build.md)、[docs/architecture.md](docs/architecture.md)。

## SDK

`./run.sh sdk <name> --version <ver>` 生成 `workspace/dist/rhetsim-sdk-<ver>/`、
tarball 和校验和。SDK 包含模拟器二进制、固件、
内核、DTB、initramfs、sysroot/工具链、示例和消费端脚本。参见
[sdk/layout.md](sdk/layout.md) 和 [docs/sdk-spec.md](docs/sdk-spec.md)。

不要把大二进制提交进 git：通过 GitHub Releases、OCI 镜像或软件平台的下载脚本分发。

## Claude 资产

- 提交规范和工作边界：[CLAUDE.md](CLAUDE.md)。
- 项目 skill：`.claude/skills/`（`bootstrap`、`build`、`run-debug`、`release`、
  `memory-sync`）。
- 项目知识库：[docs/memory/MEMORY.md](docs/memory/MEMORY.md)。

本机 Claude memory 目录软链到 `docs/memory/`，因此记忆更新会随仓库版本化。

## 许可证

Apache-2.0。Copyright 2026 OpenFunTech。
