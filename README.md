# gClockClock

A ClockClock 24 style clock in the browser: 24 small analog clocks whose hands turn together to
form the time. One HTML file, no build, no dependencies.

**Live:** https://geeforceone.github.io/gClockClock/clock.html

## Use

Open `clock.html` in a browser (or the live link). The clock fills the whole window.

- **Click the first clock** (top left) to open the options: how the hands move to the next time
  (path, easing, wave, magnet, face moves, duration) and how often a crazy show plays. Settings are
  kept in the browser.
- **Click the last clock** (bottom right) to play a crazy show, such as Billiard.

## Raspberry Pi kiosk

`kiosk-setup.sh` turns a fresh Raspberry Pi OS (labwc) into a full-screen clock in Chromium kiosk
mode. Run it as the normal user:

```
curl -sLO https://raw.githubusercontent.com/geeForceOne/gClockClock/main/kiosk-setup.sh
bash kiosk-setup.sh                 # options: --url URL, --upside-down, --no-sudo
sudo reboot
```

The page checks for a new version every 5 minutes and reloads itself, so the kiosk updates on its
own.

## License

[MIT](LICENSE)
