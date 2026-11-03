#!/usr/bin/env bash
# omarchy-plasma uninstaller: restore Omarchy's auto-login and remove the config changes.
#
# Usage:
#   ./uninstall.sh [--remove-packages] [--dry-run]
#
#   --remove-packages   Also remove the Plasma packages (pacman -Rs). Off by default,
#                       because some of them may be used by other apps you installed.
#   --dry-run           Show what would be done without changing anything
#
# Your kitty color theme (the BEGIN_KITTY_THEME block) is left alone; delete that
# block from ~/.config/kitty/kitty.conf if you want kitty to follow Omarchy's theme again.

set -euo pipefail

REMOVE_PKGS=0
DRY_RUN=0
SDDM_OVERRIDE="/etc/sddm.conf.d/zz-local.conf"
KITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
BTOP_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/btop/btop.conf"
# shellcheck disable=SC2016  # kitty expands this variable, not the shell
INCLUDE_LINE='include ${XDG_CURRENT_DESKTOP}.conf'
PKGS=(plasma-desktop konsole dolphin kscreen plasma-nm plasma-pa kde-gtk-config plasma-meta)

ok()   { printf '  ✓ %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*"; }
run()  { if (( DRY_RUN )); then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }

while (( $# )); do
  case "$1" in
    --remove-packages) REMOVE_PKGS=1 ;;
    --dry-run)         DRY_RUN=1 ;;
    -h|--help)         sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if { : < /dev/tty; } 2>/dev/null; then TTY_IN=/dev/tty; else TTY_IN=/dev/stdin; fi

(( EUID != 0 )) || { echo "Run as your normal user, not root." >&2; exit 1; }

echo "==> Login screen"
if [[ -f "$SDDM_OVERRIDE" ]]; then
  run sudo rm -f "$SDDM_OVERRIDE"
  ok "Removed $SDDM_OVERRIDE (Omarchy auto-login restored)"
else
  ok "No SDDM override found"
fi

echo "==> Kitty"
if [[ -f "$KITTY_DIR/kitty.conf" ]] && grep -qxF "$INCLUDE_LINE" "$KITTY_DIR/kitty.conf"; then
  if (( DRY_RUN )); then
    echo "  [dry-run] remove the per-desktop include from kitty.conf"
  else
    # Drop the include line and the comment the installer put above it.
    grep -vxF "$INCLUDE_LINE" "$KITTY_DIR/kitty.conf" \
      | grep -vxF '# Per-desktop overrides (added by omarchy-plasma)' > "$KITTY_DIR/kitty.conf.tmp"
    mv "$KITTY_DIR/kitty.conf.tmp" "$KITTY_DIR/kitty.conf"
  fi
  ok "Removed per-desktop include"
fi
for f in KDE.conf KDE.conf.bak Hyprland.conf; do
  if [[ -f "$KITTY_DIR/$f" ]]; then run rm -f "$KITTY_DIR/$f"; ok "Removed $f"; fi
done

echo "==> Desktop folder"
USER_DIRS="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
DESKTOP_MARKER="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-plasma/desktop-was-home"
if [[ -f "$DESKTOP_MARKER" ]]; then
  # Only undo what the installer did: point the desktop back at the home folder.
  if command -v xdg-user-dirs-update >/dev/null; then
    run xdg-user-dirs-update --set DESKTOP "$HOME"
  else
    # shellcheck disable=SC2016  # user-dirs.dirs stores a literal $HOME
    run sed -i 's|^XDG_DESKTOP_DIR=.*|XDG_DESKTOP_DIR="$HOME/"|' "$USER_DIRS"
  fi
  run rm -f "$DESKTOP_MARKER"
  run rmdir --ignore-fail-on-non-empty "$(dirname "$DESKTOP_MARKER")"
  ok "Desktop points at your home folder again"
  # Remove ~/Desktop only if it's empty, so nothing you saved there is lost.
  if [[ -d "$HOME/Desktop" ]] && [[ -z "$(ls -A "$HOME/Desktop")" ]]; then
    run rmdir "$HOME/Desktop"
    ok "Removed the empty ~/Desktop folder"
  elif [[ -d "$HOME/Desktop" ]]; then
    warn "Kept ~/Desktop because it has files in it"
  fi
else
  ok "Desktop folder wasn't changed by the installer"
fi

echo "==> btop"
if [[ -f "$BTOP_CONF" ]] && grep -q '^color_theme = "TTY"' "$BTOP_CONF"; then
  run sed -i 's/^color_theme = .*/color_theme = "current"/' "$BTOP_CONF"
  ok "btop back on Omarchy's theme"
fi

if (( REMOVE_PKGS )); then
  echo "==> Plasma packages"
  INSTALLED=()
  for p in "${PKGS[@]}"; do pacman -Qq "$p" &>/dev/null && INSTALLED+=("$p"); done
  if (( ${#INSTALLED[@]} )); then
    run sudo pacman -Rs "${INSTALLED[@]}" < "$TTY_IN"
  else
    ok "None installed"
  fi
fi

echo
echo "Done. Reboot to go straight back into Omarchy."
