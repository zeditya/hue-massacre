# HOW TO RUN — Hue Massacre

Everything you need to open, run, test, and export the game. Written for someone
who has **never used Godot before**, so it is more detailed than usual.

---

## 1. Install Godot

1. Go to <https://godotengine.org/download>.
2. Download **Godot 4.7 — Standard** for your OS.
   - Get the **Standard** build. Do **not** get the **.NET / C#** build — this
     project is pure GDScript and the .NET build is a much larger download.
3. It is a single portable executable. Put it somewhere sensible and run it.
   - **Windows:** `Godot_v4.7-stable_win64.exe`
   - **macOS:** `Godot.app` (if macOS refuses to open it, right-click → Open once)
   - **Linux:** `Godot_v4.7-stable_linux.x86_64` — if it will not run,
     `chmod +x` it first.

You do **not** need to install anything else. No addons, no Python, no SDK.

> **Version note:** the project is configured for 4.7. Godot 4.2+ will also open
> it; if you use an older 4.x, Godot may offer to upgrade `project.godot` — say
> yes, it is a safe change.

---

## 2. Open the project

1. Launch Godot. The **Project Manager** appears.
2. Click **Import**.
3. Click **Browse**, and select the file `project.godot` in this folder.
   - That is the file to pick, **not** a folder and **not** `scenes/main.tscn`.
4. The list will now show *Hue Massacre* with a valid path. Click **Import &
   Edit**.
5. Godot opens the editor and spends a few seconds importing. The first import
   may show a small progress bar — that is normal.

You do not need to configure anything. The main scene, the input map, the window
size and the renderer are all already set in `project.godot`.

---

## 3. Play it

Press **F5** (or the ▶ play button, top-right).

The game opens on a **start menu** — *START GAME / HOW TO PLAY / QUIT* — with a
strip of the whole hue wheel above it. A window opens at 1280×720, resizable.

**Controls**

| Input | Action |
|---|---|
| **W A S D** / **Arrow keys** | Move — this also aims your light cone and your lunge |
| **Space** / **Left click** | Lunge-dash the way you are steering — kills guards on contact |
| **R** | Restart the current room |
| **Esc** | Pause — *Resume / Restart room / Quit to menu* |
| **W / S** on a menu | Move the highlight; **Space / Enter / click** selects |

There is deliberately **no separate mouse aim**: the way you steer is the way you
face, the way you lunge, and the way your light cone points.

**A 30-second first run**, so you can tell it works:

1. Choose **START GAME**. A short story scene plays (the spark alone in the grey
   city), then the five rhyme cards — press **Space** (or click) to move through
   them.
2. In Room 1 you are a white spark on a grey floor with two guards.
3. Walk up behind the **red** guard, point at him with **W A S D**, then tap
   **Space** to lunge into him. He dies and splatters red paint on the floor.
4. Stand in that red paint. **Your own colour is now red** (see the swatch in the
   top-left HUD), so the floor matches you and the remaining guard cannot see you.
5. Walk to the **yellow** guard and kill him to clear the room.

If all five steps happen, the build is good.

> **If you see a black window or a shader warning:** open
> **Project → Project Settings → Rendering → Renderer** and confirm it is
> **Compatibility**. The project already sets this, because the Compatibility
> renderer is the one that works in the web build — using Forward+ locally would
> make the game look different once exported.

---

## 4. Run the automated tests

The project ships with an 187-check test suite. It runs in a headless engine (no
window) and prints a pass/fail line for every check.

**From the editor:** open `tests/test_runner.tscn` in the FileSystem panel and
press **F6** (run the *current* scene). Watch the **Output** panel at the bottom.

**From a terminal** (faster, and this is the recommended way):

```bash
# Linux / macOS
/path/to/Godot_v4.7-stable_linux.x86_64 --headless --path . res://tests/test_runner.tscn

# Windows (PowerShell)
& "C:\path\to\Godot_v4.7-stable_win64.exe" --headless --path . res://tests/test_runner.tscn
```

You should see the checks scroll past and then:

```
=========================================================
RESULT: 187 passed, 0 failed
=========================================================
```

The process exits with code **0** on success and **1** if anything failed, so it
can be wired into CI. See [TESTING.md](TESTING.md) for what each check covers.

> The tests are excluded from the web export (see `exclude_filter` in
> `export_presets.cfg`), so they never ship to players.

---

## 5. Export a Web build

This is the deliverable that goes on itch.io or GitHub Pages.

### 5.1 One-time: install the export templates

Godot cannot export without the matching template pack (a one-time ~1.3 GB
download that is not part of the base engine).

1. In the editor: **Editor → Manage Export Templates…**
2. Click **Download and Install** and let it finish (it is large; go get a coffee).
3. Confirm the version it shows matches your Godot version exactly (e.g.
   `4.7.2.stable`).

### 5.2 Export

1. **Project → Export…**
2. On the left you will already see a preset named **Web** — it is pre-configured
   in `export_presets.cfg`, so you do **not** need to add one.
3. Click **Export Project…**, and save to `build/web/index.html`.
   - Godot fills in the folder: `index.html`, `index.js`, `index.wasm`, `index.pck`,
     and a `.png` icon.
4. That `build/web/` folder is a complete website. Upload the **whole folder**, not
   just `index.html`.

> `build/` is already listed in `.gitignore`, so the export output will not be
> committed. That is intentional — build output does not belong in the repo.

### 5.3 Test it locally (do not skip this)

**You must serve the build over HTTP.** Double-clicking `index.html` will not
work: browsers block WebAssembly and `.pck` files loaded from `file://`.

