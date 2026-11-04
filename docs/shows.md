# Crazy show scenes and easter eggs

Details split off from `CLAUDE.md`; the general rules for shows are under "Crazy shows" there.

## Billiard

Billiard is a crazy show (`SHOWS.billiard`, a scene with `play()`), not a face move. Its `play()`
calls `breakShot()` and returns `BILLIARD_SECONDS`; the hands keep showing the time (blank faces stay
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

## Saber

Saber is a scene too (`SHOWS.saber`, `saberDuel(gen)`): a hand-held sword duel between the middle
clocks of digits 2 and 3 (`grid[1][2]` blue, `grid[1][5]` red). Their minute hand ignites into a
blade (`.hand.saber`, 1.9 cells, white core with a `--glow` box-shadow from `--saber-a`/`--saber-b`);
the hour hand is `tucked` as the hilt. The clock is the fighter: the blade swings around its center
and the clock steps toward the other one and back (CSS `translate` with a transition). Every fight
is new: `saberFight()` builds a list of beats from random moves (`strike` high or low, `thrust`,
at most one `lock`, at most two `miss`es that cut a clock above or below the attacker) until
`SABER_FIGHT`, then a random winner knocks the other blade up and cuts the loser. It tracks the
steps itself so every clash spot is within `SABER_REACH` of both hilts (`spot()`). A beat is
`{ t, d, blue, red, clash, cut }`; a move turns the blade to `deg` (local angles via `deg(i, a)`:
0 points at the other fighter, negative is up) or points it `at` a spot (computed from the hilt
after the step), `step` is cells toward the other fighter, `ease: 'strike'` for a hit. `clash`
fires `spark()` (a fading `.spark` div) and a white flash when the beat ends; `cut: { victim, at,
by, after }` calls `cut()` along fighter `by`'s blade. `cut()` makes two `clip-path` half-plane copies of the face that
drift apart and fall while the face is hidden, then it grows back (an ungated timeout, so a
cancelled show never leaves a face hidden). The other clocks point at each beat's action.
Fighters get `dueling`, `z-index: 2` and a transparent face (so the other fighter's face doesn't
hide a blade); `leaveDuel()` undoes that (and the hilt) and is called from `endScenes()`, as is the removal of
`saber`/`clash`, so a cancelled duel leaves nothing behind.

## Tron

Tron is a scene (`SHOWS.tron`, `lightCycles(gen)`): two light cycles (`--tron-a` cyan from the left,
`--tron-b` orange from the right, random rows) race over the clock centers, one cell per
`TRON_STEP`, turning only at right angles. `raceCycles()` works out the whole race first (so the
length is known): each step `steer()` picks a free cell straight on, left or right (weighted toward
straight on and away from dead ends); a cycle with no free cell, or the loser of two that want the
same cell, crashes (`crash`, `bump` = where it wanted to go); the winner rides on up to `TRON_LAP`
cells (both crashing at once is a draw). The trail is the hands: all hands shrink to `tucked` dots
and the rims become `--tron-grid`; the clock a cycle leaves turns its minute hand at the next cell
(instantly) and grows it to `reach` with a linear width transition that keeps pace with the head;
`.hand.trail` colors it from the face's `--trail`. The head is a `.cycle` div (CSS `translate`
and `rotate`). A crash bumps the head forward and derezzes it into `.pixel` divs; each trail then
flickers out back along its path (Web Animation with `fill: forwards`, cancelled in `onfinish` after
the hand is a dot again). `clearTron()` (from `endScenes()`, only if `tronOn`) removes the heads,
pixels, classes and animations.

Tron 2 (`SHOWS.tron2`, `traceTime(gen)`) shares the look and `clearTron()`, but the cycles ride the
strokes of the time in `shown`: a graph of the new poses (two clocks are joined where either points
at the other), traversed breadth first from an end of each group (random), one stroke per
`TRON2_STEP`; at a fork another head splits off, so every stroke is drawn once. The dots turn to
the new pose while they are dots; a wall is the hand pointing along the stroke, revealed with an
animated `clip-path` (from the pivot, or from the tip when only the far clock's hand points back).
At the end `settle()` lands it (see Matrix).

## Matrix

Matrix (`SHOWS.matrix`, `matrixRain(gen)`) also builds the time in `shown`. Green code rain falls
in all 24 faces (blank ones only get rain): one `<canvas>` (`.matrix`, over the faces but
under the hands, which have `z-index: 1`), mirrored with `setTransform` so the glyphs are mirrored
as in the film, updated once per `MATRIX_TICK` (no rAF). It is never cleared: each tick fades it by
`MATRIX_FADE` (`destination-out`) and each stream draws only its head and the cell it leaves
(`draw()` clears the cell first), so the long tails cost nothing extra. Kept cheap for the Pi
(measured there: the rain went from 8–29 to 45–60 fps): glyphs are copied with `drawImage` from
strips rendered once (`sprite()`; `fillText` per glyph was slow), and there is no clip path —
`spans` limits each column to the rows whose glyph fits in the face, and `inside()` drops hand cells
outside it. Animating the glow by an opacity layer (`::after`) was tried and was slower on the Pi.
A face is a grid of `MATRIX_ROWS` × `MATRIX_ROWS` glyph cells (fewer on small screens, so a row is
at least `MATRIX_MIN_PX`; odd, so a column and a row run through the center), the font as tall as a
row so the glyphs in a column nearly touch; one stream per column, of `MATRIX_GLYPHS`: half-width
katakana as in the film plus digits and symbols (`MATRIX_FONT`; the Pi has them in Droid Sans
Fallback). The rain builds the hands: `builds` holds each clock's hand cells (center out along each hand of the new pose); when a head passes an empty
one, its glyph locks there with chance `matrixLock(t)` (0 at first, 1 before `MATRIX_STOP`) and
stays, bright, while the rain goes on; a column with empty cells restarts at once; a safety net
locks the rest just before `MATRIX_STOP`. When a clock's cells are all locked they flash white and
dissolve, and its solid hands fade in as `.hand.code`. All faces start `blank`, the hands turn to
the new pose while hidden (`poseNow()`), all rims turn `--matrix-rim` (`.face.coded`).
After `MATRIX_STOP` no stream restarts and `settle()` runs; `clearMatrix()` (from the timer when the rain is gone, or
`endScenes()`) removes the canvas.

Tron 2 and Matrix land on the time without turning a hand: `settle(hhmm, poses)` cools the hands to
white (background/box-shadow transitions, `SETTLE_SECONDS`), with Magnet on gives them their link
classes (`handLinks()`; off: plain hands) and sets `landedOn`. `showTime()` for that time then turns
nothing (`setPose(…, still)`) and `linkHands(true)` links at once if Magnet is on. `endScenes()` clears `landedOn` (after `showTime()` has read it).
`posesOf(hhmm)` and `poseNow(clock, pose)` are the shared helpers.

## Bougainvillea

Bougainvillea is a scene (`SHOWS.bougainvillea`, `bougainvillea()`, replaced the old Flower show).
The hands keep showing the time (blank faces stay blank) while a plant grows on the digits in an SVG
layer (`.bloom`, fixed over `root`, `viewBox="0 0 8 3"`, so every size is in cells; colors
`--vine`/`--shoot`/`--leaf` and `BRACT_COLORS`). The digits become a graph: a node per non-blank
clock (all digit poses are axis-aligned, read via `poseAngles()`/`DIRS`), a stroke where two
clocks' hands point at each other, a stub where a hand points at nothing. Vines start below the
bottom row of each digit and spread through the strokes at `BLOOM_SPEED` cells/s (arrival times by
relaxing over the strokes); each stroke is two strands twining round the hands (`strand()`, sine
offsets that cross at the clock centers), plus shoots round the rims (`tendril()`). `grow()` reveals
a path with an animated `stroke-dashoffset` and adds leaves behind the tip and bract clusters (three
`BRACT`s round a white `.blossom`) a little later; the second strand of a pair is `bare` to keep the
element count down for the Pi (about 1,300 SVG elements). At `BLOOM_FALL` each bract falls and sways
(CSS transforms in user units, `transform-box: fill-box`) and the plant fades; `clearBloom()`
(called from `endScenes()`) removes the layer when the time lands or another show starts.

## Easter eggs

`EGGS` maps ids to `{ on(date), start?, stop? }`; `checkEgg()` (every tick) puts class `egg-<id>`
on `<html>` while its day lasts and runs start/stop. `?<id>` turns one on any day (to try it).
The looks are CSS (`.egg-<id> .hand:not(.trail, .code, .saber, .stick)`, so shows that restyle
hands keep their look). Not in the README on purpose (surprises).
- `muertos` (Nov 1–2): arm bones with knobbed joints (`--knobs`); a skeleton hand (`--skeleton`)
  reaches back out of the center where a stroke ends (`.end`: both hands point the same way) and
  at the tip of a hand pointing at nothing (not `.linked`). `markLinked()` sets both classes at
  every `showTime()`; `retractHands()` clears them.
- `may4` (May 4): hilt (`::before`) and glowing blade (`::after`); `lightSabers()` gives each face
  a `--blade` color from `BLADES` via `dayRandom()` (same all day).
- `christmas` (Dec 24–26): candy-cane hands, `.snow` flakes (CSS animations), snow lying in the
  faces (`--pile`, rising during the day).
- `valentine` (Feb 14): pink hands, a beating heart (`.face.blank::after`) in unused faces.
- `newyear` (Dec 31): `tick()` keeps 23:59 until `countdown()` at 23:59:50: the middle digits count
  10…1, then at 00:00 the hands spin into the time (`landedOn`) and `fireworks()` burst.
  `?newyear` counts down at the end of every odd minute.
- `aprilfools` (Apr 1): `aprilFool()` shows the hour off by one at a random minute of each hour
  (`?aprilfools`: every even minute) and holds it ~10 s before `tick()` lands on the real time.

