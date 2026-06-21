#!/usr/bin/env bash
set -euo pipefail

APP_DEST="$HOME/Applications/ScreenTurn.app"
CLI_DEST="$HOME/.local/bin/screenturn"
CLI_ALIAS_DEST="$HOME/.local/bin/st"
PATH_BLOCK_START="# >>> ScreenTurn PATH >>>"
PATH_BLOCK_END="# <<< ScreenTurn PATH <<<"

remove_path_block() {
  local shell_file="$1"
  local tmp_file

  [[ -f "$shell_file" ]] || return 0

  tmp_file="$(mktemp)"
  awk -v start="$PATH_BLOCK_START" -v end="$PATH_BLOCK_END" '
    $0 == start { skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping { print }
  ' "$shell_file" > "$tmp_file"

  if ! cmp -s "$shell_file" "$tmp_file"; then
    mv "$tmp_file" "$shell_file"
    echo "Removed ScreenTurn PATH block from $shell_file"
  else
    rm -f "$tmp_file"
  fi
}

rm -rf "$APP_DEST"
rm -f "$CLI_DEST"

if [[ -L "$CLI_ALIAS_DEST" && "$(readlink "$CLI_ALIAS_DEST")" == "$CLI_DEST" ]]; then
  rm -f "$CLI_ALIAS_DEST"
  echo "Removed $CLI_ALIAS_DEST"
else
  echo "Skipped $CLI_ALIAS_DEST because it is not a ScreenTurn symlink"
fi

remove_path_block "$HOME/.zprofile"
remove_path_block "$HOME/.zshrc"
remove_path_block "$HOME/.bash_profile"
remove_path_block "$HOME/.bashrc"
remove_path_block "$HOME/.profile"

echo "Removed $APP_DEST"
echo "Removed $CLI_DEST"
echo "Config preserved at: $HOME/Library/Application Support/ScreenTurn/config.json"
