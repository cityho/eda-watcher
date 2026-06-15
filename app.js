// eda-watcher frontend: poll manifest, render entry list / code sub-tabs / images.

const POLL_MS = 3000;
const fileURL = (p) => `/api/file?path=${encodeURIComponent(p)}`;
const basename = (p) => p.split("/").pop();

let entries = [];
let selectedId = null;
let activeScript = null; // abs path of active code sub-tab

const $list = document.getElementById("entry-list");
const $tabs = document.getElementById("tabs");
const $code = document.getElementById("code-wrap");
const $right = document.getElementById("right");
const $banner = document.getElementById("banner");
const $status = document.getElementById("status-text");

function showBanner(msg) {
  $banner.textContent = msg;
  $banner.classList.add("show");
}
function hideBanner() {
  $banner.classList.remove("show");
}

async function poll() {
  try {
    const res = await fetch("/api/manifest", { cache: "no-store" });
    if (!res.ok) {
      showBanner(`manifest error (${res.status}): ${await res.text()}`);
      $status.textContent = "error";
      return;
    }
    hideBanner();
    $status.textContent = "live";
    const next = await res.json();
    if (JSON.stringify(next) !== JSON.stringify(entries)) {
      entries = next;
      renderList();
      // keep selection if still present, else select newest
      if (!entries.find((e) => e.id === selectedId)) {
        selectedId = entries.length ? entries[0].id : null;
        activeScript = null;
      }
      renderSelected();
    }
  } catch (e) {
    showBanner(`connection lost: ${e.message}`);
    $status.textContent = "offline";
  }
}

function renderList() {
  if (!entries.length) {
    $list.innerHTML = '<div class="empty">no entries yet</div>';
    return;
  }
  $list.innerHTML = "";
  for (const e of entries) {
    const div = document.createElement("div");
    div.className = "entry" + (e.id === selectedId ? " active" : "");
    const created = (e.created || "").replace("T", " ").slice(0, 19);
    div.innerHTML = `
      <button class="del" title="Remove from board">×</button>
      <div class="title"></div>
      <div class="meta"></div>
      ${e.note ? '<div class="note"></div>' : ""}`;
    div.querySelector(".title").textContent = e.title || e.id;
    div.querySelector(".meta").textContent =
      `${created} · ${(e.scripts || []).length} script · ${(e.images || []).length} img`;
    if (e.note) div.querySelector(".note").textContent = e.note;
    div.onclick = () => {
      selectedId = e.id;
      activeScript = null;
      renderList();
      renderSelected();
    };
    div.querySelector(".del").onclick = (ev) => {
      ev.stopPropagation();
      deleteEntry(e);
    };
    $list.appendChild(div);
  }
}

async function deleteEntry(e) {
  if (!confirm(`Remove "${e.title || e.id}" from the board?\n(manifest only — your files are NOT deleted)`)) {
    return;
  }
  try {
    const res = await fetch("/api/delete", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: e.id }),
    });
    if (!res.ok) {
      toast(`Delete failed (${res.status}): ${await res.text()}`, true);
      return;
    }
    // optimistic local update; next poll confirms
    entries = entries.filter((x) => x.id !== e.id);
    if (selectedId === e.id) {
      selectedId = entries.length ? entries[0].id : null;
      activeScript = null;
    }
    renderList();
    renderSelected();
    toast(`Removed "${e.title || e.id}" (files kept on disk)`);
  } catch (err) {
    toast(`Delete error: ${err.message}`, true);
  }
}

let toastTimer = null;
function toast(msg, isError) {
  const el = document.getElementById("toast");
  el.textContent = msg;
  el.className = "toast show" + (isError ? " error" : "");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("show"), 3500);
}

function renderSelected() {
  const entry = entries.find((e) => e.id === selectedId);
  if (!entry) {
    $tabs.innerHTML = "";
    $code.innerHTML = '<div class="empty">select an entry</div>';
    $right.innerHTML = '<div class="empty">select an entry</div>';
    return;
  }
  renderTabs(entry);
  renderImages(entry);
}

function renderTabs(entry) {
  const scripts = entry.scripts || [];
  $tabs.innerHTML = "";
  if (!scripts.length) {
    $code.innerHTML = '<div class="empty">no scripts</div>';
    return;
  }
  if (!activeScript || !scripts.includes(activeScript)) {
    activeScript = scripts[0];
  }
  for (const s of scripts) {
    const tab = document.createElement("div");
    tab.className = "tab" + (s === activeScript ? " active" : "");
    tab.textContent = basename(s);
    tab.title = s;
    tab.onclick = () => {
      activeScript = s;
      renderTabs(entry);
    };
    $tabs.appendChild(tab);
  }
  loadCode(activeScript);
}

async function loadCode(path) {
  $code.innerHTML = '<div class="empty">loading…</div>';
  try {
    const res = await fetch(fileURL(path));
    if (!res.ok) {
      $code.innerHTML = `<div class="empty">cannot load (${res.status}): ${await res.text()}</div>`;
      return;
    }
    const text = await res.text();
    const pre = document.createElement("pre");
    const code = document.createElement("code");
    code.className = "language-python";
    code.textContent = text;
    pre.appendChild(code);
    $code.innerHTML = "";
    $code.appendChild(pre);
    if (window.hljs) hljs.highlightElement(code);
  } catch (e) {
    $code.innerHTML = `<div class="empty">error: ${e.message}</div>`;
  }
}

function renderImages(entry) {
  const images = entry.images || [];
  if (!images.length) {
    $right.innerHTML = '<div class="empty">no images</div>';
    return;
  }
  $right.innerHTML = "";
  for (const img of images) {
    const card = document.createElement("div");
    card.className = "img-card";
    const name = document.createElement("div");
    name.className = "img-name";
    name.textContent = basename(img);
    name.title = img;
    const el = document.createElement("img");
    el.src = fileURL(img);
    el.onclick = () => window.open(fileURL(img), "_blank");
    el.onerror = () => {
      el.replaceWith(
        Object.assign(document.createElement("div"), {
          className: "img-missing",
          textContent: "file not found on disk",
        })
      );
    };
    card.appendChild(name);
    card.appendChild(el);
    $right.appendChild(card);
  }
}

poll();
setInterval(poll, POLL_MS);
