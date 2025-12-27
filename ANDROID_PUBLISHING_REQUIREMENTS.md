# Android App Bundle (AAB) Requirements for Google Play Store

## Required Format
- **Android App Bundle (AAB)** - Google Play requires AAB format (not APK) for all new apps since August 2021
- Build command: `flutter build appbundle --release`

## Critical Requirements

### 1. **Signing**
- ✅ Must be signed with a **release keystore** (NOT debug keys)
- ✅ Must enroll in **Play App Signing** (Google manages your signing key)
- ❌ Debug-signed bundles will be **rejected**

### 2. **Target SDK Level**
- ✅ Must target **Android 14 (API 34)** or higher (as of 2024)
- ✅ By August 2025: Must target **Android 15 (API 35)** or higher
- Check your current target SDK in `android/app/build.gradle.kts`

### 3. **Application ID**
- ❌ Cannot use `com.example.*` - this is reserved for samples
- ✅ Must use your own unique package name (e.g., `com.yourcompany.vending_empire`)
- ⚠️ **Current issue**: Your app uses `com.example.vending_empire` - this needs to be changed!

### 4. **Version Information**
- ✅ `versionCode` (build number) - must increment with each release
- ✅ `versionName` (user-facing version) - e.g., "1.0.0"
- Currently set in `pubspec.yaml`: `version: 1.0.0+1`

### 5. **Size Limits**
- ✅ Base module: Max 200 MB compressed
- ✅ Total download per device: Max 4 GB compressed

### 6. **Permissions**
- ✅ All permissions must be declared in `AndroidManifest.xml`
- ✅ Runtime permissions must be requested at runtime (Android 6.0+)

## Current Issues to Fix

1. **Application ID**: Change from `com.example.vending_empire` to your own unique ID
2. **Signing**: Set up release signing (currently using debug keys)
3. **Target SDK**: Verify it's API 34 or higher

## Build Commands

```bash
# Build release AAB (requires signing setup)
flutter build appbundle --release

# Output location:
# build/app/outputs/bundle/release/app-release.aab
```

## Next Steps

1. Create a release keystore
2. Configure signing in `android/app/build.gradle.kts`
3. Change application ID from `com.example.*` to your unique ID
4. Verify target SDK is API 34+
5. Build and test the AAB
6. Upload to Google Play Console

