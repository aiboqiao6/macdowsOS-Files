param(
    [string]$Qt = 'C:\Qt\6.11.1\msvc2022_64',
    [string]$VisualStudio = 'C:\Program Files\Microsoft Visual Studio\2022\Community',
    [string]$QtMsBuild = "$env:LOCALAPPDATA\QtMsBuild"
)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$output = Join-Path $workspace 'x64\Review'
$objects = Join-Path $workspace 'macdowsOS Files\x64\Release'
$testOutput = Join-Path $output 'tests'
New-Item -ItemType Directory -Force -Path $testOutput | Out-Null
& "$VisualStudio\MSBuild\Current\Bin\MSBuild.exe" "$workspace\macdowsOS Files.sln" /p:Configuration=Release /p:Platform=x64 "/p:QtMsBuild=$QtMsBuild" "/p:OutDir=$output\" /m /v:minimal /nologo
if ($LASTEXITCODE) { throw 'Application build failed' }
$arguments = @('/nologo', '/MD', '/EHsc', '/std:c++17', '/Zc:__cplusplus', '/permissive-', '/utf-8', '/DNOMINMAX', '/DUNICODE', '/D_UNICODE', '/DQT_GUI_LIB', '/DQT_WIDGETS_LIB', "/I`"$workspace\macdowsOS Files`"", "/I`"$Qt\include`"")
foreach ($module in @('QtCore', 'QtGui', 'QtWidgets', 'QtQml', 'QtQuick', 'QtTest')) {
    $arguments += "/I`"$Qt\include\$module`""
}
$arguments += @("`"$PSScriptRoot\smoke.cpp`"", "/Fo`"$testOutput\smoke.obj`"", "/Fe`"$testOutput\smoke.exe`"")
foreach ($object in @('FileLocations', 'FileFilterModel', 'FileIconProvider', 'NativeShell', 'WindowManager', 'WindowsIntegration', 'moc_FileLocations', 'moc_FileFilterModel', 'moc_NativeShell', 'moc_WindowManager', 'moc_WindowsIntegration', 'qrc_qml')) {
    $arguments += "`"$objects\$object.obj`""
}
$arguments += @('/link', "/LIBPATH:`"$Qt\lib`"", 'Qt6Core.lib', 'Qt6Gui.lib', 'Qt6Widgets.lib', 'Qt6Quick.lib', 'Qt6Qml.lib', 'Qt6Test.lib', 'dwmapi.lib', 'ole32.lib', 'shell32.lib', 'uuid.lib', 'user32.lib', 'advapi32.lib', 'gdi32.lib', '/LTCG')
$response = Join-Path $testOutput 'compile.rsp'
Set-Content -LiteralPath $response -Value ($arguments -join ' ') -Encoding UTF8
$batch = Join-Path $testOutput 'compile.cmd'
Set-Content -LiteralPath $batch -Encoding ASCII -Value @("@call `"$VisualStudio\VC\Auxiliary\Build\vcvars64.bat`"", "@cl @`"$response`"", '@exit /b %errorlevel%')
& $env:ComSpec /c $batch
if ($LASTEXITCODE) { throw 'Smoke test compilation failed' }
$previousPath = $env:PATH
try {
    $env:PATH = "$Qt\bin;$previousPath"
    $env:MACDOWS_TEST_SCREENSHOT = Join-Path $testOutput 'window.png'
    & "$testOutput\smoke.exe"
    if ($LASTEXITCODE) { throw "Smoke tests failed: $LASTEXITCODE" }
} finally {
    $env:PATH = $previousPath
    Remove-Item Env:MACDOWS_TEST_SCREENSHOT -ErrorAction SilentlyContinue
}

