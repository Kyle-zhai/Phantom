#!/usr/bin/env bash
# Import the Picks public-database schema (record types, indexes, security
# roles) into the CloudKit container, then deploy it to Production.
#
# One-time prerequisite (needs your Apple ID — Claude can't do this part):
#   1. https://icloud.developer.apple.com → your account menu → "Manage Tokens"
#      → "Generate Management Token"  (scope: the Phantom container)
#   2. xcrun cktool save-token --type management      ← paste the token when asked
#
# Then:  ./docs/cloudkit/import-schema.sh            (development)
#        ./docs/cloudkit/import-schema.sh production  (after testing)
set -euo pipefail
TEAM_ID="7N337R6J9M"
CONTAINER="iCloud.com.yinanzhai.phantom"
ENV="${1:-development}"
SCHEMA="$(cd "$(dirname "$0")" && pwd)/phantom-public.ckdb"

echo "→ Validating $SCHEMA against $CONTAINER ($ENV)…"
xcrun cktool validate-schema --team-id "$TEAM_ID" --container-id "$CONTAINER" --environment "$ENV" --file "$SCHEMA"
echo "→ Importing…"
xcrun cktool import-schema --team-id "$TEAM_ID" --container-id "$CONTAINER" --environment "$ENV" --file "$SCHEMA"
echo "✅ Schema imported into $ENV."
if [[ "$ENV" == "development" ]]; then
  echo "   Next: test on a signed build, then run again with 'production'."
  echo "   The PRIVATE database schema (user data) is created by the app itself on first run;"
  echo "   deploy it from CloudKit Console → Schema → Deploy Schema Changes to Production."
fi
