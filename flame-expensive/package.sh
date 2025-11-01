#!/bin/bash
#
# package.sh
# Creates a distributable package of Flame.app
#

set -e

APP_NAME="Flame"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
PACKAGE_NAME="Flame-macOS.zip"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "❌ Error: ${APP_BUNDLE} not found. Run ./build.sh first."
    exit 1
fi

echo "📦 Creating distributable package..."

# Remove any existing package
rm -f "${BUILD_DIR}/${PACKAGE_NAME}"

# Create a README with instructions
cat > "${BUILD_DIR}/README.txt" << 'EOF'
Flame - 3D Fire Shader for macOS
=================================

Installation Instructions:
1. Extract Flame.app from this archive
2. Move Flame.app to your Applications folder (or anywhere you like)
3. Right-click on Flame.app and select "Open"
4. Click "Open" in the security dialog
5. The app will now run normally

If the app shows a black screen or doesn't start:
- Open Terminal and run: xattr -cr /path/to/Flame.app
- Then try opening the app again

System Requirements:
- macOS 12.0 or later
- Metal-compatible GPU

Enjoy!
EOF

# Create zip archive
cd "${BUILD_DIR}"
zip -r "${PACKAGE_NAME}" "${APP_NAME}.app" README.txt -q
cd ..

# Clean up README
rm "${BUILD_DIR}/README.txt"

echo "✅ Package created: ${BUILD_DIR}/${PACKAGE_NAME}"
echo ""
echo "Distribution instructions:"
echo "  1. Share ${BUILD_DIR}/${PACKAGE_NAME} with others"
echo "  2. Recipients should extract and right-click → Open the first time"
echo "  3. If needed, run: xattr -cr Flame.app"
