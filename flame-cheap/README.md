# 🔥 3D Fire Shader - Cross-Platform Implementation

A realistic volumetric fire shader ported from GLSL to work natively on macOS, iOS, and Android. This implementation uses Metal for Apple platforms and OpenGL ES 3.0 for Android.

## 🎉 Complete macOS App Available!

**Want to use this right away?** A complete, ready-to-run macOS app with controls is included!

👉 **See [QUICKSTART.md](QUICKSTART.md)** for 5-minute setup guide
👉 **See [MACOS_APP_SUMMARY.md](MACOS_APP_SUMMARY.md)** for full details

The app includes:
- Beautiful SwiftUI interface with real-time controls
- 4 preset fire effects (Campfire, Inferno, Gentle, Reset)
- Adjustable parameters (speed, intensity, height, turbulence, color)
- 60 FPS GPU-accelerated rendering

---

## Features

- **Realistic fire rendering** using volumetric raymarching
- **60 FPS performance** on all platforms
- **Customizable parameters** for different fire effects
- **Cross-platform** support (iOS, macOS, Android)
- **Easy integration** with SwiftUI, UIKit, and Android Views

## Files

### iOS/macOS
- `FireShader.metal` - Metal compute shader
- `FireShaderView.swift` - Swift wrapper with UIKit/AppKit and SwiftUI support

### Android
- `fire_shader.frag` - OpenGL ES fragment shader
- `fire_shader.vert` - OpenGL ES vertex shader
- `FireShaderView.kt` - Kotlin wrapper with GLSurfaceView

## Parameters

All implementations support the following customizable parameters:

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `speed` | 1.0 | 0.5-2.0 | Animation speed |
| `intensity` | 1.5 | 0.5-3.0 | Flame brightness |
| `height` | 1.0 | 0.5-2.0 | Vertical flame expansion |
| `turbulence` | 1.0 | 0.5-2.0 | Chaos/detail level |
| `colorShift` | 1.0 | 0.5-2.0 | Color temperature shift |

## Usage Examples

### iOS (SwiftUI)

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        FireShaderSwiftUIView()
            .edgesIgnoringSafeArea(.all)
    }
}
```

### iOS/macOS (UIKit/AppKit)

```swift
import UIKit // or import AppKit for macOS

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Create fire shader view
        let fireView = FireShaderView(frame: view.bounds,
                                      device: MTLCreateSystemDefaultDevice())
        fireView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Customize parameters
        fireView.intensity = 2.0
        fireView.speed = 0.8
        fireView.turbulence = 1.5

        view.addSubview(fireView)
    }
}
```

### Android

#### XML Layout

```xml
<com.example.fireshader.FireShaderView
    android:id="@+id/fireShaderView"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

#### Activity/Fragment

```kotlin
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val fireView = findViewById<FireShaderView>(R.id.fireShaderView)

        // Customize parameters
        fireView.intensity = 2.0f
        fireView.speed = 0.8f
        fireView.turbulence = 1.5f
    }
}
```

#### Programmatic Creation

```kotlin
val fireView = FireShaderView(context).apply {
    layoutParams = ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT
    )
    intensity = 2.0f
    speed = 0.8f
    turbulence = 1.5f
}
containerView.addView(fireView)
```

## Setup Instructions

### iOS/macOS

1. Add both files to your Xcode project:
   - `FireShader.metal`
   - `FireShaderView.swift`

2. Ensure Metal framework is linked (it should be by default)

3. Add the Metal shader to your build target:
   - Select `FireShader.metal` in Project Navigator
   - Check that your app target is selected in File Inspector

4. Use the view as shown in the examples above

### Android

1. Add the Kotlin file to your project:
   ```
   app/src/main/java/com/example/fireshader/FireShaderView.kt
   ```

2. (Optional) If you prefer loading shaders from files, place shader files in assets:
   ```
   app/src/main/assets/fire_shader.vert
   app/src/main/assets/fire_shader.frag
   ```
   Then modify `FireRenderer` to load from assets instead of using inline strings.

3. Ensure your app's `build.gradle` has OpenGL ES dependency (usually included by default):
   ```gradle
   android {
       defaultConfig {
           // OpenGL ES 3.0 support
           minSdkVersion 18
       }
   }
   ```

4. Add OpenGL ES feature in `AndroidManifest.xml`:
   ```xml
   <uses-feature android:glEsVersion="0x00030000" android:required="true" />
   ```

## Performance Tips

- The shader performs 50 raymarching iterations with 8 turbulence loops each
- On lower-end devices, you may want to reduce iterations for better performance
- Consider adding quality settings that adjust iteration counts
- The shader runs at 60 FPS on most modern devices

## Customization Ideas

### Different Fire Colors

Adjust `colorShift` parameter:
- `0.5` - Cooler, bluish fire
- `1.0` - Standard orange/yellow fire
- `1.5` - Hot white/yellow fire
- `2.0` - Extreme hot fire

### Campfire Effect

```swift
// iOS/macOS
fireView.intensity = 1.0
fireView.height = 0.7
fireView.speed = 0.6
fireView.turbulence = 1.2
```

```kotlin
// Android
fireView.intensity = 1.0f
fireView.height = 0.7f
fireView.speed = 0.6f
fireView.turbulence = 1.2f
```

### Explosion Effect

```swift
// iOS/macOS
fireView.intensity = 3.0
fireView.height = 1.5
fireView.speed = 2.0
fireView.turbulence = 2.0
```

```kotlin
// Android
fireView.intensity = 3.0f
fireView.height = 1.5f
fireView.speed = 2.0f
fireView.turbulence = 2.0f
```

## How It Works

The shader uses several techniques to create realistic fire:

1. **Volumetric Raymarching**: Samples 3D space along rays from camera to build up the fire volume

2. **Hollow Cone Distance Field**: Models fire as a hollow cone shape, matching real fire physics

3. **Multi-Octave Turbulence**: 8 iterations of noise at different frequencies create chaotic, natural-looking flames

4. **Frequency Scaling**: Each turbulence loop reduces frequency by 0.6x, creating detail at multiple scales

5. **Color Mapping**: Uses sine waves to map distance to fire colors (red → orange → yellow → white)

6. **Tone Mapping**: Tanh approximation prevents color oversaturation while maintaining brightness

## License

This implementation is based on the fire shader from shadcn.io. Feel free to use and modify for your projects.

## Credits

- Original shader concept from [shadcn.io/shaders/fire-3d-shaders](https://www.shadcn.io/shaders/fire-3d-shaders)
- Ported to Metal and OpenGL ES 3.0 for native mobile/desktop use
