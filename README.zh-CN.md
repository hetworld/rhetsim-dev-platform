# RhetSim 开发平台

[RhetSim](https://github.com/hetworld/rhetsim) 的源码/构建域：拉取固定版本的组件源码，
构建交叉工具链、模拟器、固件、内核和 initramfs，运行相互隔离的实例，并为
`rhetsim-software-dev-platform` 打包 SDK。

> **当前状态：P1 已完成 / P2 进行中。** 默认构建（模拟器 + OpenSBI + Linux +
> 预构建 rootfs）、实例生命周期、实例锁、SDK 打包和外部 initrd 启动均已验证；
> 工具链和 rootfs 重建是 `tools/` 下的可选维护工具。迁移期间仍可以用
> `./run.sh build <instance> --reuse-existing` 链接现有的 `rhet/` 构建产物。
>
> **当前重点：模拟器开发和验证。** SDK/发布（P3/P4）只做规划，不是当前工作流。

## 目录

```text
env/        声明式环境定义（版本、配置、补丁、实例）
scripts/    可执行编排（构建、实例、打包、测试）
tools/      可选维护工具（工具链、initramfs 重建）
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
./run.sh verify-lock
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
- 昂贵的构建产物放在 `workspace/shared/`，内容寻址、只读；实例 `bin/` 默认链接过去，
  `--copy` 则物化成独立副本。根文件系统是来自 `rhetsim-initramfs` 的**预构建资源**，
  平台不再构建它；OpenSBI 和 Linux 仍在本地构建，方便调试时模拟器与软件同步。
- 内核不再内嵌根文件系统。rootfs 作为独立 initrd 通过模拟器的 `--initrd` 加载，
  修改 rootfs 不会触发内核重编。

## 构建与运行

- `./run.sh build <name>`：构建 `rhetsim-cli`、OpenSBI 和 Linux，再组装预构建 rootfs；
  模拟器源码优先使用实例 worktree `workspace/instances/<name>/src/rhetsim`。
- `./run.sh start <name>`：交互式启动模拟器。
- `./run.sh start <name> --batch`：非交互运行，日志写入
  `workspace/instances/<name>/logs/<run-id>/uart.log`。
- `./run.sh test boot <name>`：启动 Linux 并检查 `RHETSIM_INIT_OK` 标记；`--` 后可传
  模拟器参数，例如 `./run.sh test boot <name> -- --no-jit`。
- `./run.sh test sim`：在实例 `src/rhetsim` worktree 里跑
  `cargo test --workspace`。
- `./run.sh bench --runs 3`：测量 Linux 启动耗时并打印 JIT 统计；`--no-jit`
  可跑解释器基线。
- 实例级组件补丁放在 `env/instances/<name>/patches/<component>/`；构建时在临时
  worktree 中应用，并计入组件 build ID。

详见 [docs/build.md](docs/build.md)、[docs/architecture.md](docs/architecture.md)。

## SDK

`./run.sh sdk <name> --version <ver>` 生成 `workspace/dist/rhetsim-sdk-<ver>/`、
tarball 和校验和。SDK 包含模拟器二进制、固件、内核、DTB、initramfs、可选 sysroot、
示例和消费端脚本。需要 sysroot 时用可选维护工具
`tools/toolchain/build-toolchain.sh` 构建。参见 [sdk/layout.md](sdk/layout.md) 和
[docs/sdk-spec.md](docs/sdk-spec.md)。

> SDK/发布后续再规划；当前重点是模拟器开发和验证。

不要把大二进制提交进 git：通过 GitHub Releases、OCI 镜像或软件平台的下载脚本分发。

## Claude 资产

- 提交规范和工作边界：[CLAUDE.md](CLAUDE.md)。
- 项目 skill：`.claude/skills/`（`bootstrap`、`build`、`run-debug`、`release`、
  `memory-sync`）。
- 项目知识库：[docs/memory/MEMORY.md](docs/memory/MEMORY.md)。

本机 Claude memory 目录软链到 `docs/memory/`，因此记忆更新会随仓库版本化。

## 许可证

Apache-2.0。Copyright 2026 OpenFunTech。
