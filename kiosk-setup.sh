#!/bin/bash
# Sets up a Raspberry Pi (Raspberry Pi OS with desktop, labwc) as a kiosk for the clock:
# Chromium full screen after boot, tuned for small Pis. Run it once as the normal user (not
# root), then reboot. It can be run again; nothing is added twice.
#
#   bash kiosk-setup.sh [--url URL] [--upside-down] [--no-sudo]
#
#   --url URL       page to show (default: the GitHub Pages clock)
#   --upside-down   the display is mounted upside down: rotate boot logo, desktop and touch
#   --no-sudo       only the parts in your home folder; print the system parts instead
#
# Without sudo (home folder): kiosk launcher + autostart, GPU renderer on Pi 3 and older,
# unused desktop autostarts and user services off, Chromium cache in RAM.
# With sudo (asks for your password once): desktop auto-login, no screen blanking,
# Bluetooth and the background update check (packagekit) off, and --upside-down.
set -e

URL=https://geeforceone.github.io/gClockClock/clock.html
UPSIDE_DOWN=0
USE_SUDO=1
while [ $# -gt 0 ]; do
  case "$1" in
    --url) URL="$2"; shift ;;
    --upside-down) UPSIDE_DOWN=1 ;;
    --no-sudo) USE_SUDO=0 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)"; exit 1 ;;
  esac
  shift
done

[ "$(id -u)" -ne 0 ] || { echo "Run this as your normal user, not with sudo."; exit 1; }
command -v labwc >/dev/null || { echo "labwc not found: this needs Raspberry Pi OS with desktop."; exit 1; }
command -v chromium >/dev/null || { echo "Chromium not found."; exit 1; }
step() { echo "==> $*"; }

# ---- home folder ----

step "Kiosk launcher ~/gclock-kiosk.sh"
cat > ~/gclock-kiosk.sh <<EOF
#!/bin/sh
# Shows the clock full screen. Started at login from ~/.config/labwc/autostart (via lwrespawn,
# which restarts it if Chromium exits). The page reloads itself when a new version is published.
URL=$URL
# wait up to 60s for the network, so Chromium does not start on an error page
for i in \$(seq 60); do
  curl -s -f -o /dev/null --max-time 3 "\$URL" && break
  sleep 1
done
# no incognito: the clock keeps its settings in the browser profile.
# --ozone-platform=wayland: otherwise Chromium tries X11; cache in RAM spares the SD card.
exec chromium --ozone-platform=wayland --kiosk --noerrdialogs --disable-infobars --no-first-run \\
  --password-store=basic --disk-cache-dir=/dev/shm/gclock-cache --hide-crash-restore-bubble \\
  --disable-session-crashed-bubble "\$URL"
EOF
chmod +x ~/gclock-kiosk.sh

step "Start it at login (~/.config/labwc/autostart)"
# labwc on Raspberry Pi OS also runs the system autostart (panel, kanshi) next to this one.
mkdir -p ~/.config/labwc
grep -qs gclock-kiosk ~/.config/labwc/autostart || echo "/usr/bin/lwrespawn $HOME/gclock-kiosk.sh &" >> ~/.config/labwc/autostart

# Pi 3 and older: Raspberry Pi OS makes labwc draw on the CPU (pixman), which makes the
# animations stutter. The GPU renderer works there and cuts labwc's CPU use from ~50% to ~7%.
if ! raspi-config nonint gpu_has_mmu; then
  step "GPU renderer for labwc (Pi 3 and older)"
  grep -qs "^WLR_RENDERER=" ~/.config/labwc/environment || echo "WLR_RENDERER=gles2" >> ~/.config/labwc/environment
fi

step "Turn off desktop autostarts the clock doesn't need"
# Hidden=true in ~/.config/autostart overrides /etc/xdg/autostart (delete the file to undo).
# Kept: autotouch (touch mapping), display setup.
mkdir -p ~/.config/autostart
for name in squeekboard polkit-mate-authentication-agent-1 pprompt pwrkey; do
  printf '[Desktop Entry]\nHidden=true\n' > ~/.config/autostart/$name.desktop
done

step "Turn off user services the clock doesn't need (undo: systemctl --user unmask ...)"
# sound, Bluetooth media control, phone/camera/online-account detection
systemctl --user mask pipewire.socket pipewire.service pipewire-pulse.socket pipewire-pulse.service \
  wireplumber.service filter-chain.service mpris-proxy.service gvfs-afc-volume-monitor.service \
  gvfs-goa-volume-monitor.service gvfs-gphoto2-volume-monitor.service gvfs-mtp-volume-monitor.service \
  >/dev/null 2>&1 || true

if [ $UPSIDE_DOWN = 1 ] && [ -f ~/.config/kanshi/config ]; then
  # the driver rotates the picture (see below); a 180 here as well would rotate it twice
  sed -i 's/transform 180/transform normal/' ~/.config/kanshi/config
fi

# ---- system (sudo) ----

# Upside-down display: rotate once, in the driver. panel_orientation also turns the boot logo
# (rotate=180 would only turn the text console). The output and its mode come from the driver.
OUT=$(ls /sys/class/drm/ | sed -n 's/^card[0-9]*-\(DSI-[0-9]\)$/\1/p' | head -1)
[ -n "$OUT" ] || OUT=$(ls /sys/class/drm/ | sed -n 's/^card[0-9]*-\(HDMI-A-[0-9]\)$/\1/p' | head -1)
MODE=$(head -1 /sys/class/drm/card*-"$OUT"/modes 2>/dev/null)
VIDEO="video=$OUT:${MODE}@60,panel_orientation=upside_down"
TOUCH_RULE='ENV{ID_INPUT_TOUCHSCREEN}=="1", ENV{LIBINPUT_CALIBRATION_MATRIX}="-1 0 1 0 -1 1"'

if [ $USE_SUDO = 0 ]; then
  echo
  echo "Skipped (--no-sudo). The system part would:"
  echo "  - turn on desktop auto-login and turn off screen blanking (raspi-config)"
  echo "  - disable Bluetooth and mask packagekit"
  [ $UPSIDE_DOWN = 1 ] && echo "  - add '$VIDEO' to /boot/firmware/cmdline.txt, disable_splash=1 to config.txt," &&
    echo "    and flip touch with a udev rule"
  echo "Then reboot."
  exit 0
fi

step "System settings (asks for your password)"
sudo -v
sudo raspi-config nonint do_boot_behaviour B4   # boot to the desktop, logged in automatically
sudo raspi-config nonint do_blanking 1          # never blank the screen
sudo systemctl disable --now bluetooth >/dev/null 2>&1 || true
sudo systemctl mask packagekit >/dev/null 2>&1 || true

if [ $UPSIDE_DOWN = 1 ]; then
  [ -n "$OUT" ] && [ -n "$MODE" ] || { echo "No display found to rotate."; exit 1; }
  step "Upside-down display: $OUT $MODE"
  CMDLINE=/boot/firmware/cmdline.txt
  [ -f $CMDLINE.gclock-bak ] || sudo cp $CMDLINE $CMDLINE.gclock-bak
  # replace any earlier video= setting for this output, then add ours (cmdline.txt is one line)
  sudo sed -i -e "s/ video=$OUT:[^ ]*//g" -e "1 s/\$/ $VIDEO/" $CMDLINE
  CONFIG=/boot/firmware/config.txt
  [ -f $CONFIG.gclock-bak ] || sudo cp $CONFIG $CONFIG.gclock-bak
  grep -q '^disable_splash=1' $CONFIG || echo 'disable_splash=1' | sudo tee -a $CONFIG >/dev/null
  # labwc doesn't rotate touch for a driver-level orientation, so flip it here
  printf '# display mounted upside down (panel_orientation in cmdline.txt): flip touch to match\n%s\n' "$TOUCH_RULE" |
    sudo tee /etc/udev/rules.d/99-gclock-touch-rotate.rules >/dev/null
fi

echo
echo "Done. Reboot to start the clock: sudo reboot"
