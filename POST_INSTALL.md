# Post-Install Manual Steps

These steps require manual interaction and can't be fully automated.

## Permissions (System Settings > Privacy & Security)

- [ ] **Aerospace** — grant Accessibility permission
- [ ] **Slack** — grant Screen Recording + Notifications
- [ ] **Raycast** — grant Accessibility permission

## Raycast

- [ ] Open Raycast settings
- [ ] Set hotkey to `Cmd + Space`
- [ ] Verify Spotlight hotkey is disabled (should be handled by `defaults.sh`)

## Ghostty

- [ ] Open Ghostty, hit `Cmd + ,` to create config
- [ ] Config should already be symlinked — verify `theme = Catppuccin Mocha` is set

## VS Code / Cursor

- [ ] Open each IDE
- [ ] Ensure Cursor imports settings from VSCode
- [ ] Verify font is set to `FiraCode Nerd Font` (should be in synced settings.json)
- [ ] If `code` command not working: Cmd+Shift+P → "Shell Command: Install 'code' command in PATH"

## Chrome

- [ ] Confirm that it's set as default browser (defaultbrowser should have handled this)
- [ ] Sign in to Google account

## Notifications

- [ ] Slack: In-app settings → ensure notifications are enabled
- [ ] System Settings → Notifications → verify Slack is allowed