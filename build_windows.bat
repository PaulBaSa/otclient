@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat" x64 >> c:\otclient\build.log 2>&1
if errorlevel 1 (
    echo ERROR: vcvarsall failed >> c:\otclient\build.log
    exit /b 1
)
echo VCVARS_OK >> c:\otclient\build.log
set VCPKG_ROOT=C:\vcpkg
cd /d c:\otclient
cmake --preset windows-release >> c:\otclient\build.log 2>&1
echo CMAKE_CONFIGURE_EXIT=%errorlevel% >> c:\otclient\build.log
