#!/bin/bash
# Build script for GPXViewer app
# Builds the app and copies the binary to the app bundle

set -e  # Exit on error

echo "Building GPXViewer..."
swift build

# Create app bundle structure if it doesn't exist
echo "Setting up app bundle structure..."
mkdir -p build/GPXViewer.app/Contents/MacOS
mkdir -p build/GPXViewer.app/Contents/Resources

# Create Info.plist if it doesn't exist
if [ ! -f build/GPXViewer.app/Contents/Info.plist ]; then
    cat > build/GPXViewer.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>GPXViewer</string>
    <key>CFBundleIdentifier</key>
    <string>com.snowteeth.gpxviewer</string>
    <key>CFBundleName</key>
    <string>GPXViewer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
fi

echo "Copying binary to app bundle..."
cp .build/arm64-apple-macosx/debug/GPXViewer build/GPXViewer.app/Contents/MacOS/GPXViewer

echo "Build complete! App is ready at: build/GPXViewer.app"
echo "To run: open build/GPXViewer.app"
