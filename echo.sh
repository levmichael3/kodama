#!/usr/bin/env bash
# kodama echo — a quiet forest spirit for your repo.
# Cuts through repository noise, echoes back actionable signals.
#
# Outputs a BLUF-first, zero-bloat signal summary to $GITHUB_OUTPUT (as `echo`)
# and to $GITHUB_STEP_SUMMARY when available. Facts survive verbatim; no AI
# calls, no network, no secrets required.
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

if [[ -n "$RANGE" ]] && git rev-parse --verify "$BASE_SHA" >/dev/null 2>&1; then
  FILES=$(git diff --name-only "$RANGE" 2>/dev/null | head -n "$MAX_FILES" || true)
  STAT=$(git diff --stat "$RANGE" 2>/dev/null | tail -n 5 || true)
else
  FILES=$(git diff --name-only HEAD 2>/dev/null | head -n "$MAX_FILES" || true)
  STAT=$(git diff --stat HEAD 2>/dev/null | tail -n 5 || true)
fi

COMMITS=""
if [[ -n "$RANGE" ]] && git rev-parse --verify "$BASE_SHA" >/dev/null 2>&1; then
  COMMITS=$(git log --oneline "$RANGE" 2>/dev/null | head -n 10 || true)
fi

# --- compose echo -------------------------------------------------------------
ECHO_FILE="$(mktemp)"
{
  echo "## 🌳 kodama echo — $MODE"
  echo ""
  case "$MODE" in
    review)
      echo "**Bottom line up front:** review the changed files below; facts (paths, flags, thresholds) are quoted verbatim from the diff."
      ;;
    calm)
      echo "**Breathe.** One thing at a time. The forest keeps what matters; the rest is leaves."
      echo ""
      echo "Pick the smallest next step from the signal below and do only that."
      ;;
    summary | *)
      echo "**Bottom line up front:** actionable signals from this change, noise removed."
      ;;
  esac
  echo ""
  if [[ -n "$COMMITS" ]]; then
    echo "### Commits"
    echo ""
    echo '```text'
    echo "$COMMITS"
    echo '```'
    echo ""
  fi
  if [[ -n "$FILES" ]]; then
    echo "### Changed files (max $MAX_FILES)"
    echo ""
    echo "$FILES" | sed 's/^/- `/' | sed 's/$/`/'
    echo ""
  else
    echo "_No file changes detected in range — nothing to echo back._"
    echo ""
  fi
  if [[ -n "$STAT" ]]; then
    echo "### Diff stat"
    echo ""
    echo '```text'
    echo "$STAT"
    echo '```'
    echo ""
  fi
  if [[ -n "$CONTEXT" ]]; then
    echo "### Given context (verbatim)"
    echo ""
    echo "$CONTEXT"
    echo ""
  fi
  echo "---"
  echo "_kodama (木霊) — the echo that answers back from the forest._"
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
