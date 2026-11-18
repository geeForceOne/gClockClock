# gClockClock

ClockClock 24 style clock: 24 small analog clocks (4 digits × 2×3) whose hands form the time.
Plain HTML/CSS/JS in one file, no build, no dependencies. Public repo (MIT).

## Files

- `clock.html` — the whole app. Open it in a browser to run.
- `wallpaper/` + `lively-setup.ps1` — Lively Wallpaper package and its installer.
- `kiosk-setup.sh` — Raspberry Pi full-screen kiosk setup.
- `docs/` — the notes below, plus README screenshots.

## Read before changing

These are not loaded by default. Read the matching file first:

- `docs/internals.md` — options panel and custom lists, magnet, face moves, step shows, look and pixel snapping.
- `docs/shows.md` — the scenes, `settle()`/`landedOn`, easter eggs (`EGGS`).
- `docs/lively.md` — the wallpaper package, its Customize panel, `lively-setup.ps1`.
- `docs/deploy.md` — GitHub Pages, self-update, `kiosk-setup.sh`, the Pi.

## Core model

- `DIGITS[n]` = 6 `[hour, minute]` poses, row-major, 2 wide × 3 high (from the original UWP app's
  `Digit.cs`). `[7.5, 37.5]` is blank: the hands fade out.
- Angles: `hour*30 - 90`, `minute*6 - 90` (0° points right, clockwise is positive, like CSS `rotate`).
- Each clock keeps unwrapped `hourDeg`/`minuteDeg`; the `PATHS` entry computes the next angle
  (hour hand dir `+1`, minute `-1`).
- Timing: the current minute at startup, then each change starts early
  (`duration + max wave delay + 2s`) so it lands just before the minute turns. Shows start
  `SHOW_SECONDS` earlier, and every show must fit in it.
- Clocks are addressed as `digits[d][c]` and `grid[y][x]` (x 0–7, y 0–2).
- Generation counters (`showGen`, `magnetGen`, `clock.realGen`) cancel stale timeouts.

## Rules

- Options come from the tables (`PATHS`, `EASINGS`, `WAVES`, `MAGNETS`, `FACES`, `CRAZY`, `SHOWS`).
  To add an option, add a table entry; Random stays last.
- Mirror every clock setting change in the Lively package: `wallpaper/LivelyProperties.json` and
  the `CLOCK_CHOICES` order in `wallpaper/index.html` (dropdowns send indexes).
- Read resolved values from `active`, never `settings.x`. Every value goes through
  `accept(key, value)`; renamed ids go in `RENAMED`.
- Keep `--gap` even (0–24px) so clock centers stay on whole pixels.
- Option lists are drawn by `openList()`, not the native popup (it ran off the Pi's screen and
  wouldn't scroll by touch). Don't switch back.
- Measure a new show on the Pi 3; flag it `heavy` if it's too much.
- American English (color, center, neighbor), except real names spelled otherwise.
- Check current docs for browser APIs, Chromium flags, labwc and Pi OS tools; don't work from memory.

## Testing

Node isn't installed, so JS can't be run or linted from the shell. Verify by opening `clock.html`
in a browser. URL options override saved settings: `?path=spin&hand=ff8800&gap=8&clear`.

## Git

- One branch per change, off an up-to-date main. A push to main is a deploy (Pages; the Pi
  reloads within ~15 min).
- Stop before merging or pushing so the user can test `clock.html` locally; say what was and
  wasn't checked.
- Commit as `geeForceOne <1780268+geeForceOne@users.noreply.github.com>`, never a real name (public
  repo). Messages explain why.
- After a merge: pull main, `git branch -d` the merged branches, `git fetch --prune`.
