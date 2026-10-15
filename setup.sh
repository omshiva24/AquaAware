#!/usr/bin/env bash
# Copyright (c) 2026 P Om Shiva. All rights reserved.
# AquaAware: unauthorised copying, modification or distribution of this file,
# by any means, is prohibited without the author's written permission. See LICENSE.
# One-time setup on macOS or Linux: creates the native platform folders,
# configures permissions, and downloads packages. Safe to run again.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed. Get it from https://docs.flutter.dev/get-started/install, then run this again."
  exit 1
fi

echo "1/3  Creating platform folders (android, ios, web, windows, macos, linux)…"
flutter create . --project-name aquaaware --org org.aquaaware \
  --platforms android,ios,web,windows,macos,linux >/dev/null

echo "2/3  Configuring permissions and security settings…"
dart run tool/configure_platforms.dart

echo "3/3  Downloading packages…"
flutter pub get

echo
echo "Ready. Try:  flutter run            (pick a device)"
echo "            flutter run -d chrome  (web)"
echo "            flutter test           (unit and widget tests)"
