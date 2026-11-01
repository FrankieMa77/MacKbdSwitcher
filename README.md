# MacKbdSwitcher

[![Downloads](https://img.shields.io/github/downloads/FrankieMa77/MacKbdSwitcher/total)](https://github.com/FrankieMa77/MacKbdSwitcher/releases)
[![Version](https://img.shields.io/badge/dynamic/xml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fkirill-grigorchuk%2FMacKbdSwitcher%2Fmain%2FResources%2FInfo.plist&query=%2F%2Fkey%5B.%3D'CFBundleShortVersionString'%5D%2Ffollowing-sibling%3A%3Astring%5B1%5D&label=version&prefix=v&color=orange)](Resources/Info.plist)
![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5-orange)

Instant keyboard layout switching with the 🌐 Globe key on macOS: no popup, no delay. Plus automatic correction of words typed in the wrong layout (English, Polish, Russian).

## What's new in 0.5

- **Auto-Correct Layout.** `ghbdtn` becomes `привет`, `руддщ` becomes `hello`, right when you finish the word. Off by default, turn it on in the menu.
- **⇧ + 🌐** converts the current or the last word on demand, and undoes an auto-correction.
- **Backspace right after an auto-correction** restores the original word and teaches the app to leave it alone.
- **Languages per layout**: English, Polish and Russian; a Latin layout such as Polish Pro can be judged as both English and Polish.
- Polish ⌥ letters (ą ę ł ż ź ś ć ń ó) are part of the word.

Version 0.5 is available from source only: the published releases end at 0.4.0. See [Build from source](#build-from-source).

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
- Book Progress: your all-time characters as a share of 10 famous long books, from The Hobbit to War and Peace and the whole Harry Potter series, each with a progress bar.
- Auto-Correct Layout (optional, off by default): see below.
- Optional Open at Login.
- No network access, no third-party code.

## Auto-Correct Layout

Typed `ghbdtn` instead of `привет`? Turn on **Auto-Correct Layout** in the menu and the word fixes itself when you press Space, Return or Tab: the app erases it, types it again in the right layout and switches the layout, so you keep typing in the language you meant. Works for English, Polish and Russian.

- The decision is made per word, on the word boundary. Words shorter than 3 letters, words with digits, `iPhone`-style mixed case, URLs and file names are left alone. A comma, period or bracket right after the word is handled (`ghbdtn,` becomes `привет,`).
- **Backspace right after an auto-correction undoes it**: the original text comes back, the layout returns, and the word is remembered as an exception so it is never auto-corrected again. **Clear Learned Exceptions…** in the menu forgets them.
- **⇧ + 🌐** converts the word you are typing, or the word you just finished, on demand. Pressed right after an auto-correction it undoes it. It works even with Auto-Correct turned off.
- **Languages per layout.** A layout can carry several languages. By default a layout gets its own language (for example Polish for Polish Pro, Russian for Russian) and every Latin layout also gets English. **Auto-Correct Languages** in the menu lists every enabled layout with check marks for the languages it should be judged by (Latin layouts: English, Polski; Cyrillic layouts: Русский). Unchecking the last language takes that layout out of Auto-Correct completely. A word is converted to the best-scoring layout of the other alphabet among all your enabled layouts; on a tie the layout you used more recently wins. Layouts with the same alphabet are never converted into each other.
- **Option letters.** Letters typed with ⌥ (Polish Pro: ą ę ł ż ź ś ć ń ó) count as normal letters of the word, so Polish words with diacritics are not touched. A word with a ⌥ letter that the other layout cannot produce is never converted. Any other ⌥ key press ends the current word.
- If Auto-Correct is on but no two enabled layouts form a supported pair (a Latin and a Cyrillic layout with language data), the menu shows a greyed-out hint: "Auto-Correct: no supported layout pair".
- Return and Tab corrections cannot be undone with Backspace, and ⇧ + 🌐 does not reach back across a Return, because the text has already moved on (a chat message may be sent).
- Terminal, iTerm2, Warp, Ghostty, Alacritty and kitty are never touched. Nothing is auto-corrected while macOS Secure Input is active (password fields).
- Needs the **Accessibility** permission to watch word boundaries and retype text. Without it the 🌐 key still works as before.

How the word is judged: each language has a small table of letter-triple (trigram) probabilities. The app maps your key presses through both layouts, scores both readings against the tables, and converts only when the other reading is clearly more plausible. macOS's built-in spell checker (on this Mac, nothing is sent anywhere) confirms valid words, so real words in the current language are not converted. Layouts are read from the system, so any Latin and Cyrillic layouts work, including Russian, Russian – PC and Polish Pro.

Quality on test corpora of 2,000 frequent English, Polish and Russian words that were held out of the tables, without the spell checker: about 98% of words typed in the wrong layout are converted, and 0–0.2% of correctly typed words are wrongly converted. For Polish the conversion rate counts only words that can be typed on both layouts (without ⌥ letters, about 1,100 of 2,000), because the Russian layout has no keys for ą ę ł and the like. Rare names, abbreviations and slang are the usual misses; undo with Backspace teaches the app.

## Privacy

- Statistics are counts per language, stored only on your Mac. They never contain which keys you pressed or what you typed, and nothing is counted in password fields. Reset them any time from the menu.
- While the Accessibility permission is granted, the app watches key presses to know the current word. The current word lives only in memory and is dropped at the end of the word, on a mouse click, an arrow key, a shortcut, a layout or app change, and in password fields. It is never written to disk, logged or sent anywhere, and this works the same whether Auto-Correct is on or off.
- The only text stored on disk is a word you restored with Backspace after an auto-correction (the exception list, up to 1,000 words, stored in the app's preferences). Clear it from the menu.
- No network access at all.

How it works: the system's own 🌐 action is set to "Do Nothing", so macOS shows no popup. The app reads the 🌐 key directly from the keyboard through IOKit HID and switches the layout with the Text Input Sources API. For Auto-Correct it uses an event tap to see key presses and posts the replacement keystrokes.

## Requirements

- macOS 14 or later on Apple Silicon
- An Apple keyboard with the 🌐/Fn key
- For Auto-Correct and ⇧ + 🌐: the Accessibility permission

## Installation

1. Download the latest `MacKbdGlobe-<version>.dmg` from [Releases](https://github.com/FrankieMa77/MacKbdSwitcher/releases/latest) (up to 0.4.0, without Auto-Correct), or [build 0.5 from source](#build-from-source).
2. Open the dmg and drag **MacKbdGlobe** to **Applications**.
3. Open MacKbdGlobe from Applications. The app is not notarized by Apple, so macOS blocks the first launch: go to **System Settings → Privacy & Security** and click **Open Anyway** next to MacKbdGlobe.
4. Allow keyboard access: **System Settings → Privacy & Security → Input Monitoring** → turn on **MacKbdGlobe**. Choose **Quit & Reopen** if macOS asks.
5. Optional, for Auto-Correct Layout and ⇧ + 🌐: **System Settings → Privacy & Security → Accessibility** → turn on **MacKbdGlobe**. The menu shows **Allow Accessibility…** when Auto-Correct is on and the permission is missing. Plain 🌐 switching does not need it.
6. Turn off the system's own Globe action: **System Settings → Keyboard → "Press 🌐 key to"** → **Do Nothing**. Leave **Keyboard Shortcuts → Modifier Keys** set to "🌐 Globe", so Fn shortcuts keep working.
7. Optional: click the layout in the menu bar and turn on **Open at Login**.

The menu shows a hint if Input Monitoring is missing or the 🌐 key is not set to "Do Nothing".

## Build from source

Requires Xcode or the Xcode command line tools.

1. Once, create a self-signed code signing certificate in your login keychain. A stable signature lets macOS keep the Input Monitoring and Accessibility permissions across rebuilds; without it every rebuild asks for them again.

   ```sh
   ./tools/make-cert.sh
   ```

2. Build:

   ```sh
   ./build.sh
   ```

   This produces `build/MacKbdGlobe.app` and `dist/MacKbdGlobe-<version>.dmg`. The app is signed with `SIGN_IDENTITY` if set, otherwise with the self-signed "MacKbdSwitcher" certificate, otherwise ad-hoc. The last lines of the output show the identity used: a SHA-1 means the certificate was found, `-` means ad-hoc.

3. Replace the installed copy and start it:

   ```sh
   pkill -x MacKbdGlobe; sleep 1
   rm -rf /Applications/MacKbdGlobe.app
   ditto build/MacKbdGlobe.app /Applications/MacKbdGlobe.app
   open /Applications/MacKbdGlobe.app
   ```

   After the first install, or after switching from a release build, grant Input Monitoring and Accessibility again (the signature changed). Remove stale MacKbdGlobe entries from those lists with "−" if they remain.

The self-signed certificate is personal and local. Builds signed with it are meant for your own Mac; do not publish them.

Run the tests (Swift Testing, pure logic only) with:

```sh
swift test
```

### Language data

The trigram tables in `Resources/ngrams-en.tsv`, `Resources/ngrams-pl.tsv` and `Resources/ngrams-ru.tsv` are generated by `tools/make-ngrams.swift` from the [FrequencyWords](https://github.com/hermitdave/FrequencyWords) lists by Hermit Dave (`en_50k.txt`, `pl_50k.txt`, `ru_50k.txt`, built from OpenSubtitles 2018), which are licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The frequency lists themselves are not in this repository; the tables and the test word lists in `Tests/KbdCoreTests/Fixtures/corpus-*.txt` derived from them are shared under the same license. Regenerate with:

```sh
swiftc -O tools/make-ngrams.swift -o /tmp/make-ngrams
/tmp/make-ngrams en_50k.txt en Resources/ngrams-en.tsv Tests/KbdCoreTests/Fixtures/corpus-en.txt
/tmp/make-ngrams pl_50k.txt pl Resources/ngrams-pl.tsv Tests/KbdCoreTests/Fixtures/corpus-pl.txt
/tmp/make-ngrams ru_50k.txt ru Resources/ngrams-ru.tsv Tests/KbdCoreTests/Fixtures/corpus-ru.txt
```

Another language is a new table from the same generator (add its alphabet to the generator) plus one line in `SupportedLanguages` (`Sources/Core/Languages.swift`).

The keyboard layout fixtures in `Tests/KbdCoreTests/Fixtures/keymap-*.json` are real layouts, including the ⌥ layers, dumped through `UCKeyTranslate` by `tools/dump-keymap.swift`.

## Uninstall

Quit MacKbdGlobe from its menu, delete it from Applications, and remove it from **Privacy & Security → Input Monitoring** and **Accessibility**. Set "Press 🌐 key to" back to "Change Input Source" if you want the system behaviour again.

## Disclaimer

MacKbdSwitcher is free and will always be free.

The software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and non-infringement. You use it entirely at your own risk. In no event shall the author be liable for any claim, loss or damage of any kind whatsoever, whether direct, indirect, incidental or consequential, arising from the use of or inability to use the software.
