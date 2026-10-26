@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

rem ============================================================
rem  红米 4A (rolex) 触摸修复 —— 刷入修复版 boot.img
rem  适用于 lk2nd fastboot（与固件包 flash.bat 的流程一致）
rem
rem  boot_rolex_fts_fixed.img 与原厂 boot_rolex_fts.img 只差 1 字节：
rem      edt,edt-ft5336  ->  edt,edt-ft5306
rem
rem  用法：
rem    1) 把 boot_rolex_fts_fixed.img 放在本 bat 旁边（tools\ 目录），双击
rem    2) 或者直接把 img 文件拖到本 bat 上
rem ============================================================

set "IMG="
if not "%~1"=="" if exist "%~1" set "IMG=%~1"
if not defined IMG if exist "%~dp0boot_rolex_fts_fixed.img" set "IMG=%~dp0boot_rolex_fts_fixed.img"
if not defined IMG if exist "%~dp0..\boot\boot_rolex_fts_fixed.img" set "IMG=%~dp0..\boot\boot_rolex_fts_fixed.img"
if not defined IMG if exist "%~dp0..\boot_rolex_fts_fixed.img" set "IMG=%~dp0..\boot_rolex_fts_fixed.img"

set "FASTBOOT="
where fastboot >nul 2>nul
if not errorlevel 1 set "FASTBOOT=fastboot"
if not defined FASTBOOT if exist "%~dp0..\..\rolex\fastboot.exe" set "FASTBOOT=%~dp0..\..\rolex\fastboot.exe"
if not defined FASTBOOT if exist "%~dp0..\rolex\fastboot.exe" set "FASTBOOT=%~dp0..\rolex\fastboot.exe"
if not defined FASTBOOT if exist "D:\tools\platform-tools\fastboot.exe" set "FASTBOOT=D:\tools\platform-tools\fastboot.exe"

if not defined FASTBOOT (
    echo [错误] 找不到 fastboot.exe
    echo        请把 fastboot 加入 PATH，或把本脚本放到固件包的 rolex 目录旁边：
    echo            ^<固件包^>\rolex\fastboot.exe
    echo            ^<固件包^>\tools\flash_fixed_boot.bat
    pause
    exit /b 1
)

if not defined IMG (
    echo [错误] 找不到 boot_rolex_fts_fixed.img
    echo        请先到 Releases 下载：
    echo        https://github.com/wvivi5/redmi4a-rolex-touch-fix/releases/tag/v1.0.0
    echo        然后把 img 放到本 bat 旁边，或直接拖到本 bat 上。
    pause
    exit /b 1
)

echo ============================================================
echo   红米 4A (rolex) 触摸修复 - 刷入 boot.img
echo ============================================================
echo.
echo   镜像: %IMG%
echo.
"%FASTBOOT%" devices
echo.
echo   请确认手机已进入 fastboot：
echo     * 推荐：按固件包 flash.bat 的流程，刷完 lk2nd.img 后进入 lk2nd 的 fastboot
echo     * lk2nd 的 fastboot 里 flash boot 只写 boot.img 区段（0x80000），不会破坏 lk2nd
echo.
pause
"%FASTBOOT%" flash boot "%IMG%"
if errorlevel 1 (
    echo.
    echo [失败] 刷写未成功，请检查设备状态后重试。
    pause
    exit /b 1
)
"%FASTBOOT%" reboot
echo.
echo 完成。重启后可在手机终端里运行 tools\check_touch.sh 验证。
pause
