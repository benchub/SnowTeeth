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

# Compile Swift sources for both architectures
echo "Compiling Swift sources..."

# Compile for ARM64
swiftc \
    -o "${BUILD_DIR}/${APP_NAME}-arm64" \
    -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
    -target arm64-apple-macosx12.0 \
    -framework SwiftUI \
    -framework Metal \
    -framework MetalKit \
    -framework AppKit \
    FireApp.swift \
    ContentView.swift \
    FireShaderView.swift

# Compile for x86_64
swiftc \
    -o "${BUILD_DIR}/${APP_NAME}-x86_64" \
    -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
    -target x86_64-apple-macosx12.0 \
    -framework SwiftUI \
    -framework Metal \
    -framework MetalKit \
    -framework AppKit \
    FireApp.swift \
    ContentView.swift \
    FireShaderView.swift

# Create universal binary
lipo -create \
    "${BUILD_DIR}/${APP_NAME}-arm64" \
    "${BUILD_DIR}/${APP_NAME}-x86_64" \
    -output "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Clean up architecture-specific binaries
rm -f "${BUILD_DIR}/${APP_NAME}-arm64" "${BUILD_DIR}/${APP_NAME}-x86_64"

# Compile Metal shader with compatible language version
echo "Compiling Metal shader..."
xcrun -sdk macosx metal \
    -std=macos-metal2.0 \
    -mmacosx-version-min=12.0 \
    -c FireShader.metal \
    -o "${BUILD_DIR}/FireShader.air"

xcrun -sdk macosx metallib \
    "${BUILD_DIR}/FireShader.air" \
    -o "${APP_BUNDLE}/Contents/Resources/default.metallib"

# Clean up intermediate files
rm -f "${BUILD_DIR}/FireShader.air"

# Sign the app bundle with ad-hoc signature and entitlements
echo "Codesigning app bundle..."
codesign --force --deep --sign - --entitlements Flame.entitlements --options runtime "${APP_BUNDLE}"

echo "✅ Build complete!"
echo "📦 App bundle created at: ${APP_BUNDLE}"
echo ""
echo "To run the app:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "To install:"
echo "  cp -r ${APP_BUNDLE} /Applications/"
echo ""
echo "Note: When copying to another Mac, you may need to run:"
echo "  xattr -cr ${APP_BUNDLE}"
echo "  to remove quarantine attributes if the app doesn't start."
