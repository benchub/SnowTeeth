#!/bin/bash

# Script to copy Yeti visualization videos to iOS and Android app bundles

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VIDEO_SOURCE="$SCRIPT_DIR/video"
IOS_DEST="$SCRIPT_DIR/iOS/SnowTeeth/Resources/Videos"
ANDROID_DEST="$SCRIPT_DIR/android/app/src/main/assets/videos"

echo "=== Copying Yeti Visualization Videos ==="
echo ""

# Check if source directory exists
if [ ! -d "$VIDEO_SOURCE" ]; then
    echo "ERROR: Video source directory not found: $VIDEO_SOURCE"
    exit 1
fi

# Count video files
VIDEO_COUNT=$(find "$VIDEO_SOURCE" -name "*.mp4" -type f | wc -l | tr -d ' ')
echo "Found $VIDEO_COUNT video files in source directory"
echo ""

# Create iOS destination directory
echo "Setting up iOS..."
mkdir -p "$IOS_DEST"

# Symlink videos to iOS
echo "Creating symlinks for iOS bundle..."
for video in "$VIDEO_SOURCE"/*.mp4; do
    filename=$(basename "$video")
    if [ ! -e "$IOS_DEST/$filename" ]; then
        ln -s "$video" "$IOS_DEST/$filename"
        echo "  Linked: $filename"
    else
        echo "  Exists: $filename"
    fi
done
IOS_LINKED=$(find "$IOS_DEST" -name "*.mp4" | wc -l | tr -d ' ')
echo "✓ Linked $IOS_LINKED videos to iOS"
echo ""

# Create Android destination directory
echo "Setting up Android..."
mkdir -p "$ANDROID_DEST"

# Copy videos to Android (Android build system doesn't follow symlinks)
echo "Copying videos to Android bundle..."
rm -f "$ANDROID_DEST"/*.mp4  # Remove old symlinks if any
for video in "$VIDEO_SOURCE"/*.mp4; do
    filename=$(basename "$video")
    cp "$video" "$ANDROID_DEST/$filename"
    echo "  Copied: $filename"
done
ANDROID_COPIED=$(find "$ANDROID_DEST" -name "*.mp4" -type f | wc -l | tr -d ' ')
echo "✓ Copied $ANDROID_COPIED videos to Android"
echo ""

echo "=== Summary ==="
echo "iOS destination:     $IOS_DEST ($IOS_LINKED files)"
echo "Android destination: $ANDROID_DEST ($ANDROID_COPIED files)"
echo ""
echo "⚠️  IMPORTANT: You must add the iOS videos to the Xcode project manually:"
echo "   1. Open SnowTeeth.xcodeproj in Xcode"
echo "   2. Right-click on the project navigator"
echo "   3. Select 'Add Files to SnowTeeth...'"
echo "   4. Navigate to iOS/SnowTeeth/Resources/Videos/"
echo "   5. Select all .mp4 files"
echo "   6. Ensure 'Copy items if needed' is UNCHECKED (files are already in place)"
echo "   7. Ensure 'Add to targets: SnowTeeth' is CHECKED"
echo ""
echo "✓ Script complete!"
