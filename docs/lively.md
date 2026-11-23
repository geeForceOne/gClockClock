# Lively (Windows desktop wallpaper)

Details split off from `CLAUDE.md`.

## The package

`wallpaper/` plus `clock.html` and `clock.js` is a Lively Wallpaper web wallpaper package (`LivelyInfo.json`,
`Type: 1`); everything is local, so the wrapper, its Customize panel and the clock are always the
same version. `index.html` shows a background image and `clock.html` in an `<iframe>` with
`?transparent&wallpaper` (no page background, no options click) plus every clock setting as a URL
option; a change reloads the frame (debounced, Lively sends every setting at startup). Lively can't
show the Windows wallpaper through a transparent page (it shows white), so the page draws the
background. `?clock=../clock.html` on index.html runs it from the repo over a local server.

## Settings (Customize panel)

Lively's web player drops localStorage on exit (tested, disk cache doesn't help), so in the
wallpaper all settings live in `LivelyProperties.json` (Lively's Customize panel;
`livelyPropertyListener(name, val)`; labels as section titles):
- background image from `images/` (`folderDropdown`; its file dialog copies pictures there)
- image URL (overrides it; debounced, falls back to the color and retries)
- color, corner, size (% of screen width)
- the two margins (px from the screen edge to the faces; the frame's height follows the clock's
  8:3 shape plus the clock's 24px padding, `--pad`)
- a copy of every clock setting

**Every clock setting change must be mirrored here**: dropdowns send the item's index, so
`CLOCK_CHOICES` in index.html lists the clock ids in the order of the items, and the items carry
the clock's names.

## `lively-setup.ps1`

Runs on Windows PowerShell 5.1 and 7. It downloads `main` (or `-Source <repo folder>`, `-Branch`),
builds the package and finds Lively's library: classic `%LocalAppData%\Lively Wallpaper`, Store
version under `Packages\*LivelyWallpaper*\LocalCache\Local\Lively Wallpaper` (Lively's own
`WallpaperDir` in `Settings.json` is the unredirected path). Our wallpaper is the folder whose
`LivelyInfo.json` has `Contact` = the repo URL.

- Not installed → it writes `gClockClock-lively.zip` to Downloads to drag onto Lively.
- Installed → it closes all `Lively*` processes, copies the package over (pictures in `images/`
  stay), merges the saved values in `SaveData\wpdata\<folder>\<screen>\LivelyProperties.json` into
  the new file (by key; dropdowns by item name; `.bak` kept) and starts Lively again (Store:
  `shell:AppsFolder\<family>!App`).
