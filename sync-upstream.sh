#!/usr/bin/env bash
# sync-upstream.sh —— 从上游 linbeize/workbuddy2api-gui 拉新代码，合并进本仓 master。
#
# 合并策略：用 git merge（保留双方历史）。上游改动与本仓改动冲突时，
# 以「本仓为准」自动解决并把这些文件列出来，人工复核后再提交、推送。
#
# 用法：./sync-upstream.sh          普通合并，冲突时停下来等人处理
#       ./sync-upstream.sh -o       冲突时自动以本仓为准（ours）并推送
set -euo pipefail

STRATEGY_OURS=0
[[ "${1:-}" == "-o" ]] && STRATEGY_OURS=1

BRANCH=master
REMOTE_OURS=origin
REMOTE_UP=upstream

echo "==> 拉取上游最新代码"
git fetch "$REMOTE_UP"

# 上游如果没有新提交，直接退出，不动工作区。
if git merge-base --is-ancestor "$REMOTE_UP/$BRANCH" "$BRANCH"; then
  echo "已是最新，无需合并。"
  exit 0
fi

echo "==> 上游新增提交："
git log --oneline "$BRANCH..$REMOTE_UP/$BRANCH"

echo "==> 合并上游到 $BRANCH"
set +e
if [[ $STRATEGY_OURS -eq 1 ]]; then
  git merge --no-edit -X ours "$REMOTE_UP/$BRANCH"
else
  git merge --no-edit "$REMOTE_UP/$BRANCH"
fi
rc=$?
set -e

if [[ $rc -ne 0 ]]; then
  if [[ $STRATEGY_OURS -eq 1 ]]; then
    echo "==> 残留冲突，以本仓为准解决："
    git diff --name-only --diff-filter=U | tee /tmp/conflicted.txt
    git checkout --ours -- $(cat /tmp/conflicted.txt | tr '\n' ' ')
    git add $(cat /tmp/conflicted.txt | tr '\n' ' ')
    git commit --no-edit
  else
    echo "!! 存在冲突，已暂停。请手工解决以下文件后 git commit："
    git diff --name-only --diff-filter=U
    echo "提示：确定要放弃上游改动、保留本仓版本，可重跑本脚本并加 -o。"
    exit 1
  fi
fi

echo "==> 合并完成。本次合并涉及的改动："
git diff --stat HEAD~1 HEAD 2>/dev/null | tail -5 || true

echo "==> 重新构建前端（dist 会被 Go embed，必须同步）"
( cd web && npm run build )

echo "==> 推送到 $REMOTE_OURS/$BRANCH"
git add -A
git commit --no-edit --allow-empty -m "chore: 同步上游后重新构建 dist" 2>/dev/null || true
git push "$REMOTE_OURS" "$BRANCH"

echo "✓ 完成"
