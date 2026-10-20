#!/bin/bash
# 每日自动更新本机 omp:
#   1. 确保 mihomo 代理在运行 (git pull GitHub 需要)
#   2. git pull --ff-only origin main (CI 已把上游合并进 origin/main)
#   3. 按需 bun install / build:native
#
# 用 crontab 定时, 例如在 CI 同步(每天 02:17)之后:
#   30 4 * * * /work4/User/wangzhiyuan/software/bio_development/2-omp/oh-my-pi/update-local.sh >> /tmp/opencode/omp-update.log 2>&1

set -uo pipefail

REPO=/work4/User/wangzhiyuan/software/bio_development/2-omp/oh-my-pi
LOCK=/tmp/opencode/omp-update.lock
MIHOMO=/work4/User/wangzhiyuan/software/bio_tools/mihomo

# cron 环境 PATH 极简, 显式补齐 (conda tools / bun / cargo / sbin)
export PATH="/data1/work1/Conda/miniforge_wzy/envs/tools/bin:$HOME/.bun/bin:$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# glibc 2.17 头文件修复 (tree-sitter be16toh)
export CFLAGS="-D_BSD_SOURCE" CXXFLAGS="-D_BSD_SOURCE"

mkdir -p /tmp/opencode
log() { echo "[$(date '+%F %T')] $*"; }

# 防并发
exec 9>"$LOCK"
flock -n 9 || { log "另一个更新正在进行, 退出"; exit 0; }

cd "$REPO"

# 1. 代理 (仅 git 需要; cargo 已走 rsproxy 镜像, bun install 走 npm 官方源直连/代理均可)
if ! ss -tln | grep -q ':7890 '; then
	log "启动 mihomo..."
	nohup "$MIHOMO" -d "$HOME/.config/clash" >> /tmp/opencode/mihomo.log 2>&1 &
	sleep 3
	ss -tln | grep -q ':7890 ' || { log "mihomo 启动失败, 退出"; exit 1; }
fi
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890

# 2. pull
OLD=$(git rev-parse HEAD)
if ! git pull --ff-only origin main; then
	log "git pull --ff-only 失败 (本地可能有未推送提交或改动), 跳过本次更新"
	exit 1
fi
NEW=$(git rev-parse HEAD)
if [ "$OLD" = "$NEW" ]; then
	log "已是最新 ($(git rev-parse --short HEAD)), 无需构建"
	exit 0
fi
log "更新 $(git rev-parse --short "$OLD") -> $(git rev-parse --short "$NEW")"

# 3. 按需重建
if ! git diff --quiet "$OLD" "$NEW" -- bun.lock package.json; then
	log "JS 依赖变更, bun install..."
	bun install
fi

if ! git diff --quiet "$OLD" "$NEW" -- crates/ packages/natives/ Cargo.lock rust-toolchain.toml; then
	log "Rust 代码变更, 重新构建原生模块 (112 核增量编译约 3~5 分钟)..."
	bun run build:native
	log "构建完成: $(bun packages/coding-agent/src/cli.ts --version 2>&1)"
else
	log "无 Rust 变更, 跳过原生构建"
fi

log "更新完成: $(bun packages/coding-agent/src/cli.ts --version 2>&1)"
