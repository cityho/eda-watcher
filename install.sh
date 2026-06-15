#!/usr/bin/env bash
# Register eda-watcher with Claude Code by appending a usage section to your
# global ~/.claude/CLAUDE.md (loaded into every project's session). Idempotent:
# re-running does nothing if the section is already present.
set -euo pipefail

CLAUDE_MD="${CLAUDE_MD:-$HOME/.claude/CLAUDE.md}"
MARKER="<!-- eda-watcher -->"

mkdir -p "$(dirname "$CLAUDE_MD")"
touch "$CLAUDE_MD"

if grep -qF "$MARKER" "$CLAUDE_MD"; then
  echo "eda-watcher section already present in $CLAUDE_MD — nothing to do."
  exit 0
fi

cat >> "$CLAUDE_MD" <<'EOF'

<!-- eda-watcher -->
## eda-watcher (research plot board)

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
<!-- /eda-watcher -->
EOF

echo "Added eda-watcher section to $CLAUDE_MD"
echo "Start the board with: python serve.py  (then open http://127.0.0.1:8765)"
