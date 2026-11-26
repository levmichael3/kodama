#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$SCRIPT_DIR/SKILL.md"

if [[ ! -f "$SKILL_SRC" ]]; then
  echo "Error: SKILL.md not found in $SCRIPT_DIR" >&2
  exit 1
fi

install_skill() {
  local target_dir="$1"
  mkdir -p "$target_dir"
  cp "$SKILL_SRC" "$target_dir/SKILL.md"
  echo "Installed skill -> $target_dir/SKILL.md"
}

install_command() {
  local cmd_dir="$1"
  mkdir -p "$cmd_dir"
  cat >"$cmd_dir/echo.md" <<'EOF'
---
description: Call the forest spirits — kodama echoes back the signal, clears the noise, keeps your cognitive load down.
---
The forest is listening. Call on kodama to echo back what was just said — or the text below — in plain, human language. Every command, flag, file path, port, and exit code stays verbatim. The noise falls away. The signal remains. Your mind stays clear.

Read and apply the `kodama` skill in `/echo` translation mode.

$ARGUMENTS
EOF
  echo "Installed slash command -> $cmd_dir/echo.md"
}

installed_any=false

# Claude Code
if [[ -d "$HOME/.claude" ]] || command -v claude >/dev/null 2>&1; then
  install_skill "$HOME/.claude/skills/kodama"
  install_command "$HOME/.claude/commands"
  installed_any=true
fi

# Cursor
if [[ -d "$HOME/.cursor" ]] || command -v cursor >/dev/null 2>&1; then
  install_skill "$HOME/.cursor/skills/kodama"
  installed_any=true
fi

# OpenCode (note: singular `command`, not `commands`)
if [[ -d "$HOME/.config/opencode" ]] || command -v opencode >/dev/null 2>&1; then
  install_skill "$HOME/.config/opencode/skills/kodama"
  install_command "$HOME/.config/opencode/command"
  installed_any=true
fi

# OpenAI Codex
if [[ -d "$HOME/.codex" ]] || command -v codex >/dev/null 2>&1; then
  install_skill "$HOME/.codex/skills/kodama"
  installed_any=true
fi

# Hermes Agent
if [[ -d "$HOME/.hermes" ]]; then
  install_skill "$HOME/.hermes/skills/kodama"
  installed_any=true
fi

if [[ "$installed_any" == false ]]; then
  echo "No supported agent directories found. Installed nothing." >&2
  echo "Supported: Claude Code (~/.claude), Cursor (~/.cursor), OpenCode (~/.config/opencode), Codex (~/.codex), Hermes (~/.hermes)" >&2
  exit 1
fi

echo "Done. Restart your agent session and use /echo anytime."
