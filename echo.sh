#!/usr/bin/env bash
# kodama echo — quiet signal from your repo.
set -euo pipefail

MODE="${KODAMA_MODE:-summary}"
CONTEXT="${KODAMA_CONTEXT:-}"
MAX_FILES="${KODAMA_MAX_FILES:-20}"

# --- gather signal -----------------------------------------------------------
BASE_SHA="${GITHUB_BASE_SHA:-}"
HEAD_SHA="${GITHUB_SHA:-HEAD}"
RANGE=""
if [[ -n "$BASE_SHA" && "$BASE_SHA" != "0000000000000000000000000000000000000000" ]]; then
  RANGE="$BASE_SHA..$HEAD_SHA"
fi

valid_range() {
  [[ -n "$RANGE" ]] && git rev-parse --verify "$BASE_SHA" >/dev/null 2>&1
}

FILES="" TOTAL_FILES=0 SHORTSTAT="" COMMITS=""

if valid_range; then
  FILES=$(git diff --name-only "$RANGE" 2>/dev/null | head -n "$MAX_FILES" || true)
  TOTAL_FILES=$(git diff --name-only "$RANGE" 2>/dev/null | wc -l | tr -d ' ' || echo 0)
  SHORTSTAT=$(git diff --shortstat "$RANGE" 2>/dev/null || true)
  COMMITS=$(git log --oneline "$RANGE" 2>/dev/null | head -n 10 || true)
else
  FILES=$(git diff --name-only HEAD 2>/dev/null | head -n "$MAX_FILES" || true)
  TOTAL_FILES=$(git diff --name-only HEAD 2>/dev/null | wc -l | tr -d ' ' || echo 0)
  SHORTSTAT=$(git diff --shortstat HEAD 2>/dev/null || true)
fi

# --- build compact signal line -----------------------------------------------
N_COMMITS=0
[[ -n "$COMMITS" ]] && N_COMMITS=$(printf '%s' "$COMMITS" | grep -c . || true)

INS=$(printf '%s' "$SHORTSTAT" | grep -oE '[0-9]+ insertion' | grep -oE '^[0-9]+' || true)
DEL=$(printf '%s' "$SHORTSTAT" | grep -oE '[0-9]+ deletion' | grep -oE '^[0-9]+' || true)
INS="${INS:-0}"; DEL="${DEL:-0}"

SIGNAL_PARTS=()
if [[ $N_COMMITS -gt 0 ]]; then
  [[ $N_COMMITS -eq 1 ]] && SIGNAL_PARTS+=("1 commit") || SIGNAL_PARTS+=("$N_COMMITS commits")
fi
if [[ "$TOTAL_FILES" -gt 0 ]]; then
  [[ "$TOTAL_FILES" -eq 1 ]] && SIGNAL_PARTS+=("1 file") || SIGNAL_PARTS+=("$TOTAL_FILES files")
fi
if [[ "$INS" != "0" || "$DEL" != "0" ]]; then
  SIGNAL_PARTS+=("+${INS} −${DEL}")
fi

SIGNAL=""
for part in "${SIGNAL_PARTS[@]}"; do
  [[ -n "$SIGNAL" ]] && SIGNAL="$SIGNAL · $part" || SIGNAL="$part"
done

# --- optional AI insight (requires ANTHROPIC_API_KEY) ------------------------
AI_INSIGHT=""
if [[ -n "${ANTHROPIC_API_KEY:-}" && ( -n "$COMMITS" || -n "$FILES" ) ]]; then
  _kodama_py=$(cat <<'PYEOF'
import json, urllib.request, os, sys

commits = os.environ.get("_KODAMA_COMMITS", "")
files   = os.environ.get("_KODAMA_FILES", "")
stat    = os.environ.get("_KODAMA_STAT", "")

if not commits and not files:
    sys.exit(0)

prompt = (
    "You're a sharp colleague who just reviewed this PR. "
    "Write two sentences max: what changed and why it matters. "
    "Warm and direct — like explaining it over coffee, not writing a changelog. "
    "Use exact file and commit names from the data below. No filler.\n\n"
    "Commits:\n" + commits + "\n\nFiles:\n" + files + "\n\nStat: " + stat
)

req = urllib.request.Request(
    "https://api.anthropic.com/v1/messages",
    data=json.dumps({
        "model": "claude-haiku-4-5",
        "max_tokens": 80,
        "messages": [{"role": "user", "content": prompt}]
    }).encode(),
    headers={
        "x-api-key": os.environ["ANTHROPIC_API_KEY"],
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    },
)
try:
    with urllib.request.urlopen(req, timeout=15) as r:
        print(json.load(r)["content"][0]["text"].strip())
except Exception:
    pass
PYEOF
  )
  AI_INSIGHT=$(_KODAMA_COMMITS="$COMMITS" _KODAMA_FILES="$FILES" _KODAMA_STAT="$SHORTSTAT" \
    python3 -c "$_kodama_py" 2>/dev/null || true)
  unset _kodama_py
fi

# --- compose echo -------------------------------------------------------------
ECHO_FILE="$(mktemp)"
{
  echo "## 🌳 kodama echo"
  echo ""
  [[ -n "$SIGNAL" ]] && { echo "_${SIGNAL}_"; echo ""; }
  [[ -n "$AI_INSIGHT" ]] && { echo "$AI_INSIGHT"; echo ""; }
  case "$MODE" in
    review)
      echo "_Here's what changed — facts quoted verbatim from the diff._"
      echo ""
      ;;
    calm)
      echo "_One thing at a time. Start with the smallest file below._"
      echo ""
      ;;
  esac

  if [[ -n "$COMMITS" ]]; then
    echo "### Commits"
    echo ""
    while IFS= read -r line; do
      sha="${line%% *}"
      msg="${line#* }"
      echo "- \`${sha}\` ${msg}"
    done <<< "$COMMITS"
    echo ""
  fi

  if [[ -n "$FILES" ]]; then
    echo "### Changed files"
    echo ""
    while IFS= read -r f; do
      echo "- \`${f}\`"
    done <<< "$FILES"
    if [[ "$TOTAL_FILES" -gt "$MAX_FILES" ]]; then
      echo "_…and $(( TOTAL_FILES - MAX_FILES )) more (showing ${MAX_FILES})_"
    fi
    echo ""
  else
    echo "_No file changes detected._"
    echo ""
  fi

  if [[ -n "$CONTEXT" ]]; then
    echo "### Context"
    echo ""
    echo "$CONTEXT"
    echo ""
  fi

  echo "---"
  echo "_木霊_"
} >"$ECHO_FILE"

# --- emit ---------------------------------------------------------------------
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "echo<<KODAMA_EOF"
    cat "$ECHO_FILE"
    echo "KODAMA_EOF"
  } >>"$GITHUB_OUTPUT"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  cat "$ECHO_FILE" >>"$GITHUB_STEP_SUMMARY"
else
  cat "$ECHO_FILE"
fi

rm -f "$ECHO_FILE"
