# gClockClock

A ClockClock 24 style clock: 24 small analog clocks (4 digits × 2×3 grid) whose hands
turn to form the time. Plain HTML/CSS/JS, no build, no dependencies.

## Files

- `clock.html` — the whole app (markup, styles, script). Open it in a browser to run.
- `kiosk-setup.sh` — sets up a Raspberry Pi to show the clock full screen (see Deploy).

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
digit); a click outside (or Esc) closes it — there is no × button. It is kept as small as possible
(no title, no option descriptions, `width: fit-content`) and sits low on the screen with a light backdrop so previews stay visible. Clicking the last clock (bottom-right) plays a crazy show. The clock itself
fills the whole window.

Two sections, split by an `<hr class="divider">`: the time change (Path, Easing, Wave, Magnet,
Faces, Duration + Preview) and crazy mode (Crazy = how often + Go crazy, Show = which show).
They are defined as data (`PATHS`, `EASINGS`, `WAVES`, `MAGNETS`, `FACES`, `CRAZY`, `SHOWS`) and
rendered from `CHOICES`; buttons are generated per `.group[data-key]`. To add an option, add an
entry to the table — the UI picks it up. `SHOWS` is defined further down, so it joins `CHOICES`
there and `loadSettings()` runs right after it. Settings persist in `localStorage`
(`clockclock-settings`), validated on load, wrapped in try/catch. Clicking a Crazy or Show option
plays a show; any other option or Preview animates to a random time and back.

Path, Easing, Wave, Faces and Show have a `random` entry (`randomChoice()`, flagged `random: true`).
Code reads the resolved values from `active` (never `settings.path` etc. directly); `pickActive()`
re-picks them at every `showTime()` (Faces Random never picks `off`).
`maxDelay()` uses the longest wave when Wave is Random, since `tick()` needs it before the pick.

## Magnet

After both clocks of a pair have landed, hands pointing at an axis-aligned neighbour stretch:
- `reach`: hand goes to the neighbour's centre, so the stroke is one bar (needed for the lower
  strokes of 3 and 8 and the middle bars of 6 and 9).
- `tucked`: neighbour points straight back → only the right/down hand of the pair reaches; the
  left/up one shrinks to its pivot dot, so there is no joint (overlapping rounded tips showed).
All hands retract when the time changes. `magnetGen` cancels stale snap timeouts.
Hands have `z-index: 1` so stretched hands paint over the neighbouring face.

## Face moves

Each `FACES` entry has `play(clock, delay)`, called by `moveFace()` when a clock's pose actually
changes (with its wave delay); crazy shows don't play face moves. The hands move with the face.
Pulse/Flip/Wobble are Web Animations keyframes on the face's `transform`. `mix` picks a random move
per face. Clock (id `real`, `realClock()`) fades in 12 hour lines (`.face.dial::before`, a masked
`repeating-conic-gradient`), turns the hands to the actual time (35% of the duration), holds, then
turns them to `clock.pose` (last 40%), so it lands when a plain move would. Blank faces show their
hands during it. Its `everyClock` flag makes `setPose()` play it on every clock, not only those
whose pose changed. `clock.realGen` cancels a stale second half; `goCrazy()` bumps it on every clock.

## Billiard

Billiard is a crazy show (`SHOWS.billiard`, no `steps`), not a face move. `goCrazy()` calls
`breakShot()` and holds for `BILLIARD_SECONDS`; the hands keep showing the time (blank faces stay
blank) and the new time lands afterwards. `breakShot()` drives a rAF loop (`roll()`) through `PHASES`: shrink to `BALL` size (the balls stay black) → the 21 clocks outside the cue column glide into a 6-row triangle (`rack()`), the
column's middle clock becomes the cue ball and the other two line up behind it → `aim`: those two
turn their hour hand at the ball and minute hand straight back (one straight line through both
faces; crazy-show steps skip clocks with `isStick`; `freezeHands()` first pins the hands at their
on-screen angle, otherwise a hand whose stick angle equals its current target keeps its old slow
transition and the stick looks bent) and stretch them (`.hand.stick`, `setStick()`) into a cue stick →
pull back → strike → the hands return to their pose and everything rolls (physics: elastic ball collisions, window walls,
friction) → glide home → grow. It writes the CSS `translate`/`scale` properties (separate from
`transform`, so they combine with the other moves). Calling it again mid-scene restarts from
the current positions.

## Crazy shows

`SHOWS` maps ids to `{ name, steps }`; `steps` is a list of `{ angles(clock), dur, delay(clock), path }`
played in order by `goCrazy()` via `turnTo()` (which takes raw angles, unlike `setPose`).
`goCrazy()` plays `settings.show` (Random picks any other entry). During a step show all hands
show (blank faces included); magnet links retract during any show. `holdUntil`
pauses `tick()` for previews and shows; when it expires, `tick()` lands on the current time.
The `crazy` setting plays a show before every 1/5/60th minute; `tick()` starts that minute's
switch `SHOW_SECONDS` earlier. Every show must fit in `SHOW_SECONDS`. `showGen` cancels a
running show.

