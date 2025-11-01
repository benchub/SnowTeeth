# Android Release Signing Setup

## Step 1: Generate Release Keystore

### Option A: Using Android Studio's bundled JDK (Recommended)

Run this command from the `android/` directory:

```bash
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -genkey -v -keystore snowteeth-release.keystore -alias snowteeth -keyalg RSA -keysize 2048 -validity 10000
```

### Option B: If you have Java installed separately

```bash
keytool -genkey -v -keystore snowteeth-release.keystore -alias snowteeth -keyalg RSA -keysize 2048 -validity 10000
```

You'll be prompted for:
1. **Keystore password** - Choose a strong password (you'll need this to sign future releases)
2. **Key password** - Choose a strong password (can be the same as keystore password)
3. **Name, Organization, City, State, Country** - Your information

**IMPORTANT:**
- Store the keystore file and passwords securely (password manager, encrypted vault, etc.)
- **NEVER commit the keystore to git**
- **NEVER commit the passwords to git**
- If you lose the keystore, you cannot update the app on Play Store (must publish as new app)

## Step 2: Create keystore.properties

Create `android/keystore.properties` with your keystore information:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=snowteeth
storeFile=snowteeth-release.keystore
```

**IMPORTANT:** This file is already in `.gitignore` - do NOT commit it!

## Step 3: Verify .gitignore

Ensure `android/.gitignore` includes:
```
keystore.properties
*.keystore
*.jks
```

## Step 4: Build Release APK/AAB

After completing setup, build a release version:

```bash
cd android
./gradlew assembleRelease    # For APK
./gradlew bundleRelease       # For AAB (Android App Bundle - preferred for Play Store)
```

Output locations:
- APK: `android/app/build/outputs/apk/release/app-release.apk`
- AAB: `android/app/build/outputs/bundle/release/app-release.aab`

## Backup Your Keystore

After creating the keystore:

1. **Make encrypted backups** in multiple secure locations
2. **Document the passwords** in a secure password manager
3. Consider uploading to Play Store's App Signing service (Google manages the key)

## Google Play App Signing (Recommended)

For additional security, enroll in Google Play App Signing:
- Google stores your release key securely
- You upload an "upload key" instead
- If you lose your upload key, Google can reset it
- Your release key remains safe with Google

See: https://support.google.com/googleplay/android-developer/answer/9842756
