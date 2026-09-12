#!/usr/bin/env bash
# Registers the App ID capabilities Phantom now needs (iCloud/CloudKit +
# container, Sign in with Apple, Push, App Groups) by letting Xcode's automatic
# signing update the App ID and regenerate the team profile.
#
# Needs ONE of:
#   a) Xcode → Settings → Accounts → your Apple ID signed in (then just run this), or
#   b) an App Store Connect API key with Admin role exported as
#        ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH (same variables submit.sh uses).
set -euo pipefail
cd "$(dirname "$0")/../ios-native"
xcodegen generate >/dev/null
ARGS=(-project Phantom.xcodeproj -scheme Phantom -configuration Debug -destination 'generic/platform=iOS' -allowProvisioningUpdates build)
if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
  ARGS+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi
echo "→ Asking Xcode to register capabilities + refresh the provisioning profile…"
xcodebuild "${ARGS[@]}" 2>&1 | grep -E "error:|warning: .*(profile|capab)|BUILD" || true
APP=$(find ~/Library/Developer/Xcode/DerivedData/Phantom-*/Build/Products/Debug-iphoneos -maxdepth 1 -name Phantom.app | head -1)
if [[ -n "$APP" ]] && codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q "CloudKit"; then
  echo "✅ Signed build carries the iCloud entitlement — capabilities are registered."
else
  echo "✗ Not registered yet. If you saw 'No Accounts', sign in to Xcode (Settings → Accounts) or export the ASC_* variables, then re-run."
fi
