#!/bin/bash

# SnowTeeth Build Clean Script
# Removes all build artifacts for Android and iOS

set -e

echo "🧹 Cleaning SnowTeeth build artifacts..."

# Clean Android build artifacts
if [ -d "android" ]; then
    echo "📱 Cleaning Android build artifacts..."

    # Remove build directories
    if [ -d "android/app/build" ]; then
        echo "  - Removing android/app/build/"
        rm -rf android/app/build
    fi

    if [ -d "android/build" ]; then
        echo "  - Removing android/build/"
        rm -rf android/build
    fi

    # Remove Gradle cache
    if [ -d "android/.gradle" ]; then
        echo "  - Removing android/.gradle/"
        rm -rf android/.gradle
    fi

    # Remove local.properties (often contains machine-specific paths)
    if [ -f "android/local.properties" ]; then
        echo "  - Removing android/local.properties"
        rm -f android/local.properties
    fi

    echo "✅ Android artifacts cleaned"
fi

# Clean iOS build artifacts
if [ -d "iOS" ]; then
    echo "🍎 Cleaning iOS build artifacts..."

    # Remove build directories
    if [ -d "iOS/SnowTeeth/build" ]; then
        echo "  - Removing iOS/SnowTeeth/build/"
        rm -rf iOS/SnowTeeth/build
    fi

    # Remove DerivedData
    if [ -d "iOS/DerivedData" ]; then
        echo "  - Removing iOS/DerivedData/"
        rm -rf iOS/DerivedData
    fi

    # Remove xcuserdata (user-specific Xcode data)
    find iOS -name "xcuserdata" -type d -print0 | while IFS= read -r -d '' dir; do
        echo "  - Removing $dir"
        rm -rf "$dir"
    done

    # Remove UserInterfaceState files
    find iOS -name "*.xcuserstate" -type f -print0 | while IFS= read -r -d '' file; do
        echo "  - Removing $file"
        rm -f "$file"
    done

    echo "✅ iOS artifacts cleaned"
fi

# Clean GPX build artifacts
if [ -d "gpx" ]; then
    echo "🗺️  Cleaning GPX build artifacts..."

    # Remove Swift build directories
    if [ -d "gpx/.build" ]; then
        echo "  - Removing gpx/.build/"
        rm -rf gpx/.build
    fi

    if [ -d "gpx/build" ]; then
        echo "  - Removing gpx/build/"
        rm -rf gpx/build
    fi

    if [ -d "gpx/venv" ]; then
        echo "  - Removing gpx/venv/"
        rm -rf gpx/venv
    fi

    echo "✅ GPX artifacts cleaned"
fi

# Clean any additional build artifacts
echo "🗑️  Cleaning additional artifacts..."

# Remove common editor/IDE files that might have been created
if [ -d ".idea" ]; then
    echo "  - Removing .idea/"
    rm -rf .idea
fi

if [ -d ".vscode/build" ]; then
    echo "  - Removing .vscode/build/"
    rm -rf .vscode/build
fi

echo ""
echo "✨ All build artifacts cleaned successfully!"
