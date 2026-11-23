# Home Assistant card (Marketplace)

Since Home Assistant 2026.11, HACS is built in as the Marketplace; it still reads `hacs.json` and
follows the HACS publishing rules, so "HACS" below means either.

Details split off from `CLAUDE.md`.

## Files

- `clock.js`: the clock engine, shared with `clock.html`. `gClockClock(stage, options)` builds the
  clock in `stage` and returns a control object (`settings`, `defaults`, `choices`, `set()`,
  `preview()`, `goCrazy()`, `busy()`, `stop()`). Its CSS is a string in the file; `addStyle()` puts
  it in the page's `<head>` or in the shadow root the stage is in.
- `gClockClock.js`: the card (`custom:gclock-card`), an ES module (dashboard resources load as
  modules). It loads `clock.js` from next to itself as a classic script, passing on its own query
  (`?v=…`, the installed version) so the two files match.
- `hacs.json`: just the name. HACS downloads every `.js` file from the first place one is named
  after the repo (`dist/`, then the latest release, then the root), so both files come from the
  root. Don't add other `.js` files to the root. A non-JS file the card needs would mean moving
  everything to `dist/` (per the HACS docs).
- `docs/card-test.html`: a mock dashboard page to try the card without HA (serve the repo with
  `python -m http.server`).

## The stage

The engine never touches the window: everything goes in the stage (`.gclock`, `position:
relative`, `overflow: hidden`, `isolation: isolate`, `container-type: size`). Sizes use `cqw`/`cqh`
(the stage), not `vw`/`vh`. Show layers (canvases, SVG, heads, sparks, snow, fireworks) are
`position: absolute` children of the stage, placed with `box(el)` (a box relative to the stage)
instead of `getBoundingClientRect()`. Egg classes and the look variables are on the stage. Keep it
that way for new shows: `stage.append()`, never `document.body`. `--pad` is the space around the
clock (24px in the page, 8px in the card).

## The card

- Config keys = the clock settings (same names and values as the URL options) plus `transparent`
  (no black fill, the dashboard's card background shows). Colors take `"#ff8800"` or `[255, 136, 0]`
  (what HA's `color_rgb` picker stores).
- `setConfig()` on a running card calls `set()` with the defaults under the config (a removed key
  goes back to its default), then plays like the options panel: a changed show or How often plays
  a show, a changed time-change setting previews, a rim/fade change shows the rims.
- No localStorage and no URL options in the card; tapping the last clock plays a show, the first
  clock does nothing.
- HA detaches cards while another view shows: `disconnectedCallback()` stops the clock only after
  60s away, `connectedCallback()` starts a new one if it was stopped. A show due while the card has
  no size (hidden) is skipped (`tick()` shows the time instead).
- `getConfigForm()` (HA's built-in editor): three expandable groups like the options panel; select
  lists come from `gClockClock.choices()` (an idle clock that isn't attached or run), so a new table
  entry shows up by itself. **A new setting key needs a field and a label here.**
- `getGridOptions()`: full width by default, at least 6 of the 12 columns, height from the 8:3
  shape (`aspect-ratio` on the stage).

## Releases

No GitHub releases yet: HACS then offers the default branch (version = short commit hash), so a
push to `main` also updates HACS users. With releases, HACS offers the last 5 releases plus the
default branch ("just tags are not enough"). Users add the repo in the Marketplace as a custom
repository (type Dashboard; needs a connected GitHub account); the HACS default list needs a separate submission.
