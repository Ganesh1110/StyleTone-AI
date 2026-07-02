#!/usr/bin/env bash
# StyleTone AI APK Build automation script
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "🎯 StyleTone AI - APK Release Builder"
echo "=============================================="
echo "Select your compilation target:"
echo "1) Standard APK (Single file containing all architectures - ~80MB)"
echo "2) Split APKs (Optimized separate files per CPU architecture - ~30MB each)"
echo "3) Compile both options"
echo "=============================================="
read -p "Select build option [1-3]: " opt

echo ""
echo "[*] Cleaning build cache..."
flutter clean

echo "[*] Resolving dependencies..."
flutter pub get

echo "[*] Running static code analysis..."
if ! flutter analyze; then
  echo ""
  echo "⚠️  Static analysis reported warnings. Continuing build..."
fi

echo ""
if [ "$opt" == "1" ]; then
  echo "[*] Compiling standard release APK..."
  flutter build apk --release
elif [ "$opt" == "2" ]; then
  echo "[*] Compiling optimized split-ABI APKs..."
  flutter build apk --release --split-per-abi
else
  echo "[*] Compiling standard & split release APKs..."
  flutter build apk --release
  flutter build apk --release --split-per-abi
fi

echo ""
echo "=============================================="
echo "🎉 Build Finished Successfully!"
echo "=============================================="
echo "Output APK files are located in your build folder:"
echo "📂 build/app/outputs/flutter-apk/"
echo ""
echo "Compiled file details:"
if [ -d "build/app/outputs/flutter-apk" ]; then
  ls -lh build/app/outputs/flutter-apk/*.apk
fi
echo "=============================================="
