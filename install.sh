#!/bin/bash
set -e

DOTFILES_DIR="$HOME/dotfiles"

# ── Colors ──────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[done]${NC} $1"; }
warn()    { echo -e "${YELLOW}[skip]${NC} $1"; }

# ── 1. Xcode CLI Tools ─────────────────────────────────────────────
if ! xcode-select -p &>/dev/null; then
  info "Installing Xcode Command Line Tools..."
  xcode-select --install
  info "Waiting for Xcode CLI tools to finish installing..."
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
  success "Xcode CLI tools installed"
else
  warn "Xcode CLI tools already installed"
fi

# ── 2. Homebrew ─────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for Apple Silicon
  if [[ $(uname -m) == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  warn "Homebrew already installed"
fi

# ── 3. Brew Bundle ──────────────────────────────────────────────────
if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
  info "Installing packages from Brewfile..."
  brew bundle --file="$DOTFILES_DIR/Brewfile"
  success "Brew bundle complete"
else
  warn "No Brewfile found at $DOTFILES_DIR/Brewfile"
fi

# ── 4. Symlink Dotfiles ────────────────────────────────────────────
info "Symlinking dotfiles..."

# Files in ~/
HOME_FILES=(
  ".zshrc"
  ".zprofile"
)

# Directories in ~/.config/
CONFIG_DIRS=(
  "aerospace"
  "kitty"
  "mpv"
  "presenterm"
  "starship"
)

for f in "${HOME_FILES[@]}"; do
  target="$DOTFILES_DIR/$f"
  link="$HOME/$f"

  if [[ -e "$link" && ! -L "$link" ]]; then
    warn "Backing up existing $link to $link.bak"
    mv "$link" "$link.bak"
  fi

  ln -sf "$target" "$link"
  success "Linked $link"
done

mkdir -p "$HOME/.config"
for d in "${CONFIG_DIRS[@]}"; do
  target="$DOTFILES_DIR/.config/$d"
  link="$HOME/.config/$d"

  if [[ -e "$link" && ! -L "$link" ]]; then
    warn "Backing up existing $link to $link.bak"
    mv "$link" "$link.bak"
  fi

  ln -sfn "$target" "$link"
  success "Linked $link"
done

# ── 5. VS Code Setup ───────────────────────────────────────────────
info "Setting up VS Code..."
bash "$DOTFILES_DIR/vscode/setup.sh"

# ── 6. macOS Defaults ──────────────────────────────────────────────
info "Applying macOS defaults..."
bash "$DOTFILES_DIR/macos/defaults.sh"
success "macOS defaults applied"

# ── 7. Git Auth ─────────────────────────────────────────────────────
if ! gh auth status &>/dev/null; then
  info "Authenticating with GitHub..."
  gh auth login
else
  warn "Already authenticated with GitHub"
fi

# Ensure default rebase editor is vim:
git config --global core.editor "vim"

# ── 8. Done ─────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Manual steps remaining — see POST_INSTALL.md"
echo "You may want to restart your shell: exec zsh"