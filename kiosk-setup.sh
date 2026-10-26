#!/bin/bash
# Sets up a Raspberry Pi (Raspberry Pi OS with desktop, labwc) to show the clock full screen
# after login. Run it once as the normal user (not root):
#   bash kiosk-setup.sh [url]
# Desktop auto-login must be on (Raspberry Pi Imager sets it; otherwise raspi-config,
# System Options > Boot / Auto Login > Desktop Autologin).
set -e
URL="${1:-https://geeforceone.github.io/gClockClock/clock.html}"

# Launcher: wait for the network so Chromium doesn't start on an error page, then show the clock.
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
# no incognito: the clock keeps its settings in the browser profile
exec chromium --ozone-platform=wayland --kiosk --noerrdialogs --disable-infobars --no-first-run \\
  --password-store=basic --hide-crash-restore-bubble --disable-session-crashed-bubble "\$URL"
EOF
chmod +x ~/gclock-kiosk.sh

# Start it at login; labwc on Raspberry Pi OS also runs the system autostart (panel, kanshi).
mkdir -p ~/.config/labwc
grep -qs gclock-kiosk ~/.config/labwc/autostart || echo "/usr/bin/lwrespawn $HOME/gclock-kiosk.sh &" >> ~/.config/labwc/autostart

echo "Done. The clock starts at the next login or reboot."
