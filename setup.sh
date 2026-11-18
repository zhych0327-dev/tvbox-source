#!/usr/bin/env bash
# 一键把当前目录初始化为可 push 的 git 仓库，并配置提交模板、CI 自动提交身份。
# 用法：bash setup.sh  （在 tvbox-source/ 目录下执行）

set -euo pipefail

echo "==> 初始化 git 仓库"
git init -q

echo "==> 配置提交信息模板"
git config commit.template .gitmessage.txt

echo "==> 关闭自动换行转换（跨平台一致）"
git config core.autocrlf false

echo "==> 设置本地提交身份（仅本仓库生效，不覆盖全局）"
read -r -p "输入你的 Git 用户名 [默认: tvbox-bot]: " gname
gname=${gname:-tvbox-bot}
read -r -p "输入你的 Git 邮箱 [默认: tvbox-bot@users.noreply.github.com]: " gemail
gemail=${gemail:-tvbox-bot@users.noreply.github.com}
git config user.name "$gname"
git config user.email "$gemail"

echo "==> 暂存文件并生成首次提交"
git add .
git commit -q -m "chore: init tvbox source repo [skip ci]"

echo ""
echo "✓ 初始化完成。接下来关联远程并推送："
echo ""
echo "  git remote add origin https://github.com/<你的用户名>/<仓库名>.git"
echo "  git branch -M main"
echo "  git push -u origin main"
echo ""
echo "推送后到仓库 Settings → Actions → General → Workflow permissions"
echo "勾选 Read and write permissions，自动更新才能提交。"
