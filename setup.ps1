# One-time setup on Windows: creates the native platform folders,
# configures permissions, and downloads packages. Safe to run again.
#   Right-click > Run with PowerShell, or:  powershell -ExecutionPolicy Bypass -File setup.ps1
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "Flutter is not installed. Get it from https://docs.flutter.dev/get-started/install, then run this again."
  exit 1
}

Write-Host "1/3  Creating platform folders (android, ios, web, windows, macos, linux)..."
flutter create . --project-name aquaaware --org org.aquaaware --platforms android,ios,web,windows,macos,linux | Out-Null

Write-Host "2/3  Configuring permissions and security settings..."
dart run tool/configure_platforms.dart

Write-Host "3/3  Downloading packages..."
flutter pub get

if (-not (Get-Command nuget -ErrorAction SilentlyContinue)) {
  Write-Host ""
  Write-Host "Note: the Windows desktop build needs NuGet for read-aloud. Install it with:  winget install Microsoft.NuGet"
}

Write-Host ""
Write-Host "Ready. Try:  flutter run              (pick a device)"
Write-Host "            flutter run -d windows   (desktop)"
Write-Host "            flutter test             (unit and widget tests)"
