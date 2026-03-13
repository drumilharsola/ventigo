#!/bin/bash
set -e

export FLUTTER_ALLOW_ROOT=true

echo "==> Cloning Flutter SDK..."
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /tmp/flutter-sdk
FLUTTER=/tmp/flutter-sdk/bin/flutter

echo "==> Flutter version:"
$FLUTTER --version

echo "==> Getting dependencies..."
cd unburden_app
$FLUTTER pub get

echo "==> Building web..."
$FLUTTER build web --release --dart-define=API_BASE_URL=${API_BASE_URL:-}

echo "==> Build complete!"
