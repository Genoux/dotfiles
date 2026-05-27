## Learned User Preferences

- In AGS, system tray primary (left) click should focus or raise the application; secondary (right) click opens the tray menu or popover, not primary.
- For the AGS media player, update the displayed MPRIS source from explicit interaction (bar controls, tray raise) and playback-driven ordering—not from Hyprland window focus alone.
- Do not restart AGS when changing wallpaper; wallpaper or matugen theme updates are not a reason to bounce the shell here.
- Do not reintroduce wallust or a dual matugen-plus-wallust terminal pipeline unless explicitly requested; a previous wallust-style change was reverted.

## Learned Workspace Facts

- AGS/Astal shell config for this setup lives under `stow/ags/.config/ags/` in the dotfiles repo.
- Hyprland configuration is maintained under `stow/hypr/.config/hypr/`.
- A systemd user service is used to manage and restart AGS during dotfiles package or service workflows.
