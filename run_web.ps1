$ErrorActionPreference = 'Stop'

# Always run from script folder
Set-Location $PSScriptRoot

Write-Host 'Stopping stale Flutter/Dart processes...'
Get-Process flutter,dart -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host 'Cleaning problematic generated folders...'
if (Test-Path .\build\flutter_assets) {
  attrib -R .\build\flutter_assets /S /D | Out-Null
  Remove-Item .\build\flutter_assets -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path .\.dart_tool) {
  attrib -R .\.dart_tool /S /D | Out-Null
}

Write-Host 'Fetching dependencies...'
flutter pub get

Write-Host 'Launching app on Edge with fixed web port 7357...'
flutter run -d edge --web-hostname 127.0.0.1 --web-port 7357