@echo off
title Git统一main分支同步脚本
color 0A

echo ========================================
echo        Git统一main分支同步脚本
echo ========================================

:: 配置Git
git config --global user.name "CrYinLang"
git config --global user.email "11822174+CrYinLang@user.noreply.gitee.com"
git config --global http.sslVerify false

echo [1/8] 切换到main分支...
git checkout -b main 2>nul
if errorlevel 1 (
    git checkout main
)
echo 当前分支: main
echo.

echo [2/8] 删除本地master分支（如果存在）...
git branch -D master 2>nul
echo.

echo [3/8] 配置远程仓库...
git remote get-url gitee >nul 2>&1 || git remote add gitee https://gitee.com/CrYinLang/emu-aio.git
git remote get-url github >nul 2>&1 || git remote add github https://github.com/CrYinLang/EmuAIO.git

echo [4/8] 设置Gitee默认分支为main...
git push gitee main --force
echo.

echo [5/8] 强制添加并提交所有文件...
git add --all .
set "commit_time=%date% %time%"
git commit -m "统一main分支同步 [%commit_time%]" --allow-empty

echo [6/8] 推送到两个仓库的main分支...
echo 推送到Gitee main分支...
git push gitee main --force
echo 推送到GitHub main分支...
git push github main --force

echo [7/8] 设置上游分支...
git branch --set-upstream-to=gitee/main main 2>nul
git branch --set-upstream-to=github/main main 2>nul

echo [8/8] 最终验证...
echo 分支状态:
git branch -a
echo.
echo ========================================
echo          同步完成
echo ========================================
echo 已统一使用main分支
echo Gitee: https://gitee.com/CrYinLang/emu-aio
echo GitHub: https://github.com/CrYinLang/EmuAIO
echo ========================================
pause