#!/bin/bash
#
# build.sh
# Build script for the Flame macOS app
#
# Usage: ./build.sh
#

set -e

APP_NAME="Flame"
BUNDLE_ID="com.example.flame"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "🔥 Building ${APP_NAME} for macOS..."

# Create build directory
mkdir -p "${BUILD_DIR}"

# Clean previous build
if [ -d "${APP_BUNDLE}" ]; then
    echo "Cleaning previous build..."
    rm -rf "${APP_BUNDLE}"
fi

# Create app bundle structure
echo "Creating app bundle structure..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Create Info.plist
echo "Creating Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Compile Swift sources
echo "Compiling Swift sources..."
swiftc \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" \
    -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
    -target arm64-apple-macosx12.0 \
    -framework SwiftUI \
    -framework Metal \
    -framework MetalKit \
    -framework AppKit \
    FireApp.swift \
    ContentView.swift \
    FireShaderView.swift

# Compile Metal shader
echo "Compiling Metal shader..."
xcrun -sdk macosx metal \
    -c FireShader.metal \
    -o "${BUILD_DIR}/FireShader.air"

xcrun -sdk macosx metallib \
    "${BUILD_DIR}/FireShader.air" \
    -o "${APP_BUNDLE}/Contents/Resources/default.metallib"

# Clean up intermediate files
rm -f "${BUILD_DIR}/FireShader.air"

echo "✅ Build complete!"
echo "📦 App bundle created at: ${APP_BUNDLE}"
echo ""
echo "To run the app:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "To install:"
echo "  cp -r ${APP_BUNDLE} /Applications/"
