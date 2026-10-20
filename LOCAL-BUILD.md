# 本机构建说明（CentOS 7 / glibc 2.17）

本仓库 = 上游 [can1357/oh-my-pi](https://github.com/can1357/oh-my-pi) + 适配本机的构建流程。

## 全自动更新（已配置）

1. GitHub Actions `sync-upstream.yml`：每天 02:17（北京时间）合并上游 → 推送到本仓库
2. 本机 crontab：每天 04:30 跑 `update-local.sh`（pull + 按需重建，日志 `/tmp/opencode/omp-update.log`）
3. GitHub Actions `build-centos7.yml`：同步后自动在 centos:7 容器构建，产物传 Release `centos7-latest`

## 手动同步上游 + 重建

```bash
# GitHub 直连慢，git 操作走 mihomo 代理（如未启动先启动:
# nohup /work4/User/wangzhiyuan/software/bio_tools/mihomo -d ~/.config/clash > /tmp/opencode/mihomo.log 2>&1 &）
https_proxy=http://127.0.0.1:7890 git pull origin main
./build-local.sh
git push origin main   # 保存自己的修改
```

## 构建产物

| 产物 | 位置 |
|------|------|
| 原生模块（核心） | `packages/natives/native/pi_natives.linux-x64-modern.node` (~142M) |
| CLI 全局入口 | `~/.bun/bin/omp`（软链接 → `packages/coding-agent/scripts/omp`） |
| Rust 中间产物 | `target/`（~6.6G，勿删，删了增量编译失效） |

TS 代码由 Bun 直接解释执行，无需编译；每次上游更新后只需 `bun install` + `bun run build:native`（见 `build-local.sh`）。

## 本机环境要点（换机器重建时参考）

1. **glibc 2.17 老头文件**：不认识 `_DEFAULT_SOURCE`，tree-sitter 编译报 `be16toh` 未声明 → 必须 `CFLAGS="-D_BSD_SOURCE"`（脚本已内置）。
2. **rustup 直连可用**：`static.rust-lang.org` 直连通；走 mihomo 代理反而 TLS 失败。
3. **crates.io 走镜像**：`~/.cargo/config.toml` 配置了 rsproxy.cn（直连快）；直连 crates.io 会卡死数小时。
4. **ninja**：`opusic-sys` 用 cmake+Ninja 构建，`pip install ninja`（清华镜像）。
5. **Rust 工具链**实体在 `/work4/User/wangzhiyuan/software/runtime/rust/`（home 通过软链接引用，home 分区很小）。
6. **AVX2 必需**：Bun 官方 linux-x64 构建需要 AVX2；老 CPU 需换 `bun-linux-x64-baseline`。

## 部署到其他同构主机（glibc 2.17 + AVX2，如 172.30.1.100）

无需重新编译，rsync 整个仓库（排除 target/）+ Bun 二进制即可：

```bash
sshpass -e rsync -az --delete --exclude=target -e ssh \
  /work4/User/wangzhiyuan/software/bio_development/2-omp/oh-my-pi/ \
  wangzhiyuan@172.30.1.100:/work3/User/wangzhiyaun/sw/bio_development/oh-my-pi/
# 远程还需: ~/.bun/bin/bun 二进制 + ~/.bun/bin/omp 软链接 + PATH
```
