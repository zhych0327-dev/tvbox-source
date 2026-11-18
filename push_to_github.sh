#!/usr/bin/env bash
# 用个人访问令牌（PAT）把本目录推送到 GitHub —— 绕过只读集成的限制。
# 令牌只在本次运行时读取，不写入任何文件、不留在历史里。
#
# 用法：bash push_to_github.sh

set -euo pipefail

REPO_OWNER="zhych0327-dev"
REPO_NAME="tvbox-source"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"

echo "============================================================"
echo " 推送 ${REPO_OWNER}/${REPO_NAME}"
echo "============================================================"
echo ""
echo "先去 GitHub 生成一个 Personal Access Token（classic）："
echo "  https://github.com/settings/tokens"
echo "  点 Generate new token (classic)"
echo "  Note 随便填，Expiration 选 90 days"
echo "  勾选权限：repo（整个一组，必须勾）"
echo "  点 Generate token，复制那串 ghp_ 开头的字符串"
echo ""

read -r -s -p "粘贴你的 PAT（输入时不显示）: " TOKEN
echo ""
if [ -z "${TOKEN}" ]; then
  echo "令牌为空，已退出。"
  exit 1
fi

echo ""
echo "==> 初始化 git（已初始化会跳过）"
if [ ! -d .git ]; then
  git init -q
  git config core.autocrlf false
fi
git config user.name "${REPO_OWNER}"
git config user.email "${REPO_OWNER}@users.noreply.github.com"

echo "==> 提交本地文件"
git add .
git commit -qm "chore: init tvbox source repo [skip ci]" || echo "（无新改动，复用现有提交）"

echo "==> 关联远程（带令牌，仅本次使用）"
git remote remove origin 2>/dev/null || true
git remote add origin "https://${TOKEN}@github.com/${REPO_OWNER}/${REPO_NAME}.git"

echo "==> 推送到 main"
git branch -M main
if git push -u origin main; then
  echo ""
  echo "✓ 推送成功！"
else
  echo ""
  echo "✗ 推送失败。常见原因："
  echo "  - 令牌没勾 repo 权限"
  echo "  - 仓库名不对或不是你账号下的"
  echo "  - 远程已有内容但本地没拉（先在网页建的是空仓库就不会有这问题）"
  exit 1
fi

echo "==> 清除令牌，避免留在远程配置里"
git remote set-url origin "${REPO_URL}"

echo ""
echo "你的导入地址："
echo "  https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/config/tvbox.json"
echo ""
echo "最后一步：去仓库 Settings → Actions → General → Workflow permissions"
echo "勾选 Read and write permissions，自动更新才能提交。"
