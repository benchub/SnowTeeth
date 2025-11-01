# Debug Logging

SnowTeeth uses build-configuration-aware debug logging that automatically disables verbose logs in release builds while keeping error/warning logs for production debugging.

## Overview

**Debug builds**: All logs are enabled for development and debugging
**Release builds**: Only error/warning logs are enabled; verbose debug logs are automatically removed

This approach:
- **Keeps production apps clean** - No verbose logging in release builds
- **Preserves development logs** - Easy to re-enable for debugging
- **No manual toggling** - Automatically controlled by build configuration
- **No performance impact** - Debug logs are completely removed in release builds (iOS) or checked at runtime (Android)

## iOS Implementation

### Debug Logging Helpers

Location: `iOS/SnowTeeth/Utilities/DebugLog.swift`

```swift
// Debug log - only in DEBUG builds (completely removed by compiler in release)
debugLog("Velocity: \(speed) m/s")

// Error log - always logs, even in release builds
errorLog("Failed to write GPX: \(error)")

// Warning log - always logs, even in release builds
warningLog("GPS permission denied")
```

### How It Works

iOS uses conditional compilation with `#if DEBUG`:

```swift
func debugLog(_ items: Any...) {
    #if DEBUG
    print(items...)
    #endif
}
```

- **DEBUG builds**: The `DEBUG` flag is automatically defined, so logs execute
- **Release builds**: The `DEBUG` flag is not defined, so logs are completely removed by the compiler (zero runtime cost)

### Build Configurations

- **Debug**: Run from Xcode, or build with `xcodebuild -configuration Debug`
- **Release**: Archive for App Store, or build with `xcodebuild -configuration Release`

Xcode automatically sets the `DEBUG` flag for Debug builds and removes it for Release builds.

### Examples in Code

```swift
// LocationTrackingService.swift
#if DEBUG
velocityLogTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) {
    debugLog("Velocity: raw=\(rawSpeed) km/h, smoothed=\(smoothedSpeed) km/h")
}
#endif

// Errors always log
try gpxWriter.appendPoint(location: rawLocationData)
} catch {
    errorLog("Error appending point to GPX: \(error)")
}
```

## Android Implementation

### Debug Logging Helpers

Location: `android/app/src/main/java/com/snowteeth/app/util/DebugLog.kt`

```kotlin
// Debug log - only in DEBUG builds
DebugLog.d("TAG", "GPS update received")

// Info log - only in DEBUG builds
DebugLog.i("TAG", "Starting GPS tracking")

// Warning log - always logs, even in release builds
DebugLog.w("TAG", "GPS not enabled")

// Error log - always logs, even in release builds
DebugLog.e("TAG", "Failed to start tracking", exception)
```

### How It Works

Android uses runtime checks with `BuildConfig.DEBUG`:

```kotlin
object DebugLog {
    fun d(tag: String, message: String) {
        if (BuildConfig.DEBUG) {
            Log.d(tag, message)
        }
    }
}
```

- **Debug builds**: `BuildConfig.DEBUG` is `true`, so logs execute
- **Release builds**: `BuildConfig.DEBUG` is `false`, so logs are skipped (minimal runtime cost)

### Build Configurations

- **Debug**: `./gradlew assembleDebug` or run from Android Studio
- **Release**: `./gradlew assembleRelease` or build signed APK

Gradle automatically sets `BuildConfig.DEBUG` based on the build variant.

### ProGuard Optimization (Optional)

For even better release build performance, add ProGuard rules to strip debug logs entirely:

```proguard
# Remove debug logging calls in release builds
-assumenosideeffects class com.snowteeth.app.util.DebugLog {
    public static void d(...);
    public static void i(...);
}
```

This removes debug log calls at compile time, similar to iOS.

### Examples in Code

```kotlin
// LocationTrackingService.kt
private fun startVelocityLogging() {
    DebugLog.i(TAG, "🚀 Starting velocity logging (logs every 5 seconds)")
    heartbeatRunnable = object : Runnable {
        override fun run() {
            DebugLog.i(TAG, "Velocity: raw=$rawSpeed km/h, smoothed=$smoothedSpeed km/h")
            handler.postDelayed(this, 5000)
        }
    }
}

// Errors always log
try {
    gpxWriter.appendPoint(locationData)
} catch (e: Exception) {
    DebugLog.e(TAG, "Error appending point to GPX", e)
}
```

## Log Types and Usage

### Debug Logs (`debugLog` / `DebugLog.d`)
**When to use**: Development-only logging, verbose output, diagnostic information

**Examples**:
- GPS location updates (every second)
- Velocity calculations
- Snow particle collision detection
- Letter bounds calculations

**Behavior**:
- DEBUG builds: ✅ Logs appear
- Release builds: ❌ Completely disabled

### Info Logs (`debugLog` / `DebugLog.i`)
**When to use**: Important state changes during development

**Examples**:
- "GPS tracking started"
- "Velocity logging enabled"
- "First location received"

**Behavior**:
- DEBUG builds: ✅ Logs appear
- Release builds: ❌ Disabled

### Warning Logs (`warningLog` / `DebugLog.w`)
**When to use**: Important issues that should be logged in production

**Examples**:
- "GPS permission denied"
- "Location services disabled"
- "Google Play Services unavailable"

**Behavior**:
- DEBUG builds: ✅ Logs appear
- Release builds: ✅ Logs appear (important for production debugging)

### Error Logs (`errorLog` / `DebugLog.e`)
**When to use**: Errors that should be logged in production

**Examples**:
- "Failed to write GPX file"
- "Location manager error"
- "Media player error"

**Behavior**:
- DEBUG builds: ✅ Logs appear
- Release builds: ✅ Logs appear (critical for production debugging)

## Migration Guide

If you add new logging, use the appropriate helper:

### iOS

```swift
// OLD - always logs
print("Debug info: \(value)")

// NEW - debug only
debugLog("Debug info: \(value)")

// OLD - always logs
print("ERROR: \(error)")

// NEW - error logging
errorLog("\(error)")
```

### Android

```kotlin
// OLD - always logs
Log.d(TAG, "Debug info: $value")

// NEW - debug only
DebugLog.d(TAG, "Debug info: $value")

// OLD - always logs
Log.e(TAG, "Error occurred", exception)

// NEW - error logging
DebugLog.e(TAG, "Error occurred", exception)
```

## Testing

### Verify Debug Logs Are Disabled in Release

**iOS**:
1. Build in Release configuration: `xcodebuild -configuration Release`
2. Run the app
3. Check Console - verbose logs should not appear
4. Errors/warnings should still appear

**Android**:
1. Build release APK: `./gradlew assembleRelease`
2. Install and run the APK
3. Check logcat - verbose logs should not appear
4. Errors/warnings should still appear

### Verify Debug Logs Work in Development

**iOS**:
1. Run from Xcode (Debug configuration by default)
2. Check Console - all logs should appear

**Android**:
1. Run from Android Studio (debug variant by default)
2. Check logcat - all logs should appear

## Current Status

### iOS
- ✅ `LocationTrackingService.swift` - Velocity logging wrapped in `#if DEBUG`
- ✅ `ContentView.swift` - Debug logs use `debugLog()`
- ⚠️ Test files (`run_tests.swift`) - Intentionally always log (test output)
- ⚠️ Effect files (`SnowEffect.swift`, `CollisionDetector.swift`) - Kept as `print()` for now (can be migrated if needed)

### Android
- ✅ `LocationTrackingService.kt` - Velocity logging uses `DebugLog.i()`
- ✅ GPS status logs use `DebugLog.d/i/w()`
- ⚠️ View files (`SnowParticleView.kt`, etc.) - Can be migrated to `DebugLog` if needed

## Future Improvements

1. **Crash reporting integration**: Wire error logs to Crashlytics/Sentry in production
2. **Log levels**: Add VERBOSE level for extremely detailed debugging
3. **Remote logging**: Send production error logs to backend for analysis
4. **ProGuard rules**: Strip Android debug logs at compile time (like iOS)

## References

- iOS Conditional Compilation: https://docs.swift.org/swift-book/ReferenceManual/Statements.html#ID538
- Android BuildConfig: https://developer.android.com/studio/build/gradle-tips#share-custom-fields-and-resource-values-with-your-app-code
- ProGuard optimization: https://www.guardsquare.com/manual/configuration/usage#assumenosideeffects
