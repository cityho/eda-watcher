# eda-watcher

Local 2-panel research board. View Claude Code session artifacts — the
Python scripts on the left, the images they produced on the right —
without leaving your browser.

- **Read-only.** The server only ever `GET`s. It never writes the manifest
  or touches any artifact file.
- **Zero dependencies.** Python stdlib HTTP server + vanilla HTML/JS.
- **Path-agnostic.** Artifacts can live anywhere (tmp, worktree, repo) —
  they are referenced by absolute path in a manifest.

## Run

```bash
python serve.py                       # http://127.0.0.1:8765
python serve.py --port 9000 --host 0.0.0.0
```

Open the printed URL. The page polls the manifest every 3s, so new entries
appear without reloading.

## Manifest

Single source of truth, written **only by Claude** during research:

```
~/.claude/eda-watcher/manifest.json
```

A JSON array of entries:

```json
[
  {
    "id": "rsi-ma-sweep-4yr",
    "title": "RSI x MA sweep (4yr)",
    "created": "2026-06-15T10:30:00",
    "scripts": ["/abs/path/sweep.py", "/abs/path/helper.py"],
    "images": ["/abs/path/a.png", "/abs/path/b.png"],
    "note": "optional one-liner"
  }
]
```

- `id` — unique slug. Re-appending the same `id` replaces that entry
  (idempotent re-runs).
- `created` — ISO timestamp; the board sorts newest-first by this.
- `scripts` / `images` — **absolute** paths. Multiple scripts render as
  sub-tabs in the code panel.
- Paths must appear here to be servable — the server refuses (`403`) any
  path not in the manifest, so it cannot be used to read arbitrary files.

### For Claude: how to append an entry

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

## Test

```bash
pytest test_serve.py -v
```

## Behavior on missing files

If an artifact path is gone from disk (e.g. a tmp file was auto-cleaned),
the entry stays in the manifest; the board shows a "file not found"
placeholder for that item instead of crashing. Nothing is auto-removed.
