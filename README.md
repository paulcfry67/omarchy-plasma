# omarchy-plasma
Add the option to use a Plasma desktop alongside Omarchy's native Hyprland tiling desktop.

(pfry, 2026-11-01, Initial commit.)

Long time Unix and Linux user here with two years of Arch Linux, btw. I admit that I just can't used to the tiling setup. So I always use the Plasma desktop which is easier for Windows users to slide into. This repo is just one way to get it working in Omarchy and get it working quickly.

No license for now, not really anything original to me here. Developed with help from Claude AI.


Add a **KDE Plasma (Wayland)** session alongside [Omarchy](https://omarchy.org)'s Hyprland desktop, and choose between them at the login screen.

Omarchy stays exactly as it is. This adds Plasma next to it and fixes the rough edges that show up when the two share one user account.

## What it does

| Step | Change |
|---|---|
| Snapshot | Creates a btrfs snapshot named "before omarchy-plasma" with snapper |
| Packages | Installs a lean Plasma set: `plasma-desktop konsole dolphin kscreen plasma-nm plasma-pa kde-gtk-config breeze breeze-gtk` (or `plasma-meta` with `--full`) |
| Login screen | Adds `/etc/sddm.conf.d/zz-local.conf` to turn off auto-login and use the Breeze login theme, which has a session menu |
| Kitty | Gives kitty a title bar, borders and a 128×32 default size **in Plasma only**, via a per-desktop include |
| Kitty colors | Applies the "Adwaita Darker" kitty theme (configurable), because some Omarchy themes are near-monochrome |
| btop | Switches btop to the `TTY` theme so it uses the terminal's colors |

Every step checks before changing anything, so it's safe to run more than once.

## Install

On a fresh or existing Omarchy machine:

```bash
git clone https://github.com/paulcfry67/omarchy-plasma.git
cd omarchy-plasma
./install.sh
```

Or in one line:

```bash
curl -fsSL https://raw.githubusercontent.com/paulcfry67/omarchy-plasma/main/install.sh | bash
```

Then reboot. At the login screen, open the session menu at the bottom-left:

- **Plasma (Wayland)** gives you KDE.
- **Omarchy** gives you your normal Omarchy desktop.

Don't pick plain "Hyprland" or "Hyprland (uwsm)", because those skip Omarchy's session setup.

### Options

```
--full                 Install plasma-meta (complete Plasma) instead of the lean set
--kitty-theme NAME     Kitty color theme to apply (default: "Adwaita Darker")
--no-kitty-theme       Leave kitty following Omarchy's theme
--no-btop              Don't change btop's theme
--no-snapshot          Skip the btrfs snapshot
--dry-run              Show what would happen without changing anything
```

With the curl install, pass options after `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/paulcfry67/omarchy-plasma/main/install.sh | bash -s -- --full --kitty-theme "Tokyo Night"
```

Run `kitten themes` to browse kitty theme names.

## Uninstall

```bash
./uninstall.sh                    # restore auto-login, remove kitty/btop changes
./uninstall.sh --remove-packages  # also remove the Plasma packages
```

The kitty color theme is left in place. Delete the `BEGIN_KITTY_THEME` block in `~/.config/kitty/kitty.conf` if you want kitty to follow Omarchy's themes again. Or roll back the whole machine to the "before omarchy-plasma" snapshot.

## Notes

- **Don't start Plasma from a text console while Hyprland is running.** Both sessions share your user's systemd/D-Bus services, which Omarchy has already set up for Hyprland, so `plasmashell` crashes with "requesting unexisting screen". Always start Plasma from the login screen.
- **Kitty theme applies to both sessions.** It's added to the shared `kitty.conf`, so kitty keeps that theme even when you change themes in Omarchy. Use `--no-kitty-theme` if you'd rather keep Omarchy's theme in kitty.
- **GTK theming.** Plasma's appearance settings can overwrite shared GTK theme files. If Omarchy apps change color after you tweak Plasma, re-pick your theme from the Omarchy menu.
- Tested on Omarchy 4.0.6, Plasma 6.8 and kitty 0.49.

See [docs/manual-setup.md](docs/manual-setup.md) for the step-by-step manual version and the reasoning behind each change.
