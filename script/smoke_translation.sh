#!/usr/bin/env bash
set -euo pipefail

RESPONSE="$(curl --fail --silent --show-error --get \
  --data-urlencode "client=gtx" \
  --data-urlencode "sl=auto" \
  --data-urlencode "tl=zh-CN" \
  --data-urlencode "dt=t" \
  --data-urlencode "q=Good morning" \
  "https://translate.googleapis.com/translate_a/single")"

TRANSLATION="$(jq -er '.[0] | map(.[0]) | add | select(type == "string" and length > 0)' <<<"$RESPONSE")"
printf 'Live translation smoke test passed: %s\n' "$TRANSLATION"
