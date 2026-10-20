#!/bin/bash
# 在本机（CentOS 7 / glibc 2.17）上构建 omp 的一键脚本。
# 用法: ./build-local.sh
#
# 环境前提（已为本机配置好，换机器需重新准备）:
#   - Bun:        ~/.bun/bin/bun
#   - Rust:       nightly-2026-10-06 (rustup, 见 rust-toolchain.toml)
#                 工具链实体在 /work4/User/wangzhiyuan/software/runtime/rust/
#                 (~/.rustup 与 ~/.cargo 是指向它的软链接)
#   - crates 镜像: ~/.cargo/config.toml 已配 rsproxy.cn (直连可用)
#   - ninja:      pip 安装 (opusic-sys 的 cmake 需要)
#   - 代理:       mihomo @ 127.0.0.1:7890 (仅 git fetch/pull GitHub 需要)

set -euo pipefail
cd "$(dirname "$0")"

export PATH="$HOME/.bun/bin:$PATH"

# CentOS 7 的 glibc 2.17 头文件不认识 _DEFAULT_SOURCE (glibc 2.19+ 才引入),
# 导致 tree-sitter 编译时报 be16toh 未声明。_BSD_SOURCE 是 2.17 时代的对应宏。
export CFLAGS="-D_BSD_SOURCE"
export CXXFLAGS="-D_BSD_SOURCE"

echo "==> bun install"
bun install

echo "==> build native (Rust -> pi_natives.linux-x64-modern.node)"
bun run build:native

echo "==> 验证"
bun packages/coding-agent/src/cli.ts --version
echo "构建完成。开发运行: bun dev | 全局入口: ~/.bun/bin/omp"
