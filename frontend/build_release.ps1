# Optimized release build for InnerCircle (Windows).
# Run from the frontend/ directory: .\build_release.ps1

$ErrorActionPreference = "Stop"

Write-Host "== Analyze ==" -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "== Format check ==" -ForegroundColor Cyan
dart format --output=none --set-exit-if-changed lib test
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "== Test ==" -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "== Build Android APK (split-per-abi, tree-shake icons) ==" -ForegroundColor Cyan
flutter build apk --release --split-per-abi --tree-shake-icons
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "== Build Android AAB (for Play Store) ==" -ForegroundColor Cyan
flutter build appbundle --release --tree-shake-icons
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "== Done ==" -ForegroundColor Green
