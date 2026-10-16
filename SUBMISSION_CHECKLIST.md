# SUBMISSION CHECKLIST — Hue Massacre

Everything still to do **after** the build, in order. Tick them off top to bottom.

The game code is finished and tested. Everything below is packaging.

---

## Phase 0 — Final build check (15 min)

- [ ] Open the project in Godot 4.7 and press **F5**. It should play start to finish.
- [ ] Run the automated suite and confirm it is still green:
      `.. --headless --path . res://tests/test_runner.tscn` → `179 passed, 0 failed`
      (full command in [HOW_TO_RUN.md §4](HOW_TO_RUN.md))
- [ ] Play one complete run: start menu → story → 4 rooms → win screen. Time it.
- [ ] Walk through the manual checklist in [TESTING.md §4](TESTING.md), especially
      the **visual** items (the automated tests cannot see the screen).
- [ ] Fix anything the by-eye pass turns up. Re-run the suite after any change.

---

## Phase 1 — Public GitHub repo (20 min)

- [ ] Create a **public** repo (e.g. `hue-massacre`). Public is a stated requirement.
- [ ] Push the project. `build/` and `.godot/` are already in `.gitignore`, so the
      repo stays source-only and small — verify with `git status` that neither is staged.
- [ ] Check the rendered README on GitHub: tables, headings and code blocks should all display.
- [ ] Confirm no secrets or personal files slipped in.
- [ ] Add a **LICENSE** file if you want one (MIT is fine, and it is a nice touch).

```bash
git init
git add .
git commit -m "Hue Massacre: a colour-theory stealth game in Godot 4"
git branch -M main
git remote add origin https://github.com/<you>/hue-massacre.git
git push -u origin main
```

---

## Phase 2 — AI chat history PDF (30–45 min)

This is a graded deliverable and it is easy to get wrong. Requirements: **one PDF**,
**selectable text** (not screenshots), containing **all** your AI chats, including
**this agent session** and your **Claude** chat.

- [ ] Export this coding-agent session from start to finish.
- [ ] Export your Claude chat(s).
- [ ] Merge them into a **single** PDF, in a sensible order.
- [ ] **Check the text is selectable:** open the PDF and try to highlight a sentence
      and copy it. If you cannot, the PDF is images and it will lose marks — re-export
      as text, do not screenshot.
- [ ] Add a short contents page listing which chat is which.
- [ ] Name it `AI_CHAT_HISTORY.pdf` and put it in `docs/`.
- [ ] Link it from the README (replace the placeholder in the *Play it* table).

---

## Phase 3 — Web build and hosting (30 min)

- [ ] Install the export templates (**Editor → Manage Export Templates → Download**).
      This is a one-time ~1.3 GB download.
- [ ] **Project → Export → Web → Export Project** to `build/web/index.html`.
      The Web preset is already configured in `export_presets.cfg`.
- [ ] Test locally over HTTP (`python3 -m http.server 8000` inside `build/web`,
      then open <http://localhost:8000>). It will **not** work by double-clicking
      the HTML file.
- [ ] Upload to itch.io or GitHub Pages. Zip the **contents** of `build/web/`
      so `index.html` is at the zip root.
- [ ] Play the hosted build for real, in a browser, to the win screen.
- [ ] Paste the playable link into the README (replace the placeholder).

---

## Phase 4 — The video (2–4 hours of work; must be 20+ minutes) ⭐

**The requirement: a single public YouTube video, 20 minutes minimum.**
It must be public, not unlisted. Everything else can be fixed later; this is the
one item that is genuinely hard to rush.

### Before you record

- [ ] Write the talking points below onto a second monitor or a notes window.
- [ ] Set the game to **windowed 1280×720**, not fullscreen — you want the source visible.
- [ ] Close notifications. Check your mic level.
- [ ] Do one silent 60-second test recording and play it back. Confirm you can be
      heard clearly and the game audio is not drowning you.
- [ ] Record **in several files**, not one 25-minute take. If you fluff a section
      you re-record that section, not the whole thing.

### Suggested outline (adjust to your own words)

The fastest way to fill 20 minutes honestly is to **explain the code**, not to
narrate gameplay. Gameplay-only narration will run out at about 6 minutes.

| # | Segment | ~Time | What to cover |
|---|---|---|---|
| 1 | **Intro and pitch** | 2 min | Who you are, the assignment, and the one-line pitch: colour is the weapon, the camouflage and the score. |
| 2 | **Story and intro cards** | 1.5 min | Play the title and the 5 cards. Point out the coloured last words. |
| 3 | **Controls and the core loop** | 2 min | Play Room 1 live. Move, lunge, kill, absorb, hide. Explain one-hit kills both ways. |
| 4 | **Colour theory: hue and contrast** | 3 min | Open `scripts/color_theory.gd`. Explain hue as an angle, why hues wrap at 360°, and `hue_gap` taking the shortest arc. Show the 26° hiding tolerance. |
| 5 | **Colour theory: complements** | 3 min | The six hues and their exact degrees. The complement pairs, and why **Orange↔Blue at 150° deliberately fails** the 180°±25° test. This is the best bit — the wheel is measured, not vibed. |
| 6 | **Colour theory: mixing** | 2 min | Open Room 2. Why blending goes the **shortest way around the wheel**, and why naive RGB mixing turns red+blue into a muddy yellow instead of violet. |
| 7 | **The combo system** | 2.5 min | `game.gd`. The 3-second window, the multiplier, and the bug you found where the window was already zeroed. |
| 8 | **Levels as data** | 2 min | `level_data.gd`. Rooms are dictionaries, not scene files. Show how to add a guard. |
| 9 | **The boss** | 2.5 min | The rotating hue, the ~13s lap, the 1.8s window, and the design rule that keeps it from soft-locking. |
| 10 | **Testing** | 3 min | Run the suite live and let it scroll. Explain that the headless engine **cannot see `_draw()`**, so the visuals were checked by eye. Explain the vacuous-pass bug. |
| 11 | **Web export** | 2 min | The preset, why the build is single-threaded (COOP/COEP headers), and why audio needs a click. |
| 12 | **Wrap-up** | 2 min | What you would add next, what you learned, honest limitations. |

**Total: ~27 minutes.** Comfortable margin.

- [ ] Record. Aim for 25–30 minutes so trimming cannot drop you under 20.
- [ ] Edit: cut dead air and mistakes. **Re-time the final cut** — if it lands at
      19:58, you need more footage.
- [ ] Upload to YouTube as **Public** (not Unlisted).
- [ ] Set an accurate title and description; mention Godot 4 and the course.
- [ ] Copy the URL and paste it into the README (replace the placeholder).

---

## Phase 5 — Finalise the README (10 min)

- [ ] Replace **all four** placeholders at the top of `README.md`:
      - `[[PASTE ITCH.IO OR GITHUB PAGES LINK HERE]]`
      - `[[PASTE LINK TO AI_CHAT_HISTORY.pdf HERE]]`
      - `[[PASTE YOUTUBE LINK HERE]]`
      - `[[PASTE PUBLIC GITHUB REPO LINK HERE]]`
- [ ] Read the README on the live GitHub page and click every link. All four must resolve.
- [ ] Confirm the **AI usage statement** is present and honest (§9).
- [ ] Confirm the **limitations** section is present (§10).
- [ ] `git add . && git commit -m "Add submission links" && git push`

---

## Phase 6 — Submit on the LMS (10 min)

- [ ] Create `submission.txt` containing **only** the public repo URL.
- [ ] Double-check the repo is **public** in a private/incognito browser window.
      A grader who cannot open it cannot mark it.
- [ ] Double-check the video is **public** and plays without signing in.
- [ ] From that same incognito window, confirm you can reach: the repo, the playable
      build, the PDF, and the video. All four.
- [ ] Upload `submission.txt` to the LMS before the deadline.
- [ ] Submit with time to spare — LMS uploads fail at the worst possible moment.

---

## Grading self-check

Against the stated marking criteria, before you submit:

| Marks | Requirement | Where it is satisfied |
|---|---|---|
| **40** | Colour theory as the **core mechanic** | Hiding is simultaneous contrast; combos are complementary contrast; absorption is additive hue blending; the boss is complementary cancellation. It is not a skin — every rule is hue maths, and **every hue constant is re-derived and verified by the test suite**. |
| **30** | **Originality** | "Colour is both camouflage and weapon" is the whole game; being a visible colour in a grey world *is* the tension. The boss window, the deliberate Orange↔Blue non-combo, and the hide-in-your-own-paint loop are all design choices, not defaults. |
| **15** | **Typography / readable themed UI** | One themed type scale in `ui/ui_style.gd`; a display face and a body face; the combo readout drawn in the **complement of the floor colour**; the last word of each story couplet coloured to match the wheel. |
| **15** | **Complete loop with challenge and win/lose** | Title → 5 cards → 4 rooms → boss → win screen with score, time and rank. Instant restart on death, R to retry, escalating difficulty, and a score multiplier that rewards mastery. |

**Do not submit until the video is public and all four links in the README work.**
Those are the two things that most often cost marks on an otherwise finished project.