```bash
cd build/web

# Python 3 (already installed on most machines)
python3 -m http.server 8000
# Windows: py -m http.server 8000

# or Node
npx serve .
```

Then open **<http://localhost:8000>** in a browser.

*(If you have the Godot editor open, you can also just press the **Remote Debug →
Run in Browser** button in the Export dialog, which serves it for you.)*

### 5.4 Known Web limitations — read before you panic

These are properties of the web export, not bugs in the game:

| Limitation | What you will see | Why |
|---|---|---|
| **Audio needs a click** | The start menu's first moment can be silent. Sound works after your first keypress or click. | Browsers block autoplay until the user interacts. This is required behaviour, not a fault. |
| **Single-threaded build** | Slightly lower performance on very weak machines. | The preset sets `thread_support=false`. A threaded build needs the host to send `COOP`/`COEP` security headers, which **GitHub Pages and `python -m http.server` will not do** — so the threaded build would simply hang there. Single-threaded runs anywhere. |
| **No glow in the web build** | Some bloom may be missing. | Glow support is limited in the Compatibility renderer. The game is designed to look good without it. |
| **Slow first load** | A loading bar for a few seconds. | The `.wasm` file is a few megabytes and is not cached on the first visit. |
| **Fullscreen needs a click** | The canvas focuses on click. | Set by `html/focus_canvas_on_start`. |

### 5.5 Hosting

**itch.io** (easiest):

1. Zip the **contents** of `build/web/` — `index.html` must be at the *root* of
   the zip, not inside a folder.
2. On itch.io: **Create new project** → *Kind of project*: **HTML** → upload the
   zip → tick **"This file will be played in the browser"**.
3. Suggested viewport: **1280 × 720**. Then **Save & view page**.

**GitHub Pages (automated — recommended):**

`.github/workflows/deploy-web.yml` builds the Web preset and publishes it to
GitHub Pages on every push to `master`, so there is nothing to export or upload
by hand.

1. **Settings → Pages → Build and deployment → Source: GitHub Actions.** This
   one-time switch is required; without it the deploy step has nothing to
   publish to.
2. Push to `master` (or run the workflow from the **Actions** tab).
3. Wait for the workflow to finish, then open
   `https://<owner>.github.io/<repo>/`.

**GitHub Pages (manual):**

1. Commit `build/web/` to your repo, or push it to a `gh-pages` branch.
2. **Settings → Pages** → Source: your branch, folder `/` (or `/build/web`).
3. Wait a minute, then open the URL it gives you.

Either way, paste the resulting URL into the README's *Play it* table.

---

## 6. Common problems

| Problem | Fix |
|---|---|
| "Cannot export project with preset Web due to configuration errors: No export template found" | You have not installed the export templates (step 5.1), or the template version does not match your Godot version. |
| Editor opens but F5 does nothing | Make sure `scenes/main.tscn` is set as the main scene — it already is in `project.godot` (Project → Project Settings → Application → Run → Main Scene). |
| Text is blurry or the game looks soft | You are probably on the Forward+ renderer. Switch to **Compatibility** (step 3's note). |
| The tests print "0 passed" | You ran `res://scenes/main.tscn` instead of `res://tests/test_runner.tscn`. Check the path at the end of the command. |
| Audio is silent in the web build | Click once on the page. See 5.4. |
| `cURL`/browser shows a CORS or COEP error | You are serving a *threaded* build. This project exports single-threaded, so re-export with the provided preset rather than changing `thread_support`. |

---

## 7. Tweaking the game

Because every number is an `@export` at the top of its script, you can change
almost all of the feel without touching logic. The quick wins:

- **Too hard?** Raise `detect_time` in `scripts/guard.gd` (guards take longer to
  spot you) or raise `hide_tolerance_deg` in `scripts/player.gd` (more colours
  count as hiding you; also mirror it in `scripts/guard.gd` and `scripts/game.gd`).
- **Harder combos?** Lower `complement_tolerance_deg` in `scripts/game.gd` from
  25° — at 10° only the exact Yellow↔Blue pair will work.
- **Boss too fast?** Lower `hue_speed` on the boss entry in
  `scripts/level_data.gd` (28°/s = one lap in ~13s).
- **More paint on the floor?** Raise `blob_lifetime` in `scripts/paint_layer.gd`.
- **Too dark to see?** Lower `darkness_amount` in `scripts/game.gd` (0 = daylight,
  1 = pitch black); widen the beam with `light_cone_deg` / `light_range`, or widen
  the always-lit pool with `light_ambient_range`. Set `darkness_enabled = false`
  to remove the dark entirely.
- **Movement feels loose?** Raise `acceleration` and `friction` in
  `scripts/player.gd` — higher values make the spark answer (and stop on) the keys
  faster.
- **Guards too psychic?** `hear_radius` and `shout_radius` in `scripts/room.gd`
  set how far a lunge or a spot carries to other guards.
- **More or fewer colour motes?** Edit the `"motes"` lists in
  `scripts/level_data.gd`; each entry is just a position and a colour.

Select the node in the running scene tree and the exports appear in the Inspector.

### Adding a pixel font (optional)

The game deliberately uses Godot's built-in font, so there is nothing to download.
If you want a pixel font for the assignment's look:

1. Download a free one (e.g. **Press Start 2P** or **Silkscreen**, both OFL).
2. Drop the `.ttf` into `assets/fonts/` (create the folder).
3. In `ui/ui_style.gd`, load it and assign it to the `Font` values there — the
   whole UI routes through that one file, so it is a single edit.
4. **Credit the font and its license in the README** if its license asks for it.
