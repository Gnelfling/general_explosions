# Build General Explosions' Source SM3.0 shaders on Windows.
# This does not install or download anything; supply your own ShaderCompile.exe.
param(
    [string]$Compiler = "$env:USERPROFILE\Downloads\ShaderCompile\ShaderCompile.exe"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "shaders\src"
$built = Join-Path $src "shaders\fxc"
$dest = Join-Path $root "shaders\fxc"

if (-not (Test-Path -LiteralPath $Compiler -PathType Leaf)) {
    throw "Shader compiler missing: $Compiler"
}
foreach ($shader in @("ge_volume_ps30", "ge_volume_vs30")) {
    $inputFile = Join-Path $src "$shader.fxc"
    if (-not (Test-Path -LiteralPath $inputFile -PathType Leaf)) {
        throw "Shader source missing: $inputFile"
    }
    Write-Host "[GE] Building $shader..."
    & $Compiler -ver 30 -shaderpath $src -force $inputFile
    if ($LASTEXITCODE -ne 0) {
        throw "ShaderCompile failed for $shader (exit code $LASTEXITCODE)"
    }
    $outFile = Join-Path $built "$shader.vcs"
    if (-not (Test-Path -LiteralPath $outFile -PathType Leaf)) {
        throw "No .vcs output for $shader. Inspect compiler logs."
    }
}
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -LiteralPath (Join-Path $built "ge_volume_ps30.vcs") -Destination $dest -Force
Copy-Item -LiteralPath (Join-Path $built "ge_volume_vs30.vcs") -Destination $dest -Force
Write-Host "[GE] Compiled .vcs files are in $dest"
Write-Host "[GE] Restart Garry's Mod after replacing compiled shaders."
