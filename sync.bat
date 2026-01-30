@echo off
title Git双仓库强制覆盖脚本
color 0A

echo ========================================
echo        Git双仓库强制覆盖脚本
echo ========================================

:: 配置Git
git config --global user.name "CrYinLang"
git config --global user.email "11822174+CrYinLang@user.noreply.gitee.com"
git config --global http.sslVerify false

echo [1/10] 检查远程仓库配置...
git remote get-url gitee >nul 2>&1 || git remote add gitee https://gitee.com/CrYinLang/emu-aio.git
git remote get-url github >nul 2>&1 || git remote add github https://github.com/CrYinLang/EmuAIO.git

echo [2/10] 显示远程仓库状态...
echo Gitee远程仓库: 
git remote get-url gitee
echo GitHub远程仓库: 
git remote get-url github

echo [3/10] 获取当前时间...
for /f "tokens=1-3 delims=/" %%a in ('date /t') do (
    set year=%%c
    set month=%%b
    set day=%%a
)
for /f "tokens=1-2 delims=:" %%a in ('time /t') do (
    set hour=%%a
    set minute=%%b
)
set current_date=%year%-%month%-%day%
set current_time=%hour%:%minute%
set commit_msg=强制双仓库覆盖 [%current_date% %current_time%]

echo [4/10] 强制添加所有文件...
git add --all .

echo [5/10] 创建强制提交...
git commit -m "%commit_msg%" --allow-empty

echo [6/10] 强制推送到Gitee...
echo 正在推送到Gitee...
git push gitee master --force
if errorlevel 1 (
    echo Gitee推送失败
    set gitee_success=0
) else (
    echo Gitee推送成功
    set gitee_success=1
)

echo [7/10] 强制推送到GitHub...
echo 正在推送到GitHub...
git push github master --force
if errorlevel 1 (
    echo GitHub推送失败
    set github_success=0
) else (
    echo GitHub推送成功
    set github_success=1
)

echo [8/10] 验证推送结果...
echo 最新提交哈希: 
git rev-parse --short HEAD

echo [9/10] 生成状态报告...
echo.
echo ========================================
echo          推送状态报告
echo ========================================
echo 提交时间: %current_date% %current_time%

if %gitee_success%==1 (
    echo Gitee仓库: 推送成功
    echo 仓库地址: https://gitee.com/CrYinLang/emu-aio
) else (
    echo Gitee仓库: 推送失败
)

if %github_success%==1 (
    echo GitHub仓库: 推送成功
    echo 仓库地址: https://github.com/CrYinLang/EmuAIO
) else (
    echo GitHub仓库: 推送失败
)

echo [10/10] 手动验证说明...
echo.
echo 请手动访问以下链接验证文件是否显示:
echo Gitee: https://gitee.com/CrYinLang/emu-aio
echo GitHub: https://github.com/CrYinLang/EmuAIO
echo.
echo 如果Gitee仍然显示空白，请检查:
echo 1. 仓库是否为公开状态
echo 2. 清除浏览器缓存重新访问
echo 3. 等待Gitee页面缓存更新
echo ========================================
pause