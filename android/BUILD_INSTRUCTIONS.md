# Build Instructions for SnowTeeth

## Quick Start

### 1. Generate Gradle Wrapper
The project needs the Gradle wrapper files to build. Run:

```bash
cd <your-project-root>
gradle wrapper --gradle-version 8.2
```

This will create the `gradlew` and `gradlew.bat` scripts along with the wrapper JAR.

### 2. Open in Android Studio
1. Launch Android Studio
2. Select "Open an Existing Project"
3. Navigate to your project root directory (or the `android` subdirectory if opening just the Android project)
4. Click "OK"
5. Wait for Gradle sync to complete

### 3. Add Launcher Icons (Optional but Recommended)
The app references launcher icons that need to be added. You can:
- Use Android Studio's Image Asset tool: Right-click on `res` → New → Image Asset
- Or manually add launcher icons to:
  - `app/src/main/res/mipmap-hdpi/ic_launcher.png`
  - `app/src/main/res/mipmap-mdpi/ic_launcher.png`
  - `app/src/main/res/mipmap-xhdpi/ic_launcher.png`
  - `app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
  - `app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

### 4. Build and Run
#### Using Android Studio:
1. Connect an Android device or start an emulator
2. Click the "Run" button (green play icon)
3. Select your device
4. App will install and launch

#### Using Command Line:
```bash
./gradlew assembleDebug
```

The APK will be located at:
```
app/build/outputs/apk/debug/app-debug.apk
```

## Running Tests

### Unit Tests
```bash
./gradlew test
```

### View Test Results
Results will be available at:
```
app/build/reports/tests/testDebugUnitTest/index.html
```

## Troubleshooting

### Issue: "gradlew: command not found"
Solution: Run `gradle wrapper --gradle-version 8.2` first

### Issue: SDK version errors
Solution: Ensure you have Android SDK 34 installed via Android Studio's SDK Manager

### Issue: Location permissions not working
Solution:
- For Android 6.0+: Manually grant location permissions in device settings
- For Android 10+: Select "Allow all the time" for background location access

### Issue: Missing Google Play Services
Solution: The emulator or device must have Google Play Services installed for location tracking

## First Run Setup

1. Launch the app
2. Grant location permissions when prompted
3. Grant notification permissions (Android 13+)
4. Configure thresholds in Configuration screen if desired
5. Tap "Toggle Tracking" to start recording
6. Enter Visualization mode to see real-time feedback

## Development Notes

- **Minimum Android Version**: Android 8.0 (API 26)
- **Target Android Version**: Android 14 (API 34)
- **JDK Version**: 17
- **Gradle Version**: 8.2
- **Kotlin Version**: 1.9.20

## Common Gradle Commands

```bash
# Clean build
./gradlew clean

# Build debug APK
./gradlew assembleDebug

# Build release APK (requires signing config)
./gradlew assembleRelease

# Run all tests
./gradlew test

# Run lint checks
./gradlew lint

# Install debug APK on connected device
./gradlew installDebug
```

## Testing on Device vs Emulator

### Physical Device (Recommended)
- Provides real GPS data
- Better for testing actual skiing/snowboarding activities
- Accurate speed and elevation measurements

### Emulator
- Can simulate location via Android Studio's Extended Controls
- Good for UI testing
- Location updates may be less realistic

## Next Steps After Building

1. Test basic navigation between all four screens
2. Configure velocity thresholds to your preference
3. Test tracking by going for a walk/drive
4. Verify GPX file is created in app's files directory
5. Check stats screen displays correct data
6. Test both Flame and Colors visualization styles
