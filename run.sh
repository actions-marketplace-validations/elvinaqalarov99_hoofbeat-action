#!/usr/bin/env bash
# Start a Hoofbeat run, wait for it, exit 1 when it failed. Needs curl and jq (on all GitHub runners).
set -euo pipefail

api() { curl -fsS -H "Authorization: Bearer $HB_TOKEN" -H "Accept: application/json" "$@"; }
base="${HB_URL%/}/api/v1"

body=$(jq -n --arg b "$HB_BASE_URL" --arg e "$HB_ENV" '{} + (if $b != "" then {base_url: $b} else {} end) + (if $e != "" then {environment: $e} else {} end)')
run=$(api -X POST -H "Content-Type: application/json" -H "Idempotency-Key: ${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}-$HB_FLOW" -d "$body" "$base/flows/$HB_FLOW/runs")
id=$(jq -r '.data.id' <<<"$run")
url=$(jq -r '.data.url' <<<"$run")
echo "run-url=$url" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "Hoofbeat run started: $url"

# Cancelling the job stops the run, so no load is left running.
trap 'api -X POST "$base/runs/$id/stop" >/dev/null || true; echo "Run stopped."; exit 130' INT TERM

deadline=$(( $(date +%s) + HB_TIMEOUT * 60 ))
while :; do
  run=$(api "$base/runs/$id")
  [ "$(jq -r '.data.finished' <<<"$run")" = true ] && break
  if [ "$(date +%s)" -ge "$deadline" ]; then
    api -X POST "$base/runs/$id/stop" >/dev/null || true
    echo "::error::Timed out after $HB_TIMEOUT minutes; run stopped. $url"; exit 1
  fi
  sleep 10
done

status=$(jq -r '.data.status' <<<"$run")
passed=$(jq -r '.data.passed // empty' <<<"$run")
echo "passed=$passed" >> "${GITHUB_OUTPUT:-/dev/null}"

{
  echo "### Hoofbeat load test: $status"
  jq -r '.data | "- Requests: \(.summary.requests // "–")  \n- p95: \(.summary.latency.p95 // "–") ms  \n- Capacity: \(.capacity // "–")  \n- [Open the run](\(.url))"' <<<"$run"
  jq -r '.data.checks[]? | "- \(if .passed then "✅" else "❌" end) \(.label) \(.step // ""): \(.actual) \(.unit // "") (limit \(.max))"' <<<"$run"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

if [ "$passed" = false ]; then echo "::error::Load test failed its criteria: $url"; exit 1; fi
if [ "$status" != finished ]; then echo "::error::Run ended as $status: $(jq -r '.data.error // ""' <<<"$run") $url"; exit 1; fi
echo "Load test passed: $url"
