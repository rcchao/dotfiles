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
alias zshrestart="source ~/.zshrc"
alias zshconfig="open ~/.zshrc"
alias yabaiconfig="open ~/.config/yabai/yabairc"
alias yabairestart="yabai --restart-service"
alias skhdconfig="open ~/.config/skhd/skhdrc"
alias skhdrestart="skhd --restart-service"
alias aerospaceconfig="cd ~/.config/aerospace && code aerospace.toml"
alias brewfile="cd ~ && open Brewfile"
alias brewupdate="brew bundle install --no-upgrade && brew bundle install" # install taps first before brews
alias gcane="git commit --amend --no-edit"

alias present="cd ~/Desktop/repos/config-presentation && presenterm --publish-speaker-notes -x presentation.md"
alias speakernotes="cd ~/Desktop/repos/config-presentation && presenterm --listen-speaker-notes presentation.md"

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