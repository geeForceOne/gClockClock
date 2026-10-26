#!/bin/bash
# Sets up a Raspberry Pi (Raspberry Pi OS with desktop) to show the clock full screen on boot:
# desktop auto-login, no screen blanking, Chromium in kiosk mode on the clock's address.
# Run it once as the normal user (not root), then reboot:
#   bash kiosk-setup.sh [url]
set -e
URL="${1:-https://geeforceone.github.io/gClockClock/clock.html}"
BROWSER=$(command -v chromium-browser || command -v chromium) || { echo "Chromium not found"; exit 1; }

# No incognito: the clock's settings are kept in the browser's storage.
# --password-store=basic avoids a keyring password prompt at login.
CMD="$BROWSER --kiosk --noerrdialogs --disable-infobars --no-first-run --password-store=basic --disable-session-crashed-bubble --hide-crash-restore-bubble $URL"

sudo raspi-config nonint do_boot_behaviour B4   # boot to desktop, logged in automatically
sudo raspi-config nonint do_blanking 1          # never blank the screen

# labwc (Raspberry Pi OS Bookworm since late 2024)
mkdir -p ~/.config/labwc
grep -qsF "$URL" ~/.config/labwc/autostart || echo "$CMD &" >> ~/.config/labwc/autostart

# wayfire (earlier Bookworm)
if [ -f ~/.config/wayfire.ini ] && ! grep -qF "$URL" ~/.config/wayfire.ini; then
  if grep -q '^\[autostart\]' ~/.config/wayfire.ini; then
    sed -i "/^\[autostart\]/a clock = $CMD" ~/.config/wayfire.ini
  else
    printf '\n[autostart]\nclock = %s\n' "$CMD" >> ~/.config/wayfire.ini
  fi
fi

# X11 / LXDE (Bullseye and older)
mkdir -p ~/.config/lxsession/LXDE-pi
AUTOSTART=~/.config/lxsession/LXDE-pi/autostart
[ -f "$AUTOSTART" ] || cp /etc/xdg/lxsession/LXDE-pi/autostart "$AUTOSTART" 2>/dev/null || true
grep -qsF "$URL" "$AUTOSTART" || echo "@$CMD" >> "$AUTOSTART"

echo "Done. Reboot to start the clock: sudo reboot"
