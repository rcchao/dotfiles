#!/bin/bash
# Symlink VS Code settings and install CLI command
set -e

DOTFILES_DIR="$HOME/dotfiles"
VSCODE_DIR="$HOME/Library/Application Support/Code/User"

mkdir -p "$VSCODE_DIR"

# Symlink settings.json
if [[ -f "$DOTFILES_DIR/vscode/settings.json" ]]; then
  ln -sf "$DOTFILES_DIR/vscode/settings.json" "$VSCODE_DIR/settings.json"
  echo "  Linked VS Code settings.json"
fi

# Symlink keybindings.json
if [[ -f "$DOTFILES_DIR/vscode/keybindings.json" ]]; then
  ln -sf "$DOTFILES_DIR/vscode/keybindings.json" "$VSCODE_DIR/keybindings.json"
  echo "  Linked VS Code keybindings.json"
fi

# Install 'code' CLI in PATH
CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
if [[ -f "$CODE_BIN" ]]; then
  sudo ln -sf "$CODE_BIN" /usr/local/bin/code 2>/dev/null || true
  echo "  Installed 'code' command in PATH"
else
  echo "  VS Code not found — install it first, then re-run"
fi