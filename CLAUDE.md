# gClockClock

A ClockClock 24 style clock: 24 small analog clocks (4 digits × 2×3 grid) whose hands
turn to form the time. Plain HTML/CSS/JS, no build, no dependencies.

## Files

- `clock.html` — the whole app (markup, styles, script). Open it in a browser to run.
- `kiosk-setup.sh` — sets up a Raspberry Pi to show the clock full screen (see `docs/deploy.md`).
- `wallpaper/` — Lively Wallpaper package: the clock in a corner of a background image (see Lively).
- `lively-setup.ps1` — installs or updates that package in Lively (see Lively).
- `README.md`, `LICENSE` (MIT, geeForceOne).

## Read before changing

These details are not loaded by default. Read the file first when a task touches its subject:

- `docs/shows.md` — the scenes (Billiard, Saber, Tron, Tron 2, Matrix, Bougainvillea), `settle()`/`landedOn`,
  and the easter eggs (`EGGS`). Read it for any change to a show, an egg, or how hands land after a show.
- `docs/deploy.md` — GitHub Pages, self-update, `kiosk-setup.sh` and Pi notes (performance, rotation,
  slimming). Read it for any change to the `kiosk` section of the script, the setup script, or the Pi.

## Workflow

When the user gives feedback or requests changes in a back-and-forth (bug reports, tweaks, "also do
X"), don't implement each one immediately as it comes in. Acknowledge it, queue it, and keep
gathering. Only start making changes once the user explicitly says "go" (or an equally unambiguous
confirmation). Purely informational questions can still be answered right away.

## Git workflow

Never run `git commit` or `git push` unless the user explicitly asks for it in that turn. A commit
approval does not imply a push approval, and approval from an earlier turn does not carry forward to
later changes. A push to `main` is a deploy: GitHub Pages serves it and the Pi kiosk reloads it
within ~15 minutes.

- Every change starts on its own branch off an up-to-date main; after a merge, pull main, delete
  merged branches (`-d`) and `git fetch --prune`.
- Test before publish: finish the work on the branch, then stop before merging/pushing to main and
  let the user open `clock.html` locally. Say what was and wasn't checked. Skip only when told to.
- Commit as `geeForceOne <1780268+geeForceOne@users.noreply.github.com>`, never with a real name or
  Gmail (the repo is public). Write commit messages that explain why.

## Origin

Ported from an older UWP/C# app (ClockClock24 + ClockClock24Core).
Its `Digit.cs` is the source of the `DIGITS` pose table. The port fixes these original bugs:
- clock froze at midnight (`TimeSpan` rolled over to 1 day and never updated again)
- `By = ±1` on the storyboards was meant to give opposite hand directions but XAML ignored it
- hands started at 0° instead of the neutral pose

The original has no options or click dialog; all options here are new.

## How the clock works

- `DIGITS[n]` = 6 `[hour, minute]` poses in row-major order (2 wide, 3 high).
  `[7.5, 37.5]` is the blank pose: the clock is not part of the digit and its hands fade out.
- Angles: `hour*30 - 90`, `minute*6 - 90` (0° points right, positive is clockwise, same as CSS `rotate`).
- Each clock keeps an unwrapped angle per hand (`hourDeg`, `minuteDeg`); the selected `PATHS`
  entry computes the next angle from the current one (hour hand dir `+1`, minute `-1`).
- Timing: shows the current minute at startup, then switches to the next minute early
  (`duration + max wave delay + 2s`) so the animation lands just before the minute turns.
- Clocks are addressed both as `digits[d][c]` and `grid[y][x]` (x 0–7, y 0–2).

## Options panel

The options live in a `<dialog>` opened by clicking the first clock (top-left of the first
digit); a click outside (or Esc) closes it — there is no × button. With `?wallpaper` (the Lively
wallpaper) the first clock opens nothing; its settings come from Lively's Customize panel. It is
kept small (no title, no option descriptions, `width: fit-content`) and sits low on the screen
with a light backdrop so previews stay visible. Clicking the last clock (bottom-right) plays a
crazy show. The clock itself fills the whole window.

Three columns (`.section`, side by side, stacked below 700px), each a grid of label + control
rows of the same height (`--row`): Time change (Path, Easing, Wave, Magnet, Faces as `<select>`s,
Duration slider, Preview), Look (face color + None = `clear`, hand color, rim color + Fade =
`fade`, Spacing = `gap` slider),
Crazy (how often, Show, Go crazy). The dialog has its own color tokens, so the Look settings
don't recolor it. The selects are generated from the tables (`PATHS`, `EASINGS`, `WAVES`,
`MAGNETS`, `FACES`, `CRAZY`, `SHOWS`) via `CHOICES` per `select[data-key]`. To add an option, add
an entry to the table — the UI picks it up (and mirror it in the Lively package, see Lively).
`SHOWS` is defined further down, so it joins `CHOICES` there and `loadSettings()` runs right after
it. The selects stay as the value holders but open our own list (`openList()`, `.list` in a
full-window `.list-shade` that catches a press outside): it stops at the window edge and scrolls by
its own pointer-drag code with `touch-action: none`. The native popup ran off the Pi's small screen,
and `appearance: base-select` wouldn't scroll by touch there. The shade reaches outside the dialog,
so the click-outside check also needs `e.target === dialog`. Settings persist in `localStorage` (`clockclock-settings`), wrapped in try/catch; every value
goes through `accept(key, value)`, which validates it. URL options with the same names
(`?path=spin&hand=ff8800&gap=8&clear`) override the saved ones. `applyLook()` writes face, hand,
rim and gap to the `--face`/`--hand`/`--rim`/`--gap` variables (gap even, 0–24px). Fade: `busy(s)`
(from `showTime()` and `goCrazy()`, extending, never shortening) removes `.rest` from `root` and
sets it again when nothing moves any more; `.rest` makes the rims transparent (out 2s, in 0.6s). Changing a Crazy or Show
option plays a show; any other select, the Duration slider or Preview animates to a random time
and back; the Look controls apply while you pick.