## Look

Black page and faces, white hands, thin (0.5px) grey `#555` rim. Colours are CSS variables
on `:root`. Clock size `--s` fits 8 clocks across and 3 down in the window. `--s` is the grid
cell (all positions, hand reach and billiard maths are in cell units); each face is `--gap` (4px,
keep it even so centres stay on whole pixels) smaller with half of it as margin. Where CSS `round()` is supported,
`--s` and hand thickness `--t` snap to even whole pixels and `.clock24` is positioned on a whole
pixel, so joined hands from different clocks line up exactly (fractional sizes left visible
notches at the joins).

## Deploy (Raspberry Pi kiosk)

Hosted on GitHub Pages: https://geeforceone.github.io/gClockClock/clock.html (public repo
`geeForceOne/gClockClock`, Pages from `main`, root). A Raspberry Pi shows it full screen in
Chromium kiosk mode. `kiosk-setup.sh` does the whole setup on a fresh Raspberry Pi OS (labwc):
```
curl -sLO https://raw.githubusercontent.com/geeForceOne/gClockClock/main/kiosk-setup.sh
bash kiosk-setup.sh --upside-down   # options: --url URL, --upside-down, --no-sudo
sudo reboot
```
Run as the normal user; it asks for the sudo password once and is safe to re-run (idempotent;
`--no-sudo` does only the home-folder part and prints the rest, handy for testing over SSH).
Home folder: `~/gclock-kiosk.sh` waits for the network, then runs
`chromium --ozone-platform=wayland --kiosk` (without the Wayland flag Chromium tries X11 and fails
when not started from the session); `~/.config/labwc/autostart` starts it via `lwrespawn`
(restarts on exit); plus the performance and slimming items below. System (sudo): auto-login, no
blanking, Bluetooth off, packagekit masked, and with `--upside-down` the rotation below
(backups as `*.gclock-bak`).

Updating = pushing to `main`: when served over http(s) the page fetches itself every 5 minutes
and reloads when the text changed (GitHub Pages caches up to 10 minutes, so allow ~15). If a
broken version stops the page itself, it can't reload; restarting Chromium fixes that after a fix
is pushed. In the page, the `kiosk` section at the end of the script does the self-update
(`checkUpdate()`, only over http(s)) and hides the cursor after 3s idle (`body.idle`). Don't use
incognito in the kiosk, or the settings (localStorage) are lost on every start.

Pi OS updates: `sudo apt update && sudo apt full-upgrade` (packagekit is masked, so nothing updates
by itself); kiosk settings survive. For a new major release Raspberry Pi recommends a fresh install,
then `kiosk-setup.sh` again.

Notes from the reference setup (Pi 3B, Raspberry Pi OS trixie, labwc, 7" DSI touch display):
- Performance: Raspberry Pi OS forces `WLR_RENDERER=pixman` (CPU compositing) on GPUs without MMU
  (Pi 3 and older); labwc used ~50% CPU during animations. `WLR_RENDERER=gles2` in
  `~/.config/labwc/environment` cut that to ~7% (`kiosk-setup.sh` adds it; labwc applies it after
  start, so `/proc/<pid>/environ` still shows pixman). Chromium itself already uses the GPU
  (`--use-angle=gles`, no `--disable-gpu-compositing`). Check `vcgencmd get_throttled` (0x0 =
  fine): under-voltage throttles the Pi 3 to 600 MHz; with the 7" display it needs a good 2.5 A
  supply.
- Slimming: hide unused desktop autostarts with `Hidden=true` overrides in `~/.config/autostart`
  (squeekboard, polkit agent, pprompt, pwrkey; keep autotouch), mask unused user services
  (pipewire, wireplumber, filter-chain, mpris-proxy, gvfs phone/camera monitors); Chromium's cache
  goes to `/dev/shm`. Bluetooth and packagekit can be disabled (sudo).
- Display mounted upside down: rotate once, in the driver —
  `video=DSI-1:800x480@60,panel_orientation=upside_down` in `/boot/firmware/cmdline.txt` (rotates
  the boot logo and desktop; `rotate=180` only rotates the text console, not Plymouth), plus
  `disable_splash=1` in `config.txt`. Keep kanshi at `transform normal` (180 there rotates twice).
  labwc doesn't rotate touch for a driver-level orientation, so flip it with a udev rule:
  `ENV{ID_INPUT_TOUCHSCREEN}=="1", ENV{LIBINPUT_CALIBRATION_MATRIX}="-1 0 1 0 -1 1"`.
- Firefox is no alternative on a Pi 3: WebRender needs GL ES 3.0, the Pi 3 GPU has 2.0 (it would
  composite on the CPU). Chromium works with ES 2.0.

## Environment

Windows; Node is not installed, so there is no way to run or lint JS from the shell —
verify changes by opening `clock.html` in a browser.
