# ScreenTurn

> **English** | [简体中文](README.md)

ScreenTurn is a lightweight macOS menu bar app for toggling a display between landscape and portrait rotation.

It keeps the original script-friendly workflow, but wraps it in a small native app with:

- Global hotkey toggle
- Configurable shortcut
- Menu bar toggle
- Restore last display state
- Launch at login switch
- CLI helper: `screenturn`
- Short CLI alias: `st`

ScreenTurn uses [`displayplacer`](https://github.com/jakehilborn/displayplacer) to apply display rotation safely.

## GitHub Releases

Release archives contain the ARM64 (Apple Silicon) app, `screenturn`, the `st` alias, and a one-command installer. They do not require Xcode Command Line Tools.

```bash
unzip ScreenTurn-<version>-macos.zip
cd ScreenTurn-<version>
./install.sh
```

The installer checks for `displayplacer`, installs it with Homebrew when available, installs the app and CLI, and updates the shell `PATH` when needed. Each release also includes a `.sha256` checksum file.

The GitHub Actions workflows run tests and create a downloadable package for every push and pull request. Publishing a GitHub Release attaches the versioned archive and checksum automatically.

Until a Developer ID certificate and notarization credentials are configured, release builds are unsigned. macOS may ask for confirmation the first time an app downloaded from GitHub is opened.

## Source Requirements

- macOS 13 or newer
- Xcode Command Line Tools
- Homebrew `displayplacer`

```bash
brew install displayplacer
```

## Build

```bash
./scripts/build-app.sh
```

The app will be built at:

```text
build/ScreenTurn.app
```

Create a distributable archive from a source checkout:

```bash
APP_VERSION=0.1.0 ./scripts/package.sh
```

The archive and checksum are written to `dist/`.

## Test

```bash
./scripts/test.sh
```

The self-test target avoids XCTest so the project can be checked on Macs that only have Xcode Command Line Tools installed.

## App Icon

The primary icon preserves the original ScreenTurn double-display artwork in [assets/icon-source/ScreenTurn-original-art.png](assets/icon-source/ScreenTurn-original-art.png). [scripts/render-icon.swift](scripts/render-icon.swift) places it on a clean macOS white tile before the `.icns` is generated.

Rebuild the committed macOS icon after changing it:

```bash
./scripts/build-icon.sh
```

## Install

```bash
./scripts/install.sh
```

The installer will:

- Build and install `ScreenTurn.app`
- Install `screenturn` and the short alias `st`
- Install `displayplacer` with Homebrew if it is missing
- Add `~/.local/bin` to common shell startup files if needed

This installs:

```text
~/Applications/ScreenTurn.app
~/.local/bin/screenturn
~/.local/bin/st
```

Set `SCREENTURN_SKIP_DEPS=1` to skip automatic dependency installation. Set `SCREENTURN_SKIP_PATH_UPDATE=1` to skip shell `PATH` updates.

Then run setup once:

```bash
st doctor
st s
st -n
open ~/Applications/ScreenTurn.app
```

If you have multiple displays, inspect detected IDs and select the intended one:

```bash
st ls
st use <display-id>
```

## Usage

- Press the global shortcut to toggle rotation.
- Left-click the menu bar icon to toggle rotation.
- Right-click or Control-click the menu bar icon to open the menu.
- Use `Launch at Login` in the menu to enable or disable startup launch.

Default shortcut:

```text
Control + Option + Command + R
```

## Configure Shortcut

Open the menu bar menu and choose `Settings...`. Select the target display, then click the shortcut field, press the desired combination, and choose `Save`.

Use the refresh button beside the display list when monitors are connected or disconnected. Saving a newly selected display refreshes its stored rotation, resolution, refresh rate, color depth, scaling, and origin values.

ScreenTurn requires at least one modifier key and temporarily disables the active global shortcut while the settings window is open, so recording a new combination cannot rotate the display accidentally.

For advanced editing, open the config from the menu:

```text
Open Config
```

Or open it directly:

```bash
open "$HOME/Library/Application Support/ScreenTurn/config.json"
```

Edit the `hotKey` section:

```json
{
  "hotKey": {
    "key": "R",
    "modifiers": ["control", "option", "command"]
  }
}
```

Supported modifiers:

```text
control, option, shift, command
```

Supported keys include letters, numbers, arrows, function keys, `space`, `tab`, `return`, `escape`, and `delete`.

After editing, choose:

```text
Reload Config
```

## CLI

```bash
st             # toggle rotation
st t           # toggle rotation
st s           # detect current display and write config
st s <id>      # write config for a specific display
st use <id>    # select a specific detected display
st use --force <id> # save a display ID when detection is unavailable
st restore     # restore the display state before the last toggle
st status      # show config and detected displays
st ls          # alias for status
st doctor      # check readiness before first trial
st path        # print config path
st open        # open config file
st -n          # dry run: preview displayplacer command
st -n restore  # dry run: preview the restore command
st help        # show help
```

The long command still works:

```bash
screenturn toggle
screenturn setup
screenturn status
```

Recommended first trial:

```bash
st doctor      # check displayplacer, config, hotkey, display match
st s           # auto-detect and save target display
st ls          # confirm the starred display is correct
st -n          # preview the displayplacer command
st             # apply the toggle
```

After a successful toggle, ScreenTurn saves the prior display state. Use `Restore Last Rotation` in the menu or `st restore` to return to it. The restore entry is cleared after it succeeds or after selecting a different display.

## Config

ScreenTurn stores config at:

```text
~/Library/Application Support/ScreenTurn/config.json
```

For development or troubleshooting, you can override the config directory:

```bash
SCREENTURN_CONFIG_DIR=/tmp/screenturn-config st doctor
```

Example:

```json
{
  "colorDepth": 8,
  "displayID": "7787EBB5-2CC6-4199-AF58-5836F504166D",
  "hertz": 60,
  "hotKey": {
    "key": "R",
    "modifiers": [
      "control",
      "option",
      "command"
    ]
  },
  "landscapeDegree": 0,
  "landscapeResolution": "1920x1080",
  "origin": "(0,0)",
  "portraitDegree": 270,
  "portraitResolution": "1080x1920",
  "scaling": "on"
}
```

## Notes

If ScreenTurn picks the wrong display in a multi-display setup, run:

```bash
st ls
st use <display-id>
```

You can use a detected persistent, contextual, or serial display ID. ScreenTurn stores the persistent ID in config.

## Uninstall

```bash
./scripts/uninstall.sh
```

The uninstall script preserves your config file.
