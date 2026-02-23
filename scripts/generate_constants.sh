#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT_DIR/SportBoardApp/Utilities/Constants.example.swift"
TARGET="$ROOT_DIR/SportBoardApp/Utilities/Constants.swift"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Template not found: $TEMPLATE" >&2
  exit 1
fi

FORCE="${FORCE:-0}"
if [[ -f "$TARGET" && "$FORCE" != "1" ]]; then
  echo "Constants.swift already exists. Skipping (set FORCE=1 to overwrite)."
  exit 0
fi

cp "$TEMPLATE" "$TARGET"

# Rename template type so app code can compile against `Constants`.
perl -0777 -i -pe 's/enum\s+ConstantsExample\s*\{/enum Constants {/g' "$TARGET"

# Optional env-driven injection (safe defaults keep build working)
CLIENT_ID="${STRAVA_CLIENT_ID:-<SET_ME>}"
CLIENT_SECRET="${STRAVA_CLIENT_SECRET:-<SET_ME>}"
REDIRECT_URI="${STRAVA_REDIRECT_URI:-<SET_ME>}"

perl -i -pe "s#(static let clientId\s*=\s*)\".*?\"#\1\"$CLIENT_ID\"#" "$TARGET"
perl -i -pe "s#(static let clientSecret\s*=\s*)\".*?\"#\1\"$CLIENT_SECRET\"#" "$TARGET"
perl -i -pe "s#(static let redirectUri\s*=\s*)\".*?\"#\1\"$REDIRECT_URI\"#" "$TARGET"

echo "Generated $TARGET"
