#!/usr/bin/env bash
# wire-netlify.sh — one-time wiring of MCERQUA/uni-foam -> Netlify site uni-foam
# (id 225d6965-febf-46d7-b281-ac47955ff02a), per the fleet deploy-key REST pattern
# (see scripts/josh-site-deploy/provision-insurance-batch-*-netlify-*.sh).
# Idempotent: skips anything that already exists.
# Usage: bash scripts/wire-netlify.sh
set -euo pipefail
[ -n "$BASH_VERSION" ] || { echo "must run under bash" >&2; exit 3; }

SITE_ID="225d6965-febf-46d7-b281-ac47955ff02a"
REPO="MCERQUA/uni-foam"
TOKEN=$(python3 -c "
import json
d=json.load(open('/mnt/clients/hrsf/vault/credentials.json'))
print(d['credentials']['netlify_uni_foam_deploy']['value'])" 2>/dev/null) || TOKEN=""
[ -n "$TOKEN" ] || { echo "no deploy token in vault"; exit 2; }

nf(){ curl -s -H "Authorization: Bearer $TOKEN" "https://api.netlify.com/api/v1/$1"; }
nfm(){ curl -s -X "$1" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    "https://api.netlify.com/api/v1/$2" ${3:+-d "$3"}; }

# --- 0. current repo link ---
LINKED=$(nf "sites/$SITE_ID" | python3 -c "
import json,sys
d=json.load(sys.stdin)
r=d.get('repo') or {}
print(r.get('repo') or '')")

if [ -n "$LINKED" ]; then
  echo "repo already linked: $LINKED"
else
  echo "creating deploy key..."
  dk=$(nfm POST "deploy_keys" '{}')
  dkid=$(echo "$dk" | python3 -c "import json,sys;print(json.load(sys.stdin).get('id',''))")
  dkpub=$(echo "$dk" | python3 -c "import json,sys;print(json.load(sys.stdin).get('public_key',''))")
  [ -n "$dkid" ] || { echo "deploy_key FAILED: $(echo "$dk"|head -c 150)"; exit 1; }
  echo "$dkpub" > /tmp/nf-uni-foam.pub
  gh repo deploy-key add /tmp/nf-uni-foam.pub -R "$REPO" --title "netlify-cd-uni-foam" 2>&1 | tail -1

  echo "linking repo to site..."
  payload=$(python3 -c "
import json
print(json.dumps({'repo':{'provider':'github','repo':'$REPO','private_repo':False,
  'repo_branch':'main','branch':'main','deploy_key_id':'$dkid','allowed_branches':['main']}}))")
  resp=$(nfm PUT "sites/$SITE_ID" "$payload")
  echo "$resp" | python3 -c "
import json,sys
d=json.load(sys.stdin)
r=d.get('repo') or {}
print('linked:', r.get('repo'), 'branch:', r.get('branch')) if r.get('repo') else print('LINK FAILED:', json.dumps(d)[:300])"
fi

# --- 1. ignore_html_forms must be false (lead killer) ---
ihf=$(nf "sites/$SITE_ID" | python3 -c "import json,sys;print((json.load(sys.stdin).get('processing_settings') or {}).get('ignore_html_forms'))")
if [ "$ihf" != "False" ]; then
  nfm PATCH "sites/$SITE_ID" '{"processing_settings":{"html":{"pretty_urls":true},"ignore_html_forms":false}}' >/dev/null
  echo "ignore_html_forms -> false"
else
  echo "ignore_html_forms already false"
fi

# --- 2. build hook ---
bh=$(nf "sites/$SITE_ID/build_hooks" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(next((h['url'] for h in d if h.get('title')=='github-push-autodeploy'),''))")
if [ -z "$bh" ]; then
  bh=$(nfm POST "sites/$SITE_ID/build_hooks" '{"title":"github-push-autodeploy","branch":"main"}' \
    | python3 -c "import json,sys;print(json.load(sys.stdin).get('url',''))")
  echo "build hook created"
else
  echo "build hook exists"
fi
[ -n "$bh" ] || { echo "no build hook"; exit 1; }

# --- 3. GitHub push webhook -> build hook ---
existing=$(gh api "repos/$REPO/hooks" --jq '.[].config.url' 2>/dev/null | grep -c "build_hooks" || true)
if [ "${existing:-0}" -gt 0 ]; then
  echo "github webhook already present"
else
  hookjson=$(python3 -c "
import json
print(json.dumps({'name':'web','active':True,'events':['push'],
  'config':{'url':'$bh','content_type':'json'}}))")
  echo "$hookjson" | gh api -X POST "repos/$REPO/hooks" --input - >/dev/null 2>&1 \
    && echo "github push webhook added" || echo "github webhook add FAILED"
fi

# --- 4. kick first build ---
nfm POST "$bh" '' >/dev/null 2>&1 && echo "build triggered" || echo "build trigger returned"
echo "WIRING DONE"
