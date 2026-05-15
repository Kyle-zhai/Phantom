#!/usr/bin/env bash
# Fetch CC0 brand SVGs from simple-icons.org for every service we track.
# Run once; the resulting SVGs are committed to the repo.
set -euo pipefail

OUT="$(dirname "$0")/../ios-native/SubSpy/Resources/Brands"
mkdir -p "$OUT"

# Map: service id used in app  →  simple-icons slug
# Use only first column; second is the SVG asset name on simple-icons
mapping="
netflix netflix
hulu hulu
spotify spotify
peacock peacock
disney-plus disneyplus
paramount paramountplus
hbo-max max
youtube-premium youtube
youtube-tv youtubetv
apple-tv appletv
apple-music applemusic
tidal tidal
sirius-xm siriusxm
audible audible
amazon-prime amazonprime
walmart-plus walmart
costco costcowholesale
icloud icloud
google-one googleone
dropbox dropbox
adobe-cc adobecreativecloud
adobe-photography adobe
microsoft-365 microsoft365
github github
github-copilot githubcopilot
chatgpt openai
claude anthropic
gemini googlegemini
notion notion
duolingo duolingo
masterclass masterclass
lastpass lastpass
1password 1password
expressvpn expressvpn
nordvpn nordvpn
nyt nytimes
wsj wsj
washington-post washingtonpost
planet-fitness planetfitness
equinox equinox
peloton peloton
headspace headspace
calm calm
noom noom
"

count=0
fails=()
while IFS= read -r line; do
  [ -z "$line" ] && continue
  id=$(echo "$line" | awk '{print $1}')
  slug=$(echo "$line" | awk '{print $2}')
  url="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/${slug}.svg"
  out_path="${OUT}/${id}.svg"
  status=$(curl -sL -o "$out_path" -w "%{http_code}" "$url")
  if [ "$status" = "200" ] && [ -s "$out_path" ]; then
    count=$((count + 1))
  else
    rm -f "$out_path"
    fails+=("$id ($slug) → HTTP $status")
  fi
done <<< "$mapping"

echo "✅ Downloaded $count brand SVGs into $OUT"
if [ ${#fails[@]} -gt 0 ]; then
  echo ""
  echo "❌ Missed (will fall back to letter avatar in app):"
  printf '  - %s\n' "${fails[@]}"
fi
