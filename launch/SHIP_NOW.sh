#!/usr/bin/env bash
# Phantom — one-button preflight + ship.
#
# Wraps launch/submit.sh with explicit preflight checks so the user gets
# clear errors instead of silent failures. Run from the repo root:
#
#     ./launch/SHIP_NOW.sh
#
# What it does:
#   1. Verify git state is clean (no uncommitted changes).
#   2. Verify Xcode is signed in to an Apple Developer account.
#   3. Verify the 3 ASC env vars are exported.
#   4. Verify the .p8 key file actually exists.
#   5. Verify the legal pages are live.
#   6. Run launch/submit.sh end-to-end (archive → export → validate → upload).
#
# Exits non-zero on any check failure with a precise next step.

set -euo pipefail

cd "$(dirname "$0")/.."

red()    { printf "\033[31m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

bold "Phantom — App Store ship preflight"
echo "===================================="

# 1. Clean git
if [[ -n "$(git status --porcelain)" ]]; then
  red "❌ Uncommitted changes in repo. Commit or stash first:"
  git status --short
  exit 1
fi
green "✅ Git state clean ($(git rev-parse --short HEAD))"

# 2. Xcode signed in
if ! security find-identity -v -p codesigning | grep -q "Apple Distribution\|Apple Development"; then
  red "❌ No code signing identity found in Keychain."
  echo "   Open Xcode → Settings → Accounts → Add your Apple ID."
  echo "   Then run Xcode → Phantom target → Signing & Capabilities → Team."
  exit 1
fi
green "✅ Code signing identity present"

# 3. ASC env vars
missing=()
for v in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
  if [[ -z "${!v:-}" ]]; then missing+=("$v"); fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
  red "❌ Missing ASC env vars: ${missing[*]}"
  echo ""
  echo "   Get them from App Store Connect:"
  echo "   1. https://appstoreconnect.apple.com → Users and Access → Integrations"
  echo "   2. App Store Connect API → Generate Key (role: App Manager)"
  echo "   3. Save the .p8 file. Note the Key ID + Issuer ID."
  echo ""
  echo "   Then add to ~/.zshrc:"
  echo "     export ASC_KEY_ID=\"ABCDE12345\""
  echo "     export ASC_ISSUER_ID=\"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\""
  echo "     export ASC_KEY_PATH=\"\$HOME/.appstoreconnect/AuthKey_ABCDE12345.p8\""
  echo "     source ~/.zshrc"
  echo ""
  echo "   Then re-run:  ./launch/SHIP_NOW.sh"
  exit 1
fi
green "✅ ASC env vars set"

# 4. .p8 key file exists
if [[ ! -f "$ASC_KEY_PATH" ]]; then
  red "❌ ASC_KEY_PATH points to a missing file: $ASC_KEY_PATH"
  exit 1
fi
green "✅ ASC private key found ($ASC_KEY_PATH)"

# 5. Legal pages live
for page in privacy.html terms.html; do
  url="https://kyle-zhai.github.io/Phantom/$page"
  status=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
  if [[ "$status" != "200" ]]; then
    red "❌ Legal page not reachable: $url (HTTP $status)"
    echo "   Verify docs/$page is published to the gh-pages branch."
    exit 1
  fi
done
green "✅ privacy.html + terms.html live at kyle-zhai.github.io/Phantom/"

echo ""
bold "All preflight checks passed."
yellow "About to run: launch/submit.sh"
yellow "This will: bump build number → archive Release → export signed .ipa → validate → upload."
echo ""
read -r -p "Proceed with upload? [y/N] " confirm
if [[ "${confirm:-N}" != "y" && "${confirm:-N}" != "Y" ]]; then
  echo "Aborted. The .ipa was NOT built."
  exit 0
fi

exec ./launch/submit.sh
