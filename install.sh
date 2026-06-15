#!/usr/bin/env bash
# Register eda-watcher with Claude Code. Installs a usage guide at
# ~/.claude/eda-watcher.md and imports it from the global ~/.claude/CLAUDE.md
# (loaded into every project session). Idempotent: re-running is safe.
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
GUIDE="$CLAUDE_DIR/eda-watcher.md"
IMPORT_LINE="@eda-watcher.md"

mkdir -p "$CLAUDE_DIR"
touch "$CLAUDE_MD"

cat > "$GUIDE" <<'EOF'
# eda-watcher (research plot board)

When you generate a research script + image(s) the user should see, append
an entry to `~/.claude/eda-watcher/manifest.json` so it shows up on the
local board. Only do this for artifacts worth showing.

- Manifest path: `~/.claude/eda-watcher/manifest.json` (one global file
  shared by every project; create the dir on first write).
- Paths must be **absolute**; `id` should be `{project}-{slug}` to avoid
  collisions across projects.
- Re-appending the same `id` replaces that entry.
- Board server needs only Python 3.7+ stdlib (no pip installs).
- Entry schema and an append snippet: https://github.com/cityho/eda-watcher
EOF
echo "Wrote guide: $GUIDE"

if grep -qF "$IMPORT_LINE" "$CLAUDE_MD"; then
  echo "Import already present in $CLAUDE_MD."
else
  printf '\n%s\n' "$IMPORT_LINE" >> "$CLAUDE_MD"
  echo "Added '$IMPORT_LINE' to $CLAUDE_MD"
fi

echo "Start the board with: python serve.py  (then open http://127.0.0.1:8765)"
