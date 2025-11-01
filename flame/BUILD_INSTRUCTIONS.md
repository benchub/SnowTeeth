# Building the Flame macOS App

This guide provides multiple methods to build and run the Flame fire shader app on macOS.

## Method 1: Using Xcode (Recommended)

This is the easiest method and provides the best development experience.

### Step 1: Create New Xcode Project

1. Open Xcode
2. File → New → Project
3. Select **macOS** → **App**
4. Configure your project:
   - Product Name: `Flame`
   - Team: Select your team or use personal team
   - Organization Identifier: `com.yourname` (or similar)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Click **Next** and choose a location

### Step 2: Add Files to Project

1. Delete the default `ContentView.swift` that Xcode created
2. Drag and drop these files into your Xcode project:
   - `FireApp.swift` → Replace the default `FlameApp.swift`
   - `ContentView.swift`
   - `FireShaderView.swift`
   - `FireShader.metal`
3. Make sure "Copy items if needed" is checked
4. Ensure all files are added to the `Flame` target

### Step 3: Update Main App File

1. Open the default app file (e.g., `FlameApp.swift`)
2. Replace its contents with the contents of `FireApp.swift`, OR
3. Delete the default file and ensure `FireApp.swift` is the `@main` entry point

### Step 4: Configure Project Settings

1. Select your project in the navigator
2. Select the `Flame` target
3. Go to **Signing & Capabilities**
   - Select your team
   - Xcode will automatically manage signing
4. Go to **Info** tab
   - Set **Minimum Deployments** to macOS 11.0 or later

### Step 5: Build and Run

1. Select your Mac as the destination (not a simulator)
2. Press ⌘R or click the Play button
3. The app should build and run, displaying the fire shader

---

## Method 2: Using the Build Script

For advanced users who prefer command-line builds.

### Prerequisites

- Xcode Command Line Tools installed
- Swift compiler available (`xcodebuild -version`)

### Steps

1. Make the build script executable:
   ```bash
   chmod +x build.sh
   ```

2. Run the build script:
   ```bash
   ./build.sh
   ```

3. Open the built app:
   ```bash
   open build/Flame.app
   ```

### Installing to Applications

```bash
cp -r build/Flame.app /Applications/
```

**Note:** The app built this way won't be code-signed, so you may need to right-click → Open the first time you run it.

---

## Method 3: Quick Test with swiftc

For quick testing without creating a full app bundle:

```bash
# Compile Metal shader
xcrun -sdk macosx metal -c FireShader.metal -o FireShader.air
xcrun -sdk macosx metallib FireShader.air -o default.metallib

# Create a test app
mkdir -p FlameTest.app/Contents/MacOS
mkdir -p FlameTest.app/Contents/Resources

# Compile Swift
swiftc \
  -o FlameTest.app/Contents/MacOS/Flame \
  -framework SwiftUI \
  -framework Metal \
  -framework MetalKit \
  -framework AppKit \
  FireApp.swift \
  ContentView.swift \
  FireShaderView.swift

# Copy Metal library
cp default.metallib FlameTest.app/Contents/Resources/

# Run
open FlameTest.app
```

---

## Troubleshooting

### "Metal is not supported on this device"

- Make sure you're running on a Mac with Metal support (2012 or later)
- Check that Metal is available: run `system_profiler SPDisplaysDataType | grep Metal`

### "Failed to load shader library"

- Ensure `FireShader.metal` is included in the target
- Check the Build Phases → Compile Sources contains the `.metal` file
- Clean build folder: Product → Clean Build Folder (⇧⌘K)

### Black screen or no fire visible

- Check the console for error messages
- Verify Metal shaders compiled successfully
- Try resetting parameters using the "Reset" button

### Build errors about missing imports

- Ensure deployment target is macOS 11.0 or later
- Verify all frameworks are linked: Metal, MetalKit, SwiftUI, AppKit

### "Command PhaseScriptExecution failed"

- This usually means the Metal shader compilation failed
- Check for syntax errors in `FireShader.metal`
- Look at the detailed build log for specific error messages

### App crashes on launch

- Check that `@main` is only on one file (should be `FireApp.swift`)
- Verify the Metal device is created successfully
- Enable exception breakpoints in Xcode to catch the crash

---

## Project Structure

```
flame2/
├── FireApp.swift           # Main app entry point (@main)
├── ContentView.swift       # UI with controls
├── FireShaderView.swift    # Metal view wrapper
├── FireShader.metal        # Metal compute shader
├── build.sh               # Build script
└── BUILD_INSTRUCTIONS.md  # This file
```

---

## Customizing the App

### Change Window Size

Edit `FireApp.swift`:

```swift
WindowGroup {
    ContentView()
        .frame(minWidth: 600, minHeight: 400)
}
.defaultSize(width: 800, height: 600)
```

### Change App Name

1. In Xcode: Select target → General → Display Name
2. In build script: Change `APP_NAME="Flame"` to your desired name

### Add App Icon

1. Create an app icon set (1024×1024 PNG)
2. In Xcode: Assets → AppIcon
3. Drag your icon into the 1024pt slot

### Bundle Identifier

Change in Xcode: Target → Signing & Capabilities → Bundle Identifier

---

## Distribution

### For Personal Use

The Xcode-built app can be copied to Applications and run immediately.

### For Sharing

1. **Archive**: Product → Archive
2. **Export**: Distribute App → Copy App
3. Share the exported `.app`

**Note:** Users may need to right-click → Open the first time (if not notarized)

### For App Store

1. Enroll in Apple Developer Program
2. Set up proper signing certificates
3. Archive and upload via Xcode
4. Submit for review

---

## Performance Tips

- The shader runs at 60 FPS on most modern Macs
- On older Macs (2012-2015), you might want to reduce:
  - Raymarch iterations (in `.metal`: change `50.0` to `30.0`)
  - Turbulence loops (change `8` to `5`)
- Use Activity Monitor to check GPU usage
- On laptops, the app will use integrated GPU by default (you can force discrete GPU in Get Info)

---

## Next Steps

- Add keyboard shortcuts for presets
- Implement fullscreen mode
- Add more fire presets
- Create an export feature (render to video)
- Add sound effects
- Implement multiple fire sources

Enjoy your realistic fire shader! 🔥
