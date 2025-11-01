#!/bin/bash

# Script to generate app icons for both Android and iOS from a source image
# Usage: ./generate-icons.sh <path-to-source-image>
#
# Requirements:
# - Source image should be 1024x1024 pixels (square)
# - ImageMagick (for Android circular icons): brew install imagemagick
# - macOS with sips command (built-in, for iOS icons)

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    echo -e "${RED}Error: ImageMagick is not installed${NC}"
    echo "Install with: brew install imagemagick"
    exit 1
fi

# Use 'magick' if available (IMv7), otherwise fall back to 'convert' (IMv6)
if command -v magick &> /dev/null; then
    MAGICK_CMD="magick"
else
    MAGICK_CMD="convert"
fi

# Check if source image is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: No source image provided${NC}"
    echo "Usage: $0 <path-to-source-image>"
    echo "Example: $0 images/icon.jpeg"
    exit 1
fi

SOURCE_IMAGE="$1"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo -e "${RED}Error: Source image '$SOURCE_IMAGE' not found${NC}"
    exit 1
fi

# Check image dimensions
WIDTH=$(sips -g pixelWidth "$SOURCE_IMAGE" | tail -n1 | awk '{print $2}')
HEIGHT=$(sips -g pixelHeight "$SOURCE_IMAGE" | tail -n1 | awk '{print $2}')

if [ "$WIDTH" != "1024" ] || [ "$HEIGHT" != "1024" ]; then
    echo -e "${YELLOW}Warning: Source image is ${WIDTH}x${HEIGHT}. Recommended size is 1024x1024${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}Generating app icons from: $SOURCE_IMAGE${NC}"
echo

# Generate Android icons
echo "📱 Generating Android icons..."

# Android icon sizes: density:size
ANDROID_SIZES="mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192"

for density_size in $ANDROID_SIZES; do
    IFS=':' read -r density size <<< "$density_size"
    output_dir="android/app/src/main/res/mipmap-${density}"

    # Generate foreground layer (for adaptive icons on Android 8.0+)
    # Scale to 75% to fit within adaptive icon safe zone (center 66% is always visible)
    foreground_file="${output_dir}/ic_launcher_foreground.png"
    inner_size=$((size * 3 / 4))
    echo "  → ${density}: ${size}x${size}px (adaptive foreground at 75%)"

    $MAGICK_CMD "$SOURCE_IMAGE" \
        -resize "${inner_size}x${inner_size}" \
        -background none \
        -gravity center \
        -extent "${size}x${size}" \
        "$foreground_file" 2>/dev/null

    # Generate legacy launcher icon (for Android 7.1 and below)
    # This uses a circular mask since older Android doesn't support adaptive icons
    legacy_file="${output_dir}/ic_launcher.png"
    half=$((size/2))

    $MAGICK_CMD "$SOURCE_IMAGE" \
        -resize "${size}x${size}" \
        \( +clone -alpha extract \
           -draw "fill black polygon 0,0 0,$size $size,$size $size,0" \
           -draw "fill white circle $half,$half $half,0" \
        \) \
        -alpha off -compose CopyOpacity -composite \
        "$legacy_file" 2>/dev/null
done

# Create adaptive icon XML (for Android 8.0+)
echo "  → Creating adaptive icon configuration"
mkdir -p android/app/src/main/res/mipmap-anydpi-v26

cat > android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
EOF

echo -e "${GREEN}✓ Android icons generated (adaptive + legacy)${NC}"
echo

# Generate Android splash screen icons (for Android 12+ splash screen API)
echo "📱 Generating Android splash screen icons..."

# Splash screen icon sizes (higher resolution): density:size
SPLASH_SIZES="mdpi:192 hdpi:288 xhdpi:384 xxhdpi:576 xxxhdpi:768"

for density_size in $SPLASH_SIZES; do
    IFS=':' read -r density size <<< "$density_size"
    output_dir="android/app/src/main/res/drawable-${density}"
    mkdir -p "$output_dir"

    splash_file="${output_dir}/splash_icon.png"
    inner_size=$((size * 3 / 4))
    echo "  → ${density}: ${size}x${size}px (splash icon at 75%)"

    $MAGICK_CMD "$SOURCE_IMAGE" \
        -resize "${inner_size}x${inner_size}" \
        -background none \
        -gravity center \
        -extent "${size}x${size}" \
        "$splash_file" 2>/dev/null
done

# Create Android 12+ splash screen theme configuration
echo "  → Creating Android 12+ splash screen configuration"
mkdir -p android/app/src/main/res/values-v31

cat > android/app/src/main/res/values-v31/themes.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Android 12+ Splash Screen Theme -->
    <style name="Theme.SnowTeeth" parent="Theme.MaterialComponents.DayNight.NoActionBar">
        <item name="colorPrimary">@color/blue</item>
        <item name="colorPrimaryVariant">@color/blue_dark</item>
        <item name="colorOnPrimary">#FFFFFF</item>
        <item name="colorSecondary">@color/blue</item>
        <item name="colorSecondaryVariant">@color/blue_dark</item>
        <item name="colorOnSecondary">#FFFFFF</item>

        <!-- Splash Screen attributes for Android 12+ -->
        <item name="android:windowSplashScreenBackground">@color/ic_launcher_background</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/splash_icon</item>
        <item name="android:windowSplashScreenAnimationDuration">300</item>
    </style>
</resources>
EOF

echo -e "${GREEN}✓ Android splash screen icons generated${NC}"
echo

# Generate iOS icon
echo "🍎 Generating iOS icon..."
IOS_ICON_DIR="iOS/SnowTeeth/SnowTeeth/Assets.xcassets/AppIcon.appiconset"
IOS_ICON_FILE="${IOS_ICON_DIR}/icon-1024.png"

echo "  → 1024x1024px (universal)"
cp "$SOURCE_IMAGE" "$IOS_ICON_FILE"
sips -s format png "$IOS_ICON_FILE" > /dev/null 2>&1

echo -e "${GREEN}✓ iOS icon generated${NC}"
echo

# Update iOS Contents.json if needed
CONTENTS_JSON="${IOS_ICON_DIR}/Contents.json"
if ! grep -q "icon-1024.png" "$CONTENTS_JSON"; then
    echo "📝 Updating iOS Contents.json..."
    # This would require manual update or a more complex script
    echo -e "${YELLOW}Note: You may need to verify Contents.json references icon-1024.png${NC}"
fi

# Verify Android manifest has icon reference
ANDROID_MANIFEST="android/app/src/main/AndroidManifest.xml"
if ! grep -q 'android:icon="@mipmap/ic_launcher"' "$ANDROID_MANIFEST"; then
    echo -e "${YELLOW}Warning: AndroidManifest.xml may need to be updated with:${NC}"
    echo '  android:icon="@mipmap/ic_launcher"'
fi

echo
echo -e "${GREEN}✨ Icon generation complete!${NC}"
echo
echo "Generated icons:"
echo "  Android: 5 densities (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)"
echo "  iOS: 1024x1024 universal icon"
echo
echo "Next steps:"
echo "  1. Build and run your app to see the new icons"
echo "  2. For Android: Check app drawer after installation"
echo "  3. For iOS: Check home screen after installation"
