#!/bin/bash
set -e

export FLUTTER_ALLOW_ROOT=true

echo "==> Cloning Flutter SDK..."
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /tmp/flutter-sdk
FLUTTER=/tmp/flutter-sdk/bin/flutter

echo "==> Flutter version:"
$FLUTTER --version

echo "==> Getting dependencies..."
cd ventigo_app
$FLUTTER pub get

echo "==> Building web..."
$FLUTTER build web --release \
  --dart-define=API_BASE_URL=${API_BASE_URL:-}

# Fail loudly if Flutter didn't produce output
if [ ! -f "build/web/index.html" ]; then
  echo "ERROR: Flutter build did not produce build/web/index.html"
  exit 1
fi

echo "==> Build complete!"