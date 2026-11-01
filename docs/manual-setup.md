# KDE Plasma (Wayland) alongside Omarchy

Setup notes for adding a KDE Plasma session next to Omarchy's Hyprland session, with a session picker at login. Tested on Omarchy 4.0.6 with Plasma 6.8 and kitty 0.49.

## 1. Take a snapshot first

Omarchy ships with btrfs snapshots, so make a restore point before changing anything:

```bash
sudo snapper create -d "before plasma"
```

## 2. Install Plasma

A lean Plasma install rather than the full KDE suite:

```bash
sudo pacman -S plasma-desktop konsole dolphin kscreen plasma-nm plasma-pa kde-gtk-config
```

Optional: for the complete Plasma experience (all System Settings modules, power, Bluetooth and so on), install `plasma-meta` instead.

> **Don't test Plasma from a TTY** (`startplasma-wayland` on Ctrl+Alt+F3) while Hyprland is running. Both sessions share the user's systemd/D-Bus services, and Omarchy's session manager has already set them up for Hyprland, so plasmashell crashes with "requesting unexisting screen". Always start Plasma from the login screen.

## 3. Turn off auto-login and get a session picker

Omarchy's SDDM auto-logs into `omarchy.desktop` using its own login theme. Override both with a file that loads last, so Omarchy updates to its own SDDM files don't undo it:

```bash
sudo tee /etc/sddm.conf.d/zz-local.conf <<'EOF'
[Autologin]
User=

[Theme]
Current=breeze
EOF
```

- Empty `User=` disables auto-login.
- The `breeze` theme has a visible session selector (bottom-left). Check it exists first with `ls /usr/share/sddm/themes/`.
- Confirm the sessions are present: `plasma.desktop` in `/usr/share/wayland-sessions/` and `omarchy.desktop` in `/usr/local/share/wayland-sessions/`.

Reboot. At login:

- **Plasma (Wayland)** gives you KDE.
- **Omarchy** gives you the normal Omarchy setup. Don't pick plain "Hyprland" or "Hyprland (uwsm)", because those skip Omarchy's session setup.

`RememberLastSession=true` is already set by Omarchy, so the picker defaults to the last session used.

**To undo:** `sudo rm /etc/sddm.conf.d/zz-local.conf` and reboot.

## 4. Kitty: window decorations and size in Plasma only

Omarchy sets `hide_window_decorations` in `/etc/xdg/kitty/kitty.conf`, so in Plasma kitty has no title bar or borders and can't be resized. `~/.config/kitty/kitty.conf` overrides those defaults, so add a per-desktop include (`XDG_CURRENT_DESKTOP` is `KDE` in Plasma and `Hyprland` in Omarchy):

```bash
echo 'include ${XDG_CURRENT_DESKTOP}.conf' >> ~/.config/kitty/kitty.conf
touch ~/.config/kitty/Hyprland.conf

cat > ~/.config/kitty/KDE.conf <<'EOF'
hide_window_decorations no
remember_window_size no
initial_window_width 128c
initial_window_height 32c
EOF
```

The empty `Hyprland.conf` keeps kitty from complaining about a missing include in Omarchy. Close all kitty windows and reopen to apply.

## 5. Kitty color theme

Some Omarchy themes are near-monochrome, so the terminal palette is all grays. Pick a kitty theme instead:

```bash
kitten themes
```

I chose **Adwaita Darker**. `kitten themes` saves it to `~/.config/kitty/current-theme.conf` and adds this block to the end of `kitty.conf`:

```
# BEGIN_KITTY_THEME
# Adwaita Darker
include current-theme.conf
# END_KITTY_THEME
```

Because it's in the shared `kitty.conf`, it applies in **both** Omarchy and Plasma, and kitty no longer follows Omarchy theme changes. Delete that block to go back to Omarchy's theme.

Quick palette check (should show 16 distinct colors):

```bash
for i in {0..15}; do printf "\e[48;5;${i}m %2d \e[0m" $i; done; echo
```

## 6. btop colors

btop's theme `current` holds fixed RGB values from the Omarchy theme, so it ignores the terminal palette. Switch it to the built-in **TTY** theme, which uses the terminal's colors and so matches the kitty theme:

```bash
sed -i 's/^color_theme = .*/color_theme = "TTY"/' ~/.config/btop/btop.conf
```

Or, in btop, go to Esc → Options → Color theme → TTY. The trade-off is 16 colors rather than smooth graph gradients.

## Files touched

| File | Purpose |
|---|---|
| `/etc/sddm.conf.d/zz-local.conf` | Disable auto-login, Breeze login theme |
| `~/.config/kitty/kitty.conf` | Per-desktop include + kitty theme block |
| `~/.config/kitty/KDE.conf` | Plasma-only kitty settings |
| `~/.config/kitty/Hyprland.conf` | Empty placeholder |
| `~/.config/kitty/current-theme.conf` | Adwaita Darker colors |
| `~/.config/btop/btop.conf` | `color_theme = "TTY"` |
