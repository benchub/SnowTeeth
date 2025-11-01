# 🔥 Flame - Quickstart Guide

A beautiful 3D fire shader app for macOS with real-time controls.

## The Easiest Way: Using Xcode

### 1. Create New Project

Open Xcode and create a new macOS App:
- **File → New → Project**
- Choose **macOS** → **App**
- Product Name: **Flame**
- Interface: **SwiftUI**
- Language: **Swift**

### 2. Add the Files

Delete the default `ContentView.swift` and add these files to your project:

```
FireApp.swift         ← Main app entry point
ContentView.swift     ← UI with controls
FireShaderView.swift  ← Metal view wrapper
FireShader.metal      ← Metal shader
```

**Drag and drop** them into Xcode, making sure:
- ✅ "Copy items if needed" is checked
- ✅ "Flame" target is selected

### 3. Update the Main File

Replace the content of the auto-generated app file with `FireApp.swift`, or just make sure `@main` is only in `FireApp.swift`.

### 4. Run

Press **⌘R** or click the **Play button** ▶️

That's it! You should see beautiful animated fire! 🔥

## Controls

Once the app is running:

- **Show/Hide Controls**: Click the button in the top-right
- **Speed**: How fast the fire animates
- **Intensity**: How bright the fire appears
- **Height**: How tall the flames are
- **Turbulence**: How chaotic the fire looks
- **Color Shift**: Changes fire color (cooler to hotter)

### Presets

- **Campfire**: Gentle, warm campfire
- **Inferno**: Intense, raging fire
- **Gentle**: Soft, calm flames
- **Reset**: Back to defaults

## Requirements

- macOS 11.0 or later
- Mac with Metal support (2012 or later)
- Xcode 13 or later

## Troubleshooting

### Black Screen?
- Check Xcode console for errors
- Make sure `FireShader.metal` is in the target
- Try cleaning: **Product → Clean Build Folder** (⇧⌘K)

### Build Errors?
- Verify deployment target is macOS 11.0+
- Check that all 4 files are added to the target
- Make sure `@main` only appears in `FireApp.swift`

### Still Not Working?
See the detailed `BUILD_INSTRUCTIONS.md` for more help.

## What's Inside?

This app uses:
- **Metal compute shaders** for GPU-accelerated rendering
- **Volumetric raymarching** to create 3D fire
- **Multi-octave turbulence** for realistic flame motion
- **SwiftUI** for the control interface

See `ALGORITHM.md` for technical details about how the shader works.

## Customization

All shader parameters can be adjusted in real-time. Try experimenting with extreme values to see interesting effects!

Want to modify the shader itself? Edit `FireShader.metal` - any changes will be reflected when you rebuild.

---

**Enjoy your fire! 🔥**

For more information, check out:
- `BUILD_INSTRUCTIONS.md` - Detailed build guide
- `ALGORITHM.md` - How the shader works
- `README.md` - Full documentation
