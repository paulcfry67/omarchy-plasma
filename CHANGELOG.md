# Changelog

All notable changes to omarchy-plasma are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Known issues

- **Copy and paste from the host doesn't reach Wayland apps in the Omarchy session (VMware).** With open-vm-tools, text copied on the host arrives on the guest's X11 (XWayland) clipboard, but Hyprland doesn't pass it on to native Wayland apps such as kitty, so pasting there fails. In the Plasma session it works, because KWin keeps the X11 and Wayland clipboards in sync. This is a Hyprland and open-vm-tools limitation rather than something this installer changes. Workaround in Omarchy: `xclip -o -selection clipboard | wl-copy`.

## [1.3.0] - 2026-11-02

### Fixed

- **Plasma's desktop showed every folder in the home folder.** Omarchy sets `XDG_DESKTOP_DIR="$HOME/"` in `~/.config/user-dirs.dirs`, because Hyprland has no desktop icons. Plasma's desktop displays whatever folder is registered as the Desktop, so Documents, Downloads, Projects and the rest appeared on it as real folders, not shortcuts. The installer now creates `~/Desktop` and registers it with `xdg-user-dirs-update`, so the desktop starts empty, as on Windows. It only does this when the desktop currently points at the home folder, and leaves a marker so `uninstall.sh` can point it back. The uninstaller removes `~/Desktop` only if it's empty. Skip this step with `--no-desktop-folder`. Takes effect immediately, without logging out.

## [1.2.0] - 2026-11-02

### Fixed

- **Login screen too large in a VMware VM.** Omarchy runs the SDDM login screen on its own Hyprland compositor (`/etc/sddm.conf.d/10-wayland.conf` and `/usr/share/sddm/hyprland.lua`). That config sets no monitor scale, so Hyprland picks one from the size the display reports. A real monitor reports its true size and gets 1x, but VMware's virtual display reports a misleading one, so Hyprland chose 2x and the login screen ran off the bottom of the window. A user's own Hyprland monitor setting doesn't reach the login screen, which runs separately. The installer now runs the login screen on KWin, which comes with Plasma, by adding a `[Wayland] CompositorCommand` line to `zz-local.conf`. Verified on Omarchy 4.0.6 in VMware Workstation. Removing `zz-local.conf` (as `uninstall.sh` does) restores Omarchy's login screen.

## [1.1.0] - 2026-11-01

### Added

- `kitty` is now installed with Plasma. Omarchy 4 ships `foot` as its default terminal, so on a fresh install the kitty settings and theme had nothing to apply to. `uninstall.sh --remove-packages` leaves kitty in place.
- The README and the installer's closing message give a `curl` command for the uninstaller, for installs that never cloned the repo.

### Fixed

- Dry-run output reported steps as done (for example "✓ Packages installed"). Dry-run lines now read "~ would: …".

## [1.0.0] - 2026-11-01

First release: `install.sh` and `uninstall.sh`, which add a KDE Plasma (Wayland) session alongside Omarchy's Hyprland.

### Problems this release solves

These came up while setting up Plasma by hand alongside Omarchy 4.0.6. Each is now handled by the installer.

- **No way to choose Plasma at login.** Omarchy's SDDM auto-logs into `omarchy.desktop` with a login theme that has no session menu. The installer adds `/etc/sddm.conf.d/zz-local.conf`, which turns off auto-login and switches to the Breeze theme, so the session can be picked at login. Using a separate file means Omarchy updates to its own SDDM files don't undo it.
- **Plasma crashed when started from a text console.** With Hyprland running, `startplasma-wayland` on a TTY failed with `plasmashell` segfaults and "requesting unexisting screen", because both sessions share the user's systemd and D-Bus services, which Omarchy had already set up for Hyprland. The fix is to always start Plasma from the login screen, and the README and installer now say so.
- **kitty had no title bar, borders or resize handles in Plasma.** Omarchy sets `hide_window_decorations` in `/etc/xdg/kitty/kitty.conf`. The installer adds a per-desktop include (`include ${XDG_CURRENT_DESKTOP}.conf`), so Plasma gets decorations and a 128×32 default size while Omarchy stays unchanged.
- **The terminal showed only shades of gray.** Some Omarchy themes are near-monochrome, which made `ls`, `btop` and other tools look colorless. The installer applies a kitty color theme (Adwaita Darker by default; change it with `--kitty-theme`).
- **btop stayed monochrome after the terminal had colors.** btop's `current` theme holds fixed RGB values from the Omarchy theme. The installer switches btop to its built-in `TTY` theme, which follows the terminal's colors.

### Fixed during testing

- False "No omarchy.desktop session found" warning. The check required the file in *both* possible locations; Omarchy installs it only in `/usr/local/share/wayland-sessions/`.
- The installer exited when no terminal was attached (no `/dev/tty`). Prompts now fall back to standard input.
- `--help` failed when the script was piped from `curl`, because it read its own file for the help text.
- A repeat install left `KDE.conf.bak` behind after uninstalling. `uninstall.sh` now removes it.

[Unreleased]: https://github.com/paulcfry67/omarchy-plasma/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/paulcfry67/omarchy-plasma/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/paulcfry67/omarchy-plasma/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/paulcfry67/omarchy-plasma/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/paulcfry67/omarchy-plasma/releases/tag/v1.0.0
