#!/usr/bin/env bash
# apply-config.sh — load .env, validate required vars, render template files.
#
# Usage:
#   scripts/apply-config.sh              # uses .env in repo root
#   scripts/apply-config.sh /path/to/.env
#
# Template convention: any file named *.template (e.g. compose/phase1.template.yml)
# is rendered via envsubst into the same directory without the .template suffix
# (e.g. compose/phase1.yml).  Rendered files are gitignored.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${1:-$REPO_ROOT/.env}"

# ── 1. Load .env ─────────────────────────────────────────────────────────────
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: env file not found: $ENV_FILE"
  echo "  Copy .env.example to .env and fill in all values, then re-run."
  exit 1
fi

# Export every non-comment, non-blank line
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# ── 2. Validate required variables ───────────────────────────────────────────
REQUIRED=(
  WA_GATEWAY_NUMBER
  WA_GROUP_ID
  WA_ALLOWED_SENDERS
  DEEPSEEK_API_KEY
  DEEPSEEK_MODEL
  DEEPSEEK_BASE_URL
  HA_URL
  HA_TOKEN
  REPO_URL
  POLL_SECONDS
)

MISSING=()
for var in "${REQUIRED[@]}"; do
  val="${!var:-}"
  if [[ -z "$val" ]]; then
    MISSING+=("$var")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "ERROR: the following required variables are not set in $ENV_FILE:"
  for m in "${MISSING[@]}"; do
    echo "  - $m"
  done
  exit 1
fi

echo "All required variables are set."

# ── 3. Render *.template files via envsubst ───────────────────────────────────
# Find all *.template files anywhere under the repo root.
RENDERED=0
while IFS= read -r -d '' tmpl; do
  # Strip the .template suffix to get the output path
  out="${tmpl%.template}"
  envsubst < "$tmpl" > "$out"
  echo "Rendered: $tmpl -> $out"
  RENDERED=$((RENDERED + 1))
done < <(find "$REPO_ROOT" -name "*.template" -not -path "*/.git/*" -print0)

if [[ $RENDERED -eq 0 ]]; then
  echo "No *.template files found — nothing to render yet."
fi

echo ""
echo "Done. Sensitive values are NOT in the repo."
echo "Run this script again any time you update .env."
