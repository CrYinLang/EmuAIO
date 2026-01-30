@echo off
title Git先删除后重新上传脚本
color 0A

echo ========================================
echo        Git先删除后重新上传脚本
echo ========================================

:: 配置Git
git config --global user.name "CrYinLang"
git config --global user.email "11822174+CrYinLang@user.noreply.gitee.com"
git config --global http.sslVerify false

echo [1/10] 检查远程仓库配置...
git remote get-url gitee >nul 2>&1 || git remote add gitee https://gitee.com/CrYinLang/emu-aio.git
git remote get-url github >nul 2>&1 || git remote add github https://github.com/CrYinLang/EmuAIO.git

echo [2/10] 创建孤儿分支（全新历史）...
git checkout --orphan temp_force_branch

echo [3/10] 添加所有文件到新分支...
git add --all .

echo [4/10] 提交所有文件...
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set date=%%c-%%b-%%a
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set time=%%a:%%b
set commit_msg=全新历史覆盖 [%date% %time%]

git commit -m "%commit_msg%"

echo [5/10] 删除原master分支...
git branch -D master

echo [6/10] 重命名新分支为master...
git branch -m master

echo [7/10] 强制推送到Gitee（完全覆盖）...
git push gitee master --force

echo [8/10] 强制推送到GitHub（完全覆盖）...
git push github master --force

echo [9/10] 清理和优化...
git gc --aggressive --prune=now

echo [10/10] 最终验证...
echo 文件列表：
dir /b | findstr /v "\.git"
echo 提交信息：
git log --oneline -1

echo.
echo ========================================
echo          彻底覆盖完成！
echo ========================================
echo 已创建全新的Git历史记录
echo 远程仓库所有文件已被删除并重新上传
echo ========================================
pause