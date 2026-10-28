# MacKbdSwitcher

[![Downloads](https://img.shields.io/github/downloads/FrankieMa77/MacKbdSwitcher/total)](https://github.com/FrankieMa77/MacKbdSwitcher/releases)
[![Release](https://img.shields.io/github/v/release/FrankieMa77/MacKbdSwitcher)](https://github.com/FrankieMa77/MacKbdSwitcher/releases/latest)
![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5-orange)

Instant keyboard layout switching with the 🌐 Globe key on macOS: no popup, no delay.

## The problem

On recent macOS versions, pressing the 🌐 Globe key to change the input source opens a language picker in the middle of the screen, and the switch lands one to two seconds later. If you type fast in several languages, the letters typed right after the tap come out in the old layout or get lost.

## What it does

MacKbdSwitcher is a small menu bar app (the app itself is named **MacKbdGlobe**). A short tap on 🌐 switches the keyboard layout at once, without the popup.

- Works with the built-in MacBook keyboard and the Magic Keyboard with the 🌐 key.
- One tap switches to the layout you used before, so tap, tap toggles between your two languages.
- Quick taps in a row step further through your layouts (third, fourth…). Wherever you stop becomes the new pair with the layout you started from.
- Leaves 🌐 shortcuts alone. Fn+Delete, Fn+arrows, 🌐+E, combinations with ⌘ ⌥ ⌃ ⇧, and presses longer than 0.5 s do not switch.
- Shows the current layout in the menu bar as a native-style badge (EN, RU, PL…). Click it to pick a layout directly.
- A subtle click on every switch. Turn it off with **Click Sound** in the menu.
- Typing statistics in the menu: characters typed per language today and all time, with totals.
- Optional Open at Login.
- No network access, no third-party code.

Privacy: the statistics are counts per language, stored only on your Mac. The app never records which keys you press or what you type, and it does not count in password fields. Reset them any time from the menu.

How it works: the system's own 🌐 action is set to "Do Nothing", so macOS shows no popup. The app reads the 🌐 key directly from the keyboard through IOKit HID and switches the layout with the Text Input Sources API.

## Requirements

- macOS 14 or later on Apple Silicon
- An Apple keyboard with the 🌐/Fn key

## Installation

1. Download the latest `MacKbdGlobe-<version>.dmg` from [Releases](https://github.com/FrankieMa77/MacKbdSwitcher/releases/latest).
2. Open the dmg and drag **MacKbdGlobe** to **Applications**.
3. Open MacKbdGlobe from Applications. The app is not notarized by Apple, so macOS blocks the first launch: go to **System Settings → Privacy & Security** and click **Open Anyway** next to MacKbdGlobe.
4. Allow keyboard access: **System Settings → Privacy & Security → Input Monitoring** → turn on **MacKbdGlobe**. Choose **Quit & Reopen** if macOS asks.
5. Turn off the system's own Globe action: **System Settings → Keyboard → "Press 🌐 key to"** → **Do Nothing**. Leave **Keyboard Shortcuts → Modifier Keys** set to "🌐 Globe", so Fn shortcuts keep working.
6. Optional: click the layout in the menu bar and turn on **Open at Login**.

The menu shows a hint if Input Monitoring is missing or the 🌐 key is not set to "Do Nothing".

## Build from source

Requires the Xcode command line tools.

```sh
./build.sh
```

This produces `build/MacKbdGlobe.app` and `dist/MacKbdGlobe-<version>.dmg`. The app is signed with `SIGN_IDENTITY` if set, otherwise with a self-signed "MacKbdSwitcher" certificate, otherwise ad-hoc. Run `tools/make-cert.sh` once to create that certificate in your login keychain; a stable signature lets macOS keep the Input Monitoring permission across rebuilds.

## Uninstall

Quit MacKbdGlobe from its menu, delete it from Applications, and remove it from **Privacy & Security → Input Monitoring**. Set "Press 🌐 key to" back to "Change Input Source" if you want the system behaviour again.

## Disclaimer

MacKbdSwitcher is free and will always be free.

The software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and non-infringement. You use it entirely at your own risk. In no event shall the author be liable for any claim, loss or damage of any kind whatsoever, whether direct, indirect, incidental or consequential, arising from the use of or inability to use the software.
