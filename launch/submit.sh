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

# --- Preflight: credentials ---
# altool does NOT read $ASC_KEY_PATH. It looks for a file named
# AuthKey_<KeyID>.p8 in ./private_keys, ~/private_keys, ~/.private_keys or
# ~/.appstoreconnect/private_keys — or in $API_PRIVATE_KEYS_DIR. Derive that
# from the key path we already have so the upload step can find the key
# without anyone editing their shell profile.
: "${ASC_KEY_ID:?set ASC_KEY_ID (App Store Connect → Users and Access → Integrations)}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID (the Issuer ID at the top of that same page)}"
: "${ASC_KEY_PATH:?set ASC_KEY_PATH (full path to your AuthKey_<KeyID>.p8)}"
[ -f "$ASC_KEY_PATH" ] || { echo "✗ No key file at $ASC_KEY_PATH"; exit 1; }
EXPECTED_KEY_NAME="AuthKey_${ASC_KEY_ID}.p8"
if [ "$(basename "$ASC_KEY_PATH")" != "$EXPECTED_KEY_NAME" ]; then
  echo "✗ altool requires the key file to be named $EXPECTED_KEY_NAME"
  echo "  Rename it, or point ASC_KEY_PATH at a copy with that name."
  exit 1
fi
export API_PRIVATE_KEYS_DIR="$(cd "$(dirname "$ASC_KEY_PATH")" && pwd)"
echo "→ Using API key $ASC_KEY_ID from $API_PRIVATE_KEYS_DIR"

# --- Bump build number ---
# Build number lives in project.yml's CURRENT_PROJECT_VERSION setting
# (Info.plist references it via $(CURRENT_PROJECT_VERSION) placeholder).
# Reading Info.plist directly returns the literal placeholder, not a
# number — increment in project.yml instead, then regenerate the xcodeproj.
PROJECT_YML="ios-native/project.yml"
CURRENT_BUILD=$(awk -F': *"?' '/CURRENT_PROJECT_VERSION:/ {gsub(/"/,""); print $2; exit}' "$PROJECT_YML")
CURRENT_BUILD=${CURRENT_BUILD:-0}
NEXT_BUILD=$((CURRENT_BUILD + 1))
echo "→ Bumping build $CURRENT_BUILD → $NEXT_BUILD"
# In-place edit: replace `CURRENT_PROJECT_VERSION: "<old>"` with `"<new>"`.
sed -i '' -E "s/CURRENT_PROJECT_VERSION: \"?[0-9]+\"?/CURRENT_PROJECT_VERSION: \"$NEXT_BUILD\"/" "$PROJECT_YML"
echo "→ Regenerating xcodeproj…"
(cd ios-native && xcodegen generate) >/dev/null

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
