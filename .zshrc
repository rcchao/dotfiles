# ---------- Brewfile configs -----------
export HOMEBREW_BUNDLE_NO_UPGRADE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1 
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

# --------- Oh My Zsh bootstrap ---------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh

# ---------- General aliases ------------
alias aerospaceconfig="cd ~/.config/aerospace && code aerospace.toml"
alias brewfile="cd ~ && open .Brewfile"
alias brewupdate="brew bundle install --no-upgrade --global && brew bundle install --global" # install taps first before brews
alias dotfiles="cd && code dotfiles"
alias gcane="git commit --amend --no-edit"
alias skhdconfig="open ~/.config/skhd/skhdrc"
alias skhdrestart="skhd --restart-service"
alias yabaiconfig="open ~/.config/yabai/yabairc"
alias yabairestart="yabai --restart-service"
alias zshconfig="open ~/.zshrc"
alias zshrestart="source ~/.zshrc"
alias rp="realpath | pbcopy"

# ------ Better ctrl+r fuzzy find --------
source <(fzf --zsh)

# ------- Better ls (exa is depr)---------
# alias ls="eza --icons=always" # brew install ls
alias ls='lsd --tree --depth 1' # brew install lsd

# ----------- fzf git checkout -----------
gch() {
git checkout $(git branch --all | fzf| tr -d "[[:space:]]")
}

# ----------------- evals ----------------
eval "$(starship init zsh)"

#  ------------ brew install -------------
# Brew install command that installs, appends to Brewfile, then commits
# Usage: bi <package> [--cask]
# Example: bi ripgrep
#          bi --cask figma
bi() {
  if [[ "$1" == "--cask" ]]; then
    brew install --cask "$2"
    printf '\n%s\n' "cask \"$2\"" >> ~/dotfiles/Brewfile
  else
    brew install "$1"
    printf '\n%s\n' "brew \"$1\"" >> ~/dotfiles/Brewfile
  fi
  cd ~/dotfiles && git add Brewfile && git commit -m "add $* to brewfile" && cd -
}