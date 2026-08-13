@echo off
chcp 65001 >nul
title zero_K-Genie - 安装程序生成工具
color 0A

echo =====================================
echo    zero_K-Genie - 安装程序生成工具
echo =====================================
echo.

cd /d "%~dp0"
cd ..

echo [1/3] 构建 Flutter Release 版本...
echo 这可能需要几分钟，请耐心等待...
echo.

call flutter clean >nul 2>&1
call flutter pub get >nul 2>&1
call flutter build windows --release

if %errorlevel% neq 0 (
    echo.
    echo [错误] Flutter 构建失败！
    pause
    exit /b 1
)

echo.
echo [2/3] 生成安装程序...
echo.

set "ISCC=D:\software\Inno Setup 6\ISCC.exe"

if not exist "%ISCC%" (
    echo [错误] 找不到 Inno Setup！
    echo 路径: %ISCC%
    pause
    exit /b 1
)

if not exist "installer_output" mkdir installer_output

"%ISCC%" installer\installer.iss

if %errorlevel% neq 0 (
    echo.
    echo [错误] 安装程序生成失败！
    pause
    exit /b 1
)

echo.
echo [3/3] 完成!
echo.
echo =====================================
echo [成功] 安装程序已生成！
echo =====================================
echo.
echo 安装程序位置:
echo installer_output\zero_K-Genie_Setup_1.0.0.exe
echo.
echo 将此文件发给用户，双击即可安装！
echo.

start explorer.exe installer_output

pause