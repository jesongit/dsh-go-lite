# Windows entry for the same arm64/x64, signing and build-minute versionCode contract.
# Example: tooling/build-apk.ps1 --build-name 1.2.3 -f arm64
$ErrorActionPreference = 'Stop'
& python (Join-Path $PSScriptRoot 'build_apk.py') @args
exit $LASTEXITCODE
