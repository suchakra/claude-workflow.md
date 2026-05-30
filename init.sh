#!/usr/bin/env bash
# init.sh — wire claude-workflow.md into the current project after adding the submodule.
# Run once from your project root: bash .claude/workflow/init.sh
set -euo pipefail

WORKFLOW=".claude/workflow"

echo "Initializing claude-workflow.md..."

# 1. Symlink agents into .claude/agents/
mkdir -p .claude/agents
for f in "$WORKFLOW/.claude/agents/"*.md; do
  name=$(basename "$f")
  target="../workflow/.claude/agents/$name"
  link=".claude/agents/$name"
  if [ -L "$link" ]; then
    echo "  skip  $link (already linked)"
  else
    ln -sf "$target" "$link"
    echo "  link  $link"
  fi
done

# 2. Add @import to CLAUDE.md
IMPORT="@.claude/workflow/CLAUDE.md"
if [ ! -f CLAUDE.md ]; then
  echo "$IMPORT" > CLAUDE.md
  echo "  create CLAUDE.md"
elif grep -qF "$IMPORT" CLAUDE.md; then
  echo "  skip  CLAUDE.md (import already present)"
else
  { echo "$IMPORT"; echo; cat CLAUDE.md; } > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
  echo "  patch CLAUDE.md (prepended import)"
fi

# 3. Install or warn about settings.json
if [ ! -f .claude/settings.json ]; then
  mkdir -p .claude
  cp "$WORKFLOW/settings-fragment.json" .claude/settings.json
  echo "  create .claude/settings.json"
else
  echo "  warn  .claude/settings.json already exists"
  echo "        Merge the SessionStart hooks from $WORKFLOW/settings-fragment.json manually."
fi

echo ""
echo "Done. Restart Claude Code to load the agents."
echo "To update later: git submodule update --remote .claude/workflow"
