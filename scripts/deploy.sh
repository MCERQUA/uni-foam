#!/usr/bin/env bash
# deploy.sh — manual zip deploy of uni-foam.com via Netlify API.
# Fallback for when the GitHub->Netlify push webhook misses (known fleet issue).
# Usage: bash scripts/deploy.sh
set -euo pipefail
[ -n "$BASH_VERSION" ] || { echo "must run under bash" >&2; exit 3; }
cd "$(dirname "$0")/.."

SITE_ID="225d6965-febf-46d7-b281-ac47955ff02a"
TOKEN=$(python3 -c "
import json
d=json.load(open('/mnt/clients/hrsf/vault/credentials.json'))
print(d['credentials']['netlify_uni_foam_deploy']['value'])" 2>/dev/null) || TOKEN=""
[ -n "$TOKEN" ] || { echo "no deploy token in vault"; exit 2; }

ZIP=$(mktemp /tmp/uni-foam-deploy-XXXXXX.zip)
trap 'rm -f "$ZIP"' EXIT
zip -qr "$ZIP" . -x ".git/*" "scripts/*" "*.zip"
echo "zipped $(unzip -l "$ZIP" | tail -1 | awk '{print $2}') files"

RESP=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/zip" \
  --data-binary "@$ZIP" \
  "https://api.netlify.com/api/v1/sites/$SITE_ID/deploys")
DID=$(echo "$RESP" | python3 -c "import json,sys;print(json.load(sys.stdin).get('id',''))")
[ -n "$DID" ] || { echo "deploy FAILED: $(echo "$RESP" | head -c 300)"; exit 1; }
echo "deploy $DID submitted — polling"
for i in $(seq 1 40); do
  sleep 6
  STATE=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "https://api.netlify.com/api/v1/deploys/$DID" \
    | python3 -c "import json,sys;print(json.load(sys.stdin).get('state',''))")
  echo "  [$((i*6))s] $STATE"
  [ "$STATE" = "ready" ] && { echo "LIVE ✓"; exit 0; }
  [ "$STATE" = "error" ] && { echo "deploy ERROR"; exit 1; }
done
echo "timed out (last: $STATE)"; exit 1
