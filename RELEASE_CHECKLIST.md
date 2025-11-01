# Release Checklist

Track progress toward App Store and Google Play release readiness.

## Status Legend
- ❌ Not started
- 🚧 In progress
- ✅ Complete
- ⏸️ Blocked/waiting

---

## Critical for Release

### iOS

#### Code Signing & Configuration
- ❌ **Signing Certificate** - Set up proper distribution certificate (currently "Automatic")
- ❌ **Team ID** - Configure DEVELOPMENT_TEAM in project.pbxproj
- ❌ **Bundle Identifier** - Verify/register with Apple Developer Portal
- ❌ **Provisioning Profile** - Create App Store distribution profile

#### Privacy & Permissions
- ✅ **Privacy Manifest (PrivacyInfo.xcprivacy)** - Required for location tracking
  - ✅ Declared NSPrivacyTracking = false (no third-party tracking)
  - ✅ Declared NSPrivacyTrackingDomains (empty - no domains)
  - ✅ Declared NSPrivacyCollectedDataTypes (precise location, not linked to user, app functionality only)
  - ✅ Declared NSPrivacyAccessedAPITypes (UserDefaults, FileTimestamp, SystemBootTime, DiskSpace)
  - ✅ Added to Xcode project (in membershipExceptions)

#### Assets & Resources
- ❌ **App Icon** - Verify all required sizes in Assets.xcassets
  - 1024x1024 (App Store)
  - All iOS device sizes (20pt - 1024pt)
- ❌ **Launch Screen** - Verify configured properly
- ❌ **Video Assets** - Verify 13 yeti videos are bundled correctly (~file size check)

#### App Store Connect
- ❌ **App Store Listing** - Create app in App Store Connect
- ❌ **Screenshots** - 6.7", 6.5", 5.5" iPhone screenshots (required)
- ❌ **App Preview Videos** (optional but recommended)
- ❌ **Description** - Marketing copy
- ❌ **Keywords** - SEO optimization
- ❌ **Support URL** - Must provide
- ❌ **Privacy Policy URL** - Must provide (required for location access)
- ❌ **Copyright** - Set copyright notice

#### Testing
- ❌ **TestFlight Beta** - Upload build and test with external users
- ❌ **App Review Information** - Prepare notes for reviewers about GPS usage
- ❌ **Demo Account** (if needed) - Not required for this app

---

### Android

#### Code Signing & Build
- ✅ **Release Signing Key** - Create keystore file
  - ✅ Created setup documentation in `android/RELEASE_SIGNING.md`
  - ✅ Updated build.gradle.kts to load keystore.properties
  - ✅ Added keystore files to .gitignore
  - ✅ Keystore created at `android/snowteeth-release.keystore`
  - ✅ keystore.properties file created
- ✅ **Signing Configuration** - Update build.gradle.kts with signing config
- ✅ **ProGuard Rules** - Complete proguard-rules.pro for release builds
  - ✅ Keep Kotlin reflection
  - ✅ Keep serialization classes (LocationData, TrackStats)
  - ✅ Keep native methods
  - ✅ Keep Services and Activities
  - ✅ Keep custom Views
  - ✅ Preserve line numbers for crash reports
- ✅ **Build Variants** - Test release build locally
  - ✅ Release APK built: 249 MB (includes 13 yeti videos)
  - ✅ Signed with release key (verified with apksigner)
  - ✅ ProGuard optimization applied

#### Privacy & Permissions
- ❌ **Data Safety Form** - Fill out in Play Console
  - Location data collection
  - Location data usage
  - Location data sharing (none)
  - Data deletion process

