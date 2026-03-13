$env:VCPKG_ROOT = 'C:\vcpkg'

# Import MSVC environment from vcvarsall.bat
$vcvars = 'C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat'
Write-Host "Loading MSVC environment..."
$envVars = cmd /c "`"$vcvars`" x64 && set" 2>&1
foreach ($line in $envVars) {
    if ($line -match '^([^=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
    }
}

Write-Host "cl.exe: $((Get-Command cl.exe -ErrorAction SilentlyContinue).Source)"

Set-Location c:\otclient
Write-Host "Building (windows-release preset)..."
cmake --build build/windows-release --preset windows-release
$buildExit = $LASTEXITCODE
Write-Host "CMake build exit code: $buildExit"
exit $buildExit
