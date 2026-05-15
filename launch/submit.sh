#!/usr/bin/env bash
#
# Phantom — App Store submission script.
#
# Usage:
#   ./launch/submit.sh
#
# Prereqs (do once):
#   1. Apple Developer Program enrollment complete.
#   2. App Store Connect API key created:
#        https://appstoreconnect.apple.com → Users and Access → Integrations
#        → App Store Connect API → Generate Key with role "App Manager"
#      Save the .p8 file. Note the Key ID + Issuer ID.
#   3. Export the 3 values below into your shell (~/.zshrc) or pass inline:
#        export ASC_KEY_ID="ABCDE12345"
#        export ASC_ISSUER_ID="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
#        export ASC_KEY_PATH="/path/to/AuthKey_ABCDE12345.p8"
#   4. Xcode → Phantom target → Signing & Capabilities → Team selected.
#
# What this script does:
#   1. Increments CURRENT_PROJECT_VERSION (build number) by 1
#   2. Archives Release build for generic iOS device
#   3. Exports a signed App Store .ipa
#   4. Validates the .ipa with App Store Connect
#   5. Uploads the .ipa to App Store Connect
#
# After upload completes:
#   - Build appears in App Store Connect → TestFlight (10-30 min processing)
#   - Add to a TestFlight group, or directly Submit for Review

set -euo pipefail

PROJECT="ios-native/Phantom.xcodeproj"
SCHEME="Phantom"
ARCHIVE="build/Phantom.xcarchive"
EXPORT_DIR="build/export"
EXPORT_OPTIONS="launch/exportOptions.plist"

cd "$(dirname "$0")/.."

# --- Bump build number ---
INFO_PLIST="ios-native/Phantom/Info.plist"
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "0")
NEXT_BUILD=$((CURRENT_BUILD + 1))
echo "→ Bumping build $CURRENT_BUILD → $NEXT_BUILD"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT_BUILD" "$INFO_PLIST" || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $NEXT_BUILD" "$INFO_PLIST"

# --- Clean previous build artifacts ---
rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p build

# --- Archive (Release) ---
echo "→ Archiving Release build…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  archive

# --- Export signed .ipa ---
echo "→ Exporting signed .ipa…"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

IPA="$EXPORT_DIR/Phantom.ipa"
ls -la "$IPA"

# --- Validate before upload ---
echo "→ Validating with App Store Connect…"
xcrun altool --validate-app \
  -f "$IPA" \
  -t ios \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID"

# --- Upload ---
echo "→ Uploading to App Store Connect…"
xcrun altool --upload-app \
  -f "$IPA" \
  -t ios \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID"

echo ""
echo "✅ Upload complete. The build will appear in App Store Connect → TestFlight in 10-30 minutes."
echo "   Next:"
echo "   - https://appstoreconnect.apple.com/apps → Phantom → TestFlight tab"
echo "   - Submit for review once the build is processed."
