#!/bin/bash
#
# verify_files.sh
# Verify all necessary files are present for building the Flame app
#

echo "🔥 Verifying Flame app files..."
echo ""

REQUIRED_FILES=(
    "FireApp.swift"
    "ContentView.swift"
    "FireShaderView.swift"
    "FireShader.metal"
)

OPTIONAL_FILES=(
    "build.sh"
    "BUILD_INSTRUCTIONS.md"
    "README.md"
)

missing_files=0
found_files=0

echo "✅ Required files:"
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
        ((found_files++))
    else
        echo "  ✗ $file (MISSING)"
        ((missing_files++))
    fi
done

echo ""
echo "📄 Optional files:"
for file in "${OPTIONAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  - $file (not found)"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $missing_files -eq 0 ]; then
    echo "✅ All required files present! ($found_files/$found_files)"
    echo ""
    echo "Next steps:"
    echo "  1. Open Xcode"
    echo "  2. Create new macOS App project"
    echo "  3. Drag these files into your project"
    echo "  4. Build and run!"
    echo ""
    echo "Or use the build script:"
    echo "  ./build.sh"
    echo ""
else
    echo "❌ Missing $missing_files required file(s)"
    echo ""
    echo "Please ensure all required files are present."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
