# Deploy

Details split off from `CLAUDE.md`.

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
(restarts on exit); plus the performance and slimming items below. System (sudo): `wlrctl`,
auto-login, no blanking, Bluetooth off, packagekit masked, and with `--upside-down` the rotation
below (backups as `*.gclock-bak`).

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
- Display mounted upside down: rotate once, in labwc — kanshi `transform 180` in
  `~/.config/kanshi/config`, so picture, pointer, popups and touch turn together. Don't rotate in
  the driver as well (`panel_orientation=upside_down` in `cmdline.txt` rotates twice). The driver
  rotation was tried first, for the boot logo, but it only turns the main picture layer: the
  mouse pointer and Chromium's `<select>` popups (other hardware planes) showed upside down and
  mirrored, and touch needed a udev flip. The boot logo can't be turned without it, so
  `cmdline.txt` has no `quiet splash` (no logo) and `fbcon=rotate:2` turns the boot text;
  `disable_splash=1` in `config.txt` hides the firmware rainbow.
- Cursor after boot: labwc's arrow stayed at (100,100) over the running clock until the first
  touch, because the page's `body.idle` didn't hide it before then. `~/gclock-kiosk.sh` therefore
  moves the pointer 1px and back with `wlrctl` 30, 60 and 120s after the network check; a move
  can't click anything, a real tap could hit the first or last clock. To check it, use `grim -c`
  and look at the picture: plain `grim` doesn't show this cursor. The finished background loop
  stays as one harmless `<defunct>` process, because Chromium doesn't reap it.
- Firefox is no alternative on a Pi 3: WebRender needs GL ES 3.0, the Pi 3 GPU has 2.0 (it would
  composite on the CPU). Chromium works with ES 2.0.