Path, Easing, Wave, Faces and Show have a `random` entry (`randomChoice()`, flagged `random: true`).
Code reads the resolved values from `active` (never `settings.path` etc. directly); `pickActive()`
re-picks them at every `showTime()` (Faces Random never picks `off`).
`maxDelay()` uses the longest wave when Wave is Random, since `tick()` needs it before the pick.

## Magnet

After both clocks of a pair have landed, hands pointing at an axis-aligned neighbor stretch:
- `reach`: hand goes to the neighbor's center, so the stroke is one bar (needed for the lower
  strokes of 3 and 8 and the middle bars of 6 and 9).
- `tucked`: neighbor points straight back → only the right/down hand of the pair reaches; the
  left/up one shrinks to its pivot dot, so there is no joint (overlapping rounded tips showed).
All hands retract when the time changes. `magnetGen` cancels stale snap timeouts.
Hands have `z-index: 1` so stretched hands paint over the neighboring face.

## Face moves

Each `FACES` entry has `play(clock, delay)`, called by `moveFace()` when a clock's pose actually
changes (with its wave delay); crazy shows don't play face moves. The hands move with the face.
Pulse/Flip/Wobble are Web Animations keyframes on the face's `transform`. `mix` picks a random move
per face. Clock (id `real`, `realClock()`) fades in 12 hour lines (`.face.dial::before`, a masked
`repeating-conic-gradient`), turns the hands to the actual time (35% of the duration), holds, then
turns them to `clock.pose` (last 40%), so it lands when a plain move would. Blank faces show their
hands during it. Its `everyClock` flag makes `setPose()` play it on every clock, not only those
whose pose changed. `clock.realGen` cancels a stale second half; `goCrazy()` bumps it on every clock.

## Crazy shows

`SHOWS` maps ids to `{ name, steps }` or, for a whole-screen scene, `{ name, play(gen) }`, where
`play` starts the scene and returns its length in seconds (Billiard, Saber, Tron, Bougainvillea). `steps` is a list of
`{ angles(clock), dur, delay(clock), path }` played in order by `goCrazy()` via `turnTo()` (which
takes raw angles, unlike `setPose`). Random is the last entry in every options table (in Show
followed by Random (low power), `randomLow`).
`goCrazy()` plays `settings.show` (Random picks any other entry; Random (low power) skips shows
flagged `heavy`, the ones measured as too much for a Pi 3 — measure a new show on the Pi too). During a step show all hands
show (blank faces included). Magnet links retract when a show starts, except for shows with
`keepLinks` (Bougainvillea: the hands keep showing the time). `endScenes()` (in `goCrazy()` and
`showTime()`) removes what a scene left behind, separate from `retractHands()`. `holdUntil`
pauses `tick()` for previews and shows; when it expires, `tick()` lands on the current time.
The `crazy` setting (How often) plays shows at random intervals, not at fixed times: `CRAZY` entries
have `between: [min, max]` minutes; `crazyPlan` holds the minute the next show lands on, planned when
the page starts or the setting changes and again after each show (a late one plays at the next
minute). Old saved ids (`five`, `hour`) map to their replacements via `RENAMED` in `accept()`, and
`lively-setup.ps1` maps the old Lively item names. `tick()` starts the show's minute
switch `SHOW_SECONDS` earlier. Every show must fit in `SHOW_SECONDS`. `showGen` cancels a
running show.

## Look

Black page and faces, white hands, thin (0.5px) gray `#555` rim. Colors are CSS variables
on `:root`. Clock size `--s` fits 8 clocks across and 3 down in the window. `--s` is the grid
cell (all positions, hand reach and billiard math are in cell units); each face is `--gap` (4px,
keep it even so centers stay on whole pixels) smaller with half of it as margin. Where CSS `round()` is supported,
`--s` and hand thickness `--t` snap to even whole pixels and `.clock24` is positioned on a whole
pixel, so joined hands from different clocks line up exactly (fractional sizes left visible
notches at the joins).

## Lively (Windows desktop wallpaper)

`wallpaper/` plus `clock.html` is a Lively Wallpaper web wallpaper package (`LivelyInfo.json`,
`Type: 1`); everything is local, so the wrapper, its Customize panel and the clock are always the
same version. `index.html` shows a background image and `clock.html` in an `<iframe>` with
`?transparent&wallpaper` (no page background, no options click) plus every clock setting as a URL
option; a change reloads the frame (debounced, Lively sends every setting at startup). Lively can't
show the Windows wallpaper through a transparent page (it shows white), so the page draws the
background. `?clock=../clock.html` on index.html runs it from the repo over a local server.

Lively's web player drops localStorage on exit (tested, disk cache doesn't help), so in the
wallpaper all settings live in `LivelyProperties.json` (Lively's Customize panel;
`livelyPropertyListener(name, val)`; labels as section titles): background image from `images/`
(`folderDropdown`; its file dialog copies pictures there), image URL (overrides it; debounced,
falls back to the color and retries), color, corner, size (% of screen width), the two margins
(px from the screen edge to the faces; the frame's height follows the clock's 8:3 shape plus
clock.html's 24px padding), and a copy of every clock setting. **Every clock setting change must
be mirrored here**: dropdowns send the item's index, so `CLOCK_CHOICES` in index.html lists the
clock ids in the order of the items, and the items carry the clock's names.

`lively-setup.ps1` (Windows PowerShell 5.1 and 7) downloads `main` (or `-Source <repo folder>`,
`-Branch`), builds the package and finds Lively's library: classic `%LocalAppData%\Lively
Wallpaper`, Store version under `Packages\*LivelyWallpaper*\LocalCache\Local\Lively Wallpaper`
(Lively's own `WallpaperDir` in `Settings.json` is the unredirected path). Our wallpaper is the
folder whose `LivelyInfo.json` has `Contact` = the repo URL. Not installed → it writes
`gClockClock-lively.zip` to Downloads to drag onto Lively. Installed → it closes all `Lively*`
processes, copies the package over (pictures in `images/` stay), merges the saved values in
`SaveData\wpdata\<folder>\<screen>\LivelyProperties.json` into the new file (by key; dropdowns by
item name; `.bak` kept) and starts Lively again (Store: `shell:AppsFolder\<family>!App`).

## Environment

Windows; Node is not installed, so there is no way to run or lint JS from the shell —
verify changes by opening `clock.html` in a browser.

## Conventions

- **Verify external APIs, don't work from memory.** Check current official docs before relying on
  browser APIs (Web Animations, CSS `round()`), Chromium flags, labwc, or Raspberry Pi OS tools.
- **American English** in all English text (comments, docs, labels): color, center, neighbor.
  Exception: real names that are spelled otherwise, e.g. `raspi-config nonint do_boot_behaviour`.
