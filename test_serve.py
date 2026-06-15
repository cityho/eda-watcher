import json

import pytest

import serve


@pytest.fixture
def manifest(tmp_path, monkeypatch):
    """Point serve.MANIFEST_PATH at a temp file; return a writer callable."""
    path = tmp_path / "manifest.json"
    monkeypatch.setattr(serve, "MANIFEST_PATH", path)

    def write(obj):
        path.write_text(json.dumps(obj))

    write.path = path
    return write


def test_load_manifest_missing_returns_empty(manifest):
    # file not written -> []
    assert serve.load_manifest() == []


def test_load_manifest_sorted_newest_first(manifest):
    manifest([
        {"id": "a", "created": "2026-06-15T09:00:00"},
        {"id": "b", "created": "2026-06-15T11:00:00"},
        {"id": "c", "created": "2026-06-15T10:00:00"},
    ])
    ids = [e["id"] for e in serve.load_manifest()]
    assert ids == ["b", "c", "a"]


def test_load_manifest_malformed_raises(manifest):
    manifest.path.write_text("{not json")
    with pytest.raises(json.JSONDecodeError):
        serve.load_manifest()


def test_allowlisted_paths_collects_scripts_and_images():
    entries = [
        {"id": "x", "scripts": ["/tmp/a.py"], "images": ["/tmp/a.png", "/tmp/b.png"]},
        {"id": "y", "scripts": ["/tmp/c.py"], "images": []},
    ]
    paths = serve.allowlisted_paths(entries)
    assert paths == {"/tmp/a.py", "/tmp/a.png", "/tmp/b.png", "/tmp/c.py"}


def test_allowlisted_paths_expands_user(monkeypatch):
    monkeypatch.setenv("HOME", "/home/u")
    entries = [{"id": "x", "scripts": ["~/r/a.py"], "images": []}]
    assert "/home/u/r/a.py" in serve.allowlisted_paths(entries)


@pytest.mark.parametrize(
    "case, filename, expected",
    [
        ("python", "/x/sweep.py", "text/plain; charset=utf-8"),
        ("png", "/x/a.png", "image/png"),
        ("jpg", "/x/a.jpg", "image/jpeg"),
        ("svg", "/x/a.svg", "image/svg+xml"),
    ],
)
def test_guess_mime(case, filename, expected):
    assert serve.guess_mime(filename) == expected


def test_delete_entry_removes_and_keeps_files(manifest, tmp_path):
    script = tmp_path / "a.py"
    script.write_text("x = 1")
    manifest([
        {"id": "keep", "created": "2026-06-15T09:00:00", "scripts": [str(script)]},
        {"id": "drop", "created": "2026-06-15T10:00:00", "scripts": [str(script)]},
    ])
    assert serve.delete_entry("drop") is True
    remaining = serve.load_manifest()
    assert [e["id"] for e in remaining] == ["keep"]
    # referenced file is NOT deleted
    assert script.exists()


def test_delete_entry_unknown_id_returns_false(manifest):
    manifest([{"id": "a", "created": "2026-06-15T09:00:00"}])
    assert serve.delete_entry("nope") is False
    assert [e["id"] for e in serve.load_manifest()] == ["a"]


def test_delete_entry_missing_manifest_returns_false(manifest):
    assert serve.delete_entry("anything") is False


@pytest.mark.parametrize(
    "case, in_manifest, on_disk, expected_status",
    [
        ("served", True, True, 200),
        ("not_in_manifest", False, True, 403),
        ("missing_on_disk", True, False, 404),
    ],
)
def test_api_file_allowlist(manifest, tmp_path, case, in_manifest, on_disk, expected_status):
    """Drive the allowlist/disk-existence logic the handler uses for /api/file."""
    target = tmp_path / "fig.png"
    if on_disk:
        target.write_bytes(b"\x89PNG")
    abspath = str(target)

    entry_paths = [abspath] if in_manifest else ["/some/other/path.png"]
    manifest([{"id": "e", "created": "2026-06-15T10:00:00", "images": entry_paths}])

    entries = serve.load_manifest()
    allow = serve.allowlisted_paths(entries)

    # replicate handler decision branch
    import os
    if abspath not in allow:
        status = 403
    elif not os.path.isfile(abspath):
        status = 404
    else:
        status = 200
    assert status == expected_status
