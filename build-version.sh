#!/usr/bin/env bash
# build-version.sh —— 从 git tag 推导版本号，写入 .env 供 docker-compose.yml 使用。
#
# 规则：git describe --tags 的输出即为版本号。
#   · 在 tag 上（1.2.1 或 v1.2.1）       -> 1.2.1
#   · tag 之后有新提交（1.2.1-3-gabc）   -> 1.2.1+3.gabc（标记"未发布"的构建）
#   · 没有任何 tag                       -> dev
# 去掉开头的可选 v 前缀，与镜像标签约定一致（tag 与镜像标签同名，如 1.2.1）。
#
# 用法：./build-version.sh          写入 .env
#       ./build-version.sh -p       只打印不写文件（CI 里取值用）
set -euo pipefail

PRINT_ONLY=0
[[ "${1:-}" == "-p" ]] && PRINT_ONLY=1

DESCRIBE=$(git describe --tags 2>/dev/null || true)
if [[ -z "$DESCRIBE" ]]; then
  VERSION="dev"
else
  # 1.2.1 -> 1.2.1 ；v1.2.1 -> 1.2.1 ；1.2.1-3-gabc1234 -> 1.2.1+3.gabc1234
  # 去掉可选的 v 前缀；首个 - 换成 +（版本号附加段），第二个 - 换成 .（hash 分隔）。
  VERSION=$(echo "${DESCRIBE#v}" | sed 's/-/+/; s/-/./')
fi

if [[ "$PRINT_ONLY" == 1 ]]; then
  echo "$VERSION"
  exit 0
fi

# 覆盖写 .env 里的 VERSION 行（compose 会自动读同目录下的 .env）。
ENV_FILE="$(dirname "$0")/.env"
TMP="$(mktemp)"
if [[ -f "$ENV_FILE" ]]; then
  grep -v '^VERSION=' "$ENV_FILE" > "$TMP" || true
fi
echo "VERSION=$VERSION" >> "$TMP"
mv "$TMP" "$ENV_FILE"

echo "==> VERSION=$VERSION（已写入 $ENV_FILE）"
