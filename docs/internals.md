# Internals

Details split off from `CLAUDE.md`: the options panel, magnet, face moves, step shows and the look.
The options panel and the kiosk code are in `clock.html`, everything else in `clock.js` (the stage
and the card: `docs/hacs.md`).
The scenes and easter eggs are in `docs/shows.md`.

## Options panel

The options live in a `<dialog>` opened by clicking the first clock (top-left of the first
digit); a click outside (or Esc) closes it — there is no × button. With `?wallpaper` (the Lively
wallpaper) the first clock opens nothing; its settings come from Lively's Customize panel. It is
kept small (no title, no option descriptions, `width: fit-content`) and sits low on the screen
with a light backdrop so previews stay visible. Clicking the last clock (bottom-right) plays a
crazy show (in `clock.js`; the first clock calls `options.onFirstClock`). The clock itself fills
the whole window.

Three columns (`.section`, side by side, stacked below 700px), each a grid of label + control
rows of the same height (`--row`):
- Time change: Path, Easing, Wave, Magnet, Faces as `<select>`s, Duration slider, Preview.
- Look: face color + None = `clear`, hand color, rim color + Fade = `fade`, Spacing = `gap` slider.
- Crazy: how often, Show, Go crazy.

The dialog has its own color tokens, so the Look settings don't recolor it.

The selects are generated from the tables (`PATHS`, `EASINGS`, `WAVES`, `MAGNETS`, `FACES`,
`CRAZY`, `SHOWS`) via `CHOICES` per `select[data-key]`. To add an option, add an entry to the
table — the UI picks it up (and mirror it in the Lively package, see `docs/lively.md`). `SHOWS` is
defined further down, so it joins `CHOICES` there and `loadSettings()` runs right after it.

The selects stay as the value holders but open our own list (`openList()`, `.list` in a
full-window `.list-shade` that catches a press outside): it stops at the window edge and scrolls by
its own pointer-drag code with `touch-action: none`. The native popup ran off the Pi's small screen,
and `appearance: base-select` wouldn't scroll by touch there. The shade reaches outside the dialog,
so the click-outside check also needs `e.target === dialog`.

Settings persist in `localStorage` (`clockclock-settings`, only with `options.store`), wrapped in try/catch; every value goes
through `accept(key, value)`, which validates it. URL options with the same names
(`?path=spin&hand=ff8800&gap=8&clear`) override the saved ones. `applyLook()` writes face, hand,
rim and gap to the `--face`/`--hand`/`--rim`/`--gap` variables on the stage (gap even, 0–24px).

Fade: `busy(s)` (from `showTime()` and `goCrazy()`, extending, never shortening) removes `.rest`
from `root` and sets it again when nothing moves any more; `.rest` makes the rims transparent (out
2s, in 0.6s).

Changing a Crazy or Show option plays a show; any other select, the Duration slider or Preview
animates to a random time and back; the Look controls apply while you pick.

Path, Easing, Wave, Faces and Show have a `random` entry (`randomChoice()`, flagged `random: true`).
Code reads the resolved values from `active` (never `settings.path` etc. directly); `pickActive()`
re-picks them at every `showTime()` (Faces Random never picks `off`). `maxDelay()` uses the longest
wave when Wave is Random, since `tick()` needs it before the pick.

## Magnet

After both clocks of a pair have landed, hands pointing at an axis-aligned neighbor stretch:
- `reach`: hand goes to the neighbor's center, so the stroke is one bar (needed for the lower
  strokes of 3 and 8 and the middle bars of 6 and 9).
- `tucked`: neighbor points straight back → only the right/down hand of the pair reaches; the
  left/up one shrinks to its pivot dot, so there is no joint (overlapping rounded tips showed).

All hands retract when the time changes. `magnetGen` cancels stale snap timeouts. Hands have
`z-index: 1` so stretched hands paint over the neighboring face.

## Face moves

Each `FACES` entry has `play(clock, delay)`, called by `moveFace()` when a clock's pose actually
changes (with its wave delay); crazy shows don't play face moves. The hands move with the face.
Pulse/Flip/Wobble are Web Animations keyframes on the face's `transform`. `mix` picks a random move
per face.

Clock (id `real`, `realClock()`) fades in 12 hour lines (`.face.dial::before`, a masked
`repeating-conic-gradient`), turns the hands to the actual time (35% of the duration), holds, then
turns them to `clock.pose` (last 40%), so it lands when a plain move would. Blank faces show their
hands during it. Its `everyClock` flag makes `setPose()` play it on every clock, not only those
whose pose changed. `clock.realGen` cancels a stale second half; `goCrazy()` bumps it on every clock.

## Crazy shows

`SHOWS` maps ids to `{ name, steps }` or, for a whole-screen scene, `{ name, play(gen) }`, where
`play` starts the scene and returns its length in seconds (Billiard, Saber, Tron, Tron 2, Matrix, Bougainvillea, Color plate).
`steps` is a list of `{ angles(clock), dur, delay(clock), path }` played in order by `goCrazy()` via
`turnTo()` (which takes raw angles, unlike `setPose`). Random is the last entry in the tables that
have one (Path, Easing, Wave, Faces, Show); in Show it is followed by Random (low power),
`randomLow`.

`goCrazy()` plays `settings.show` (Random picks any other entry; Random (low power) skips shows
flagged `heavy`, the ones measured as too much for a Pi 3 — measure a new show on the Pi too).
During a step show all hands show (blank faces included). Magnet links retract when a show starts,
except for shows with `keepLinks` (Bougainvillea: the hands keep showing the time). `endScenes()`
(in `goCrazy()` and `showTime()`) removes what a scene left behind, separate from `retractHands()`.
`holdUntil` pauses `tick()` for previews and shows; when it expires, `tick()` lands on the current
time.

The `crazy` setting (How often) plays shows at random intervals, not at fixed times: `CRAZY`
entries have `between: [min, max]` minutes; `crazyPlan` holds the minute the next show lands on,
planned when the page starts or the setting changes and again after each show (a late one plays at
the next minute). Old saved ids (`five`, `hour`) map to their replacements via `RENAMED` in
`accept()`, and `lively-setup.ps1` maps the old Lively item names. `tick()` starts the show's minute
switch `SHOW_SECONDS` earlier. Every show must fit in `SHOW_SECONDS`. `showGen` cancels a running
show.

## Look

Black page and faces, white hands, thin (0.5px) gray `#555` rim. Colors are CSS variables on
the stage (`.gclock`). Clock size `--s` fits 8 clocks across and 3 down in the stage, inside `--pad`. `--s` is the grid cell (all
positions, hand reach and billiard math are in cell units); each face is `--gap` (4px, keep it even
so centers stay on whole pixels) smaller with half of it as margin. Where CSS `round()` is
supported, `--s` and hand thickness `--t` snap to even whole pixels and `.clock24` is positioned on
a whole pixel, so joined hands from different clocks line up exactly (fractional sizes left visible
notches at the joins).

## Origin

Ported from an older UWP/C# app (ClockClock24 + ClockClock24Core); its `Digit.cs` is the source of
`DIGITS`. The port fixed: the clock froze at midnight (`TimeSpan` rolled over to 1 day), `By = ±1`
on the storyboards was ignored by XAML (meant to give opposite hand directions), and hands started
at 0° instead of the neutral pose. The original had no options or click dialog; all options are new.
