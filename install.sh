#!/usr/bin/env bash
# Register eda-watcher with Claude Code. Installs a usage guide at
# ~/.claude/eda-watcher.md and imports it from the global ~/.claude/CLAUDE.md
# (loaded into every project session). Idempotent: re-running is safe.
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
GUIDE="$CLAUDE_DIR/eda-watcher.md"
IMPORT_LINE="@eda-watcher.md"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVE_PY="$REPO_DIR/serve.py"

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

## After registering: make sure the board is showing

The board only displays what a running server reads from the manifest. After
appending an entry, check whether the board is up; if not, start it, then give
the user the link.

```bash
# Board is at 127.0.0.1:8765. If it does not answer, start it in the
# background (stdlib only, no installs), then hand the user the link.
if ! curl -s -o /dev/null http://127.0.0.1:8765/ ; then
  nohup python3 "__SERVE_PY__" >/tmp/eda-watcher.log 2>&1 &
fi
```

Then always tell the user where to look: **http://127.0.0.1:8765**

Full reference: https://github.com/cityho/eda-watcher
EOF
sed -i.bak "s#__SERVE_PY__#$SERVE_PY#g" "$GUIDE" && rm -f "$GUIDE.bak"
echo "Wrote guide: $GUIDE"

if grep -qF "$IMPORT_LINE" "$CLAUDE_MD"; then
  echo "Import already present in $CLAUDE_MD."
else
  printf '\n%s\n' "$IMPORT_LINE" >> "$CLAUDE_MD"
  echo "Added '$IMPORT_LINE' to $CLAUDE_MD"
fi

echo "Start the board with: python serve.py  (then open http://127.0.0.1:8765)"
