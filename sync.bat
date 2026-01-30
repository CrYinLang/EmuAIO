@echo off
title Git双仓库双分支同步脚本
color 0A

echo ========================================
echo        Git双仓库双分支同步脚本
echo ========================================

:: 配置Git
git config --global user.name "CrYinLang"
git config --global user.email "11822174+CrYinLang@user.noreply.gitee.com"
git config --global http.sslVerify false

echo [1/10] 检查当前分支...
git branch --show-current
echo.

echo [2/10] 检查远程仓库配置...
git remote get-url gitee >nul 2>&1 || git remote add gitee https://gitee.com/CrYinLang/emu-aio.git
git remote get-url github >nul 2>&1 || git remote add github https://github.com/CrYinLang/EmuAIO.git

echo [3/10] 检查远程分支状态...
echo Gitee远程分支:
git ls-remote --heads gitee
echo GitHub远程分支:
git ls-remote --heads github
echo.

echo [4/10] 切换到main分支（如果存在）...
git checkout main 2>nul
if errorlevel 1 (
    echo main分支不存在，使用当前分支
    git checkout -b main 2>nul
    if errorlevel 1 (
        echo 创建main分支失败，使用master分支
        set current_branch=master
    ) else (
        set current_branch=main
    )
) else (
    set current_branch=main
)

echo 当前分支: %current_branch%
echo.

echo [5/10] 强制添加所有文件...
git add --all .

echo [6/10] 创建提交...
for /f "tokens=1-3 delims=/" %%a in ('date /t') do (
    set year=%%c
    set month=%%b
    set day=%%a
)
for /f "tokens=1-2 delims=:" %%a in ('time /t') do (
    set hour=%%a
    set minute=%%b
)
set commit_msg=双分支同步提交 [%year%-%month%-%day% %hour%:%minute%]

git commit -m "%commit_msg%" --allow-empty

echo [7/10] 推送到Gitee（master分支）...
echo 推送到Gitee master分支...
git push gitee %current_branch%:master --force
if errorlevel 1 (
    echo Gitee推送失败
    set gitee_success=0
) else (
    echo Gitee推送成功
    set gitee_success=1
)

echo [8/10] 推送到GitHub（main分支）...
echo 推送到GitHub main分支...
git push github %current_branch%:main --force
if errorlevel 1 (
    echo GitHub推送失败
    set github_success=0
) else (
    echo GitHub推送成功
    set github_success=1
)

echo [9/10] 验证推送结果...
echo 本地提交信息:
git log --oneline -1
echo 本地分支: %current_branch%
echo.

echo [10/10] 生成状态报告...
echo ========================================
echo          同步状态报告
echo ========================================
echo 本地分支: %current_branch%
echo 提交时间: %year%-%month%-%day% %hour%:%minute%

if %gitee_success%==1 (
    echo Gitee状态: 推送成功 (master分支)
    echo 仓库地址: https://gitee.com/CrYinLang/emu-aio
) else (
    echo Gitee状态: 推送失败
)

if %github_success%==1 (
    echo GitHub状态: 推送成功 (main分支)
    echo 仓库地址: https://github.com/CrYinLang/EmuAIO
) else (
    echo GitHub状态: 推送失败
)

echo.
echo 分支映射说明:
echo - 本地分支: %current_branch%
echo - Gitee远程: master分支
echo - GitHub远程: main分支
echo ========================================
pause