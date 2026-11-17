# Retro LED Clock — macOS screensaver (macOS 26+)

A vintage 7-segment LED clock with glowing digits and faint "unlit" segments.

## Install

### Option A: download a prebuilt release
1. Download the latest `.zip` from [Releases](https://github.com/shreyasatre/retro-led-clock-screensaver/releases) and unzip it.
2. Prebuilt versions aren't notarized by Apple, so macOS will block them at first.
   Right-click **Retro LED Clock.saver** → **Open**, or run:
   ```
   xattr -cr ~/Downloads/"Retro LED Clock.saver"
   ```
3. Double-click **Retro LED Clock.saver** to install it.

### Option B: build from source
Building it yourself avoids the Gatekeeper warning.
```
git clone https://github.com/shreyasatre/retro-led-clock-screensaver
cd retro-led-clock-screensaver
bash install.sh
```
If prompted, install Apple's Command Line Tools, then run `install.sh` again.

### Then
Open System Settings → Screen Saver, pick **Retro LED Clock**, and click **Options…**
To preview it full-screen right away, run `open -a ScreenSaverEngine`.

## Options
- 8 colors: Red, Blue, Yellow, Green, Purple, Orange, Pink, White
- 12/24-hour, AM/PM indicator, seconds, blinking colon
- Size and brightness sliders
- Show/hide the background panel and unlit segments (off = digits only)
- Burn-in protection: the clock glides to a new spot every minute

## Uninstall
`bash uninstall.sh`
