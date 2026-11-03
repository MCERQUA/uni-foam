#!/usr/bin/env bash
# check-form.sh — list Netlify form submissions for uni-foam.com (leads).
# Usage: bash scripts/check-form.sh [form-name]
set -euo pipefail
[ -n "$BASH_VERSION" ] || { echo "must run under bash" >&2; exit 3; }
SITE_ID="225d6965-febf-46d7-b281-ac47955ff02a"
FORM="${1:-}"
TOKEN=$(python3 -c "
import json
d=json.load(open('/mnt/clients/hrsf/vault/credentials.json'))
print(d['credentials']['netlify_uni_foam_deploy']['value'])" 2>/dev/null) || TOKEN=""
[ -n "$TOKEN" ] || { echo "no deploy token in vault"; exit 2; }

if [ -z "$FORM" ]; then
  echo "== forms on site:"
  curl -s -H "Authorization: Bearer $TOKEN" \
    "https://api.netlify.com/api/v1/sites/$SITE_ID/forms" \
    | python3 -c "import json,sys;[print(' ',f['name'],'-',f.get('submission_count','?'),'submissions') for f in json.load(sys.stdin)]"
  exit 0
fi
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.netlify.com/api/v1/sites/$SITE_ID/forms/$FORM/submissions" \
  | python3 -c "
import json,sys
for s in json.load(sys.stdin):
    print('---', s.get('created_at','?'))
    for k,v in (s.get('data') or {}).items(): print(f'  {k}: {v}')"
