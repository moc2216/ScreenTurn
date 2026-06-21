#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(basename "$SCRIPT_DIR")" == "scripts" && -f "$SCRIPT_DIR/../Package.swift" ]]; then
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  ROOT_DIR="$SCRIPT_DIR"
fi
APP_NAME="ScreenTurn"
APP_DEST="$HOME/Applications/$APP_NAME.app"
CLI_DEST="$HOME/.local/bin/screenturn"
CLI_ALIAS_DEST="$HOME/.local/bin/st"
PATH_BLOCK_START="# >>> ScreenTurn PATH >>>"
PATH_BLOCK_END="# <<< ScreenTurn PATH <<<"
APP_SOURCE=""
CLI_BINARY=""

require_command() {
  local command_name="$1"
  local hint="$2"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required tool: $command_name"
    echo "$hint"
    exit 1
  fi
}

find_displayplacer() {
  if [[ -n "${SCREENTURN_DISPLAYPLACER:-}" && -x "$SCREENTURN_DISPLAYPLACER" ]]; then
    echo "$SCREENTURN_DISPLAYPLACER"
    return 0
  fi

  if command -v displayplacer >/dev/null 2>&1; then
    command -v displayplacer
    return 0
  fi

  for candidate in /opt/homebrew/bin/displayplacer /usr/local/bin/displayplacer; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

install_displayplacer_if_needed() {
  if find_displayplacer >/dev/null; then
    echo "displayplacer is already installed: $(find_displayplacer)"
    return
  fi

  if [[ "${SCREENTURN_SKIP_DEPS:-0}" == "1" ]]; then
    echo "Skipped dependency installation because SCREENTURN_SKIP_DEPS=1"
    return
  fi

  local brew_bin
  if ! brew_bin="$(find_brew)"; then
    echo "Homebrew is required to install displayplacer automatically."
    echo "Install Homebrew from https://brew.sh, then rerun ./scripts/install.sh"
    exit 1
  fi

  echo "Installing displayplacer with Homebrew..."
  "$brew_bin" install displayplacer
}

append_path_block() {
  local shell_file="$1"

  if [[ -f "$shell_file" ]] && grep -Fq "$PATH_BLOCK_START" "$shell_file"; then
    return
  fi

  touch "$shell_file"
  cat >> "$shell_file" <<'SHELL'

# >>> ScreenTurn PATH >>>
if [ -d "$HOME/.local/bin" ]; then
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
fi
# <<< ScreenTurn PATH <<<
SHELL
  echo "Added ~/.local/bin to PATH in $shell_file"
}

ensure_local_bin_on_path() {
  mkdir -p "$HOME/.local/bin"

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac

  if [[ "${SCREENTURN_SKIP_PATH_UPDATE:-0}" == "1" ]]; then
    echo "Skipped PATH update because SCREENTURN_SKIP_PATH_UPDATE=1"
    return
  fi

  case "$(basename "${SHELL:-}")" in
    zsh)
      append_path_block "$HOME/.zprofile"
      append_path_block "$HOME/.zshrc"
      ;;
    bash)
      append_path_block "$HOME/.bash_profile"
      append_path_block "$HOME/.bashrc"
      ;;
    *)
      append_path_block "$HOME/.profile"
      ;;
  esac
}

prepare_payload() {
  local prebuilt_app="$ROOT_DIR/$APP_NAME.app"
  local prebuilt_cli="$ROOT_DIR/bin/screenturn"

  if [[ -d "$prebuilt_app" && -x "$prebuilt_cli" ]]; then
    APP_SOURCE="$prebuilt_app"
    CLI_BINARY="$prebuilt_cli"
    echo "Using prebuilt ScreenTurn release payload"
    return
  fi

  require_command swift "Install Xcode Command Line Tools with: xcode-select --install"
  "$ROOT_DIR/scripts/build-app.sh"

  local bin_dir
  bin_dir="$(cd "$ROOT_DIR" && swift build -c release --show-bin-path)"
  CLI_BINARY="$bin_dir/screenturn"

  if [[ ! -x "$CLI_BINARY" ]]; then
    CLI_BINARY="$bin_dir/ScreenTurnCLI"
  fi

  APP_SOURCE="$ROOT_DIR/build/$APP_NAME.app"
}

require_command ditto "ditto is included with macOS. Check your Command Line Tools installation."
install_displayplacer_if_needed
prepare_payload

mkdir -p "$HOME/Applications"
ensure_local_bin_on_path

rm -rf "$APP_DEST"
ditto "$APP_SOURCE" "$APP_DEST"
install -m 755 "$CLI_BINARY" "$CLI_DEST"

if [[ -e "$CLI_ALIAS_DEST" && ! -L "$CLI_ALIAS_DEST" ]]; then
  echo "Skipped alias $CLI_ALIAS_DEST because a non-symlink file already exists there"
else
  ln -sf "$CLI_DEST" "$CLI_ALIAS_DEST"
  echo "Installed alias $CLI_ALIAS_DEST -> $CLI_DEST"
fi

echo "Installed $APP_DEST"
echo "Installed $CLI_DEST"
echo ""
echo "Next:"
echo "  1. Check readiness: st doctor"
echo "  2. Run setup: st s"
echo "  3. Preview toggle: st -n"
echo "  4. Launch: open '$APP_DEST'"
echo ""
echo "If this terminal still cannot find 'st', open a new terminal or run:"
echo "  source ~/.zprofile  # zsh"