#### Assets & Resources
- ✅ **App Icon** - Verify all density versions (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
- ✅ **Adaptive Icon** - Verify foreground/background layers (ic_launcher_foreground present)
- ✅ **Video Assets** - Verify 30 yeti videos in assets/ (confirmed present)

#### Google Play Console
- ❌ **Play Console Account** - Create app in Play Console
- ❌ **Store Listing**
  - Short description (80 chars)
  - Full description (4000 chars)
  - Feature graphic (1024x500)
  - Screenshots (minimum 2, up to 8 per device type)
  - App icon (512x512)
- ❌ **Content Rating** - Complete questionnaire
- ❌ **Pricing & Distribution** - Select countries
- ❌ **Privacy Policy URL** - Must provide (required for location access)
- ❌ **Target Audience** - Declare age groups
- ❌ **App Category** - Select appropriate category (Health & Fitness or Sports)

#### Testing
- ❌ **Internal Testing** - Upload to internal testing track
- ❌ **Closed Testing** - Test with small group
- ❌ **Pre-launch Report** - Review automated test results from Play Console

---

## Both Platforms

### Legal & Documentation
- ✅ **Privacy Policy** - Create comprehensive privacy policy
  - ✅ Location data collection and usage
  - ✅ GPX file storage and export
  - ✅ No third-party sharing
  - ✅ Data deletion process
  - ❌ **TODO: Host on public URL** (document created, needs hosting)
  - ❌ **TODO: Add contact email and website** (placeholders in document)
- ❌ **Terms of Service** (optional but recommended)
- ❌ **Support Email** - Set up support contact
- ❌ **Website/Landing Page** (optional but recommended)

### Marketing Materials
- ❌ **App Description** - Write compelling copy
  - Features list
  - Use cases (skiing, snowboarding, hiking)
  - Privacy-first messaging (no cloud, local storage)
- ❌ **Screenshots** - Capture on multiple devices
  - Home screen
  - Configuration view
  - Flame visualization
  - Data visualization
  - Yeti visualization
  - Stats view with data
- ❌ **App Store Keywords** - Research and optimize
  - skiing, snowboarding, GPS tracker, snow sports, etc.

### Final Testing
- ❌ **Full Feature Test** - Test all features on physical devices
- ❌ **Location Accuracy** - Real-world GPS testing
- ❌ **Battery Usage** - Monitor battery drain during tracking
- ❌ **Memory Usage** - Check for leaks
- ❌ **Crash Testing** - Test error conditions
- ❌ **Permissions Flow** - Test first-time user experience
- ❌ **Background Tracking** - Verify works when app backgrounded
- ❌ **Video Playback** - Ensure all 13 yeti videos play correctly
- ❌ **Unit Conversion** - Test metric/imperial switching
- ❌ **GPX Export** - Verify GPX files are valid

---

## Recommended (Not Critical)

### Monitoring & Analytics
- ⏸️ **Crash Reporting** - Firebase Crashlytics or similar (optional)
- ⏸️ **Analytics** - Only if you want usage data (optional)
- ⏸️ **Performance Monitoring** - Track app performance (optional)

### Optimization
- ❌ **App Size Analysis** - Check total size (13 videos may be large)
  - Consider video compression
  - Check for unused assets
  - Enable Android App Bundle (AAB) for dynamic delivery
- ❌ **Battery Optimization** - Review location update frequency
- ❌ **Memory Optimization** - Profile memory usage with video playback

### App Store Optimization (ASO)
- ⏸️ **A/B Testing** - Test different screenshots/descriptions (post-launch)
- ⏸️ **Localization** - Support multiple languages (post-launch)
- ⏸️ **App Preview Videos** - Create demo videos (optional)

### Post-Launch
- ⏸️ **User Feedback** - Monitor reviews and respond
- ⏸️ **Bug Fixes** - Address issues from real users
- ⏸️ **Feature Updates** - Plan v0.2 features
- ⏸️ **Beta Program** - Maintain ongoing TestFlight/Internal Testing

---

## Version Tracking

Current Version: **0.1**
- Android: `versionCode = 1`, `versionName = "0.1"`
- iOS: `MARKETING_VERSION = 0.1`
- Shared: v0.4.0 (algorithms/specs)

Target Release Version: **0.1** (initial public release)

---

## Notes

- App is privacy-focused: all data stored locally, no cloud sync, no third-party sharing
- GPX export allows users to own their data
- Location permission is essential for core functionality
- Consider video file size impact on app size (13 videos @ ~1-2MB each = 13-26MB)
- Both platforms should release simultaneously for consistent user experience

---

## Quick Start Priorities

1. Privacy Manifest (iOS) - enables compliance
2. Privacy Policy (both) - required for store listings
3. Signing Configuration (both) - enables release builds
4. App Icons (both) - visual identity
5. Store Listings (both) - prepare metadata while builds are ready
