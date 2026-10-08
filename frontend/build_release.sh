#!/usr/bin/env bash
# Optimized release build commands for InnerCircle.
# Run from the frontend/ directory.

set -euo pipefail

echo "== Analyze =="
flutter analyze

echo "== Format check =="
dart format --output=none --set-exit-if-changed lib test

echo "== Test =="
flutter test

echo "== Build Android (split-per-abi, tree-shake icons) =="
# --split-per-abi produces per-architecture APKs (~40% smaller than
# a universal APK). Use --bundle for AAB when uploading to Play Store.
flutter build apk --release --split-per-abi --tree-shake-icons

echo "== Build Android AAB (for Play Store) =="
flutter build appbundle --release --tree-shake-icons

echo "== Build iOS =="
flutter build ipa --release --tree-shake-icons

echo "== Done =="
