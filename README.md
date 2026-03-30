# dotfiles

Personal macOS setup — one command to bootstrap a new machine.

## Fresh Install

```bash
git clone https://github.com/rcchao/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

## Structure

```
~/dotfiles/
├── .zshrc
├── .zprofile
├── .config/
│   ├── aerospace/
│   ├── kitty/
│   ├── mpv/
│   ├── presenterm/
│   ├── ghostty/
│   ├── yabai/
│   ├── skhd/
├── vscode/
│   ├── setup.sh
│   ├── settings.json
│   └── keybindings.json
├── macos/
│   └── defaults.sh
├── Brewfile
├── install.sh
├── POST_INSTALL.md
└── README.md
```

## Adding New Dotfiles

```bash
mv ~/.config/newapp ~/dotfiles/.config/newapp
ln -sf ~/dotfiles/.config/newapp ~/.config/newapp
```

Then add the entry to `install.sh` arrays so it gets linked on fresh machines.

## Updating

Edit files anywhere (`~/.zshrc` and `~/dotfiles/.zshrc` are the same file since they're symlinked), then:

```bash
cd ~/dotfiles
git add -A && git commit -m "update" && git push
```