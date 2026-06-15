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

Whenever you generate a research script that produces image(s) — any
plot/chart/figure, not only "important" ones — append an entry to
`~/.claude/eda-watcher/manifest.json` so every visualization shows up on
the local board. Register them all; the user prunes with the `×` button.

- Manifest path: `~/.claude/eda-watcher/manifest.json` (one global file
  shared by every project; create the dir on first write).
- Paths must be **absolute**; `id` should be `{project}-{slug}` to avoid
  collisions across projects.
- Re-appending the same `id` replaces that entry.
- Board server needs only Python 3.7+ stdlib (no pip installs).

Entry fields: `id` (unique slug, prefer `{project}-{slug}`), `title`,
`created` (ISO, board sorts newest-first), `scripts` (abs paths, render as
code sub-tabs), `images` (abs paths), `note` (optional). Append with:

```python
import json, os, datetime
from pathlib import Path

mpath = Path(os.path.expanduser("~/.claude/eda-watcher/manifest.json"))
mpath.parent.mkdir(parents=True, exist_ok=True)
entries = json.loads(mpath.read_text()) if mpath.exists() else []
entries = [e for e in entries if e["id"] != "my-id"]  # idempotent replace
entries.append({
    "id": "my-id",
    "title": "Human readable title",
    "created": datetime.datetime.now().isoformat(timespec="seconds"),
    "scripts": [os.path.abspath("sweep.py")],
    "images": [os.path.abspath("out.png")],
    "note": "",
})
mpath.write_text(json.dumps(entries, indent=2))
```

Full reference: https://github.com/cityho/eda-watcher
EOF
echo "Wrote guide: $GUIDE"

if grep -qF "$IMPORT_LINE" "$CLAUDE_MD"; then
  echo "Import already present in $CLAUDE_MD."
else
  printf '\n%s\n' "$IMPORT_LINE" >> "$CLAUDE_MD"
  echo "Added '$IMPORT_LINE' to $CLAUDE_MD"
fi

echo "Start the board with: python serve.py  (then open http://127.0.0.1:8765)"
