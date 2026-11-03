#!/usr/bin/env bash
# omarchy-plasma: add a KDE Plasma (Wayland) session alongside Omarchy's Hyprland.
#
# Usage:
#   ./install.sh [options]
#   curl -fsSL https://raw.githubusercontent.com/paulcfry67/omarchy-plasma/main/install.sh | bash
#
# Options:
#   --full                 Install plasma-meta (complete Plasma) instead of the lean package set
#   --kitty-theme NAME     Kitty color theme to apply (default: "Adwaita Darker")
#   --no-kitty-theme       Leave kitty's colors alone (keep following Omarchy's theme)
#   --no-btop              Don't switch btop to the TTY color theme
#   --no-snapshot          Skip the btrfs snapshot
#   --no-desktop-folder    Leave the desktop showing your home folder
#   --dry-run              Show what would be done without changing anything
#   -h, --help             Show this help
#
# Safe to run more than once: every step checks before it changes anything.

set -euo pipefail

VERSION="1.3.0"

# ---------- defaults ----------
FULL=0
KITTY_THEME="Adwaita Darker"
DO_KITTY_THEME=1
DO_BTOP=1
DO_SNAPSHOT=1
DO_DESKTOP=1
DRY_RUN=0

LEAN_PKGS=(plasma-desktop konsole dolphin kscreen plasma-nm plasma-pa kde-gtk-config breeze breeze-gtk kitty)
FULL_PKGS=(plasma-meta konsole dolphin kitty)

SDDM_OVERRIDE="/etc/sddm.conf.d/zz-local.conf"
KITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
BTOP_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/btop/btop.conf"
# shellcheck disable=SC2016  # kitty expands this variable, not the shell
INCLUDE_LINE='include ${XDG_CURRENT_DESKTOP}.conf'

# ---------- output helpers ----------
if [[ -t 1 ]]; then
  BOLD=$'\e[1m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RED=$'\e[31m'; RESET=$'\e[0m'
else
  BOLD=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi
step() { printf '\n%s==> %s%s\n' "$BOLD" "$*" "$RESET"; }
ok()   { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
# did: report a change; in dry-run mode, say it *would* happen instead.
did()  { if (( DRY_RUN )); then printf '  %s~%s would: %s\n' "$YELLOW" "$RESET" "$*"; else ok "$@"; fi; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$*"; }
die()  { printf '%sError:%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

# Run a command, or just print it in dry-run mode.
run() {
  if (( DRY_RUN )); then
    printf '  [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# Write stdin to a root-owned file (or show it in dry-run mode).
write_root_file() {
  local dest="$1" content
  content="$(cat)"
  if (( DRY_RUN )); then
    printf '  [dry-run] would write %s:\n' "$dest"
    printf '%s\n' "$content" | sed 's/^/      /'
  else
    printf '%s\n' "$content" | sudo tee "$dest" >/dev/null
  fi
}

usage() {
  if [[ -f "$0" ]]; then awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
  else echo "See https://github.com/paulcfry67/omarchy-plasma#options"; fi
}

# Prompts (sudo password, pacman questions) must come from the keyboard even when
# this script is piped from curl. Use the terminal if there is one, else stdin.
if { : < /dev/tty; } 2>/dev/null; then TTY_IN=/dev/tty; else TTY_IN=/dev/stdin; fi

# ---------- argument parsing ----------
while (( $# )); do
  case "$1" in
    --full)            FULL=1 ;;
    --kitty-theme)     [[ $# -ge 2 ]] || die "--kitty-theme needs a theme name"; KITTY_THEME="$2"; shift ;;
    --no-kitty-theme)  DO_KITTY_THEME=0 ;;
    --no-btop)         DO_BTOP=0 ;;
    --no-snapshot)     DO_SNAPSHOT=0 ;;
    --no-desktop-folder) DO_DESKTOP=0 ;;
    --dry-run)         DRY_RUN=1 ;;
    -h|--help)         usage; exit 0 ;;
    *)                 die "Unknown option: $1 (try --help)" ;;
  esac
  shift
done

# ---------- preflight ----------
step "omarchy-plasma $VERSION"
(( EUID != 0 )) || die "Run this as your normal user, not root. It will ask for sudo when needed."
command -v pacman >/dev/null || die "pacman not found. This script is for Arch-based Omarchy."
if [[ -d /usr/share/omarchy || -d "$HOME/.local/share/omarchy" ]]; then
  ok "Omarchy detected"
else
  warn "Omarchy not detected. Continuing, but this script is designed for Omarchy."
fi
(( DRY_RUN )) && warn "Dry run: nothing will be changed."

# Ask for sudo once up front (reads the password from the terminal even under curl | bash).
if (( ! DRY_RUN )); then
  # shellcheck disable=SC2024  # redirect is for the password prompt, intended
  sudo -v < "$TTY_IN" || die "sudo is required."
fi

# ---------- 1. snapshot ----------
step "1/7 Snapshot"
if (( ! DO_SNAPSHOT )); then
  warn "Skipped (--no-snapshot)"
elif command -v snapper >/dev/null; then
  if run sudo snapper create -d "before omarchy-plasma"; then
    did "Snapshot \"before omarchy-plasma\" created"
  else
    warn "snapper failed; continuing without a snapshot"
  fi
else
  warn "snapper not found; no snapshot taken"
fi

# ---------- 2. packages ----------
step "2/7 Plasma packages"
if (( FULL )); then PKGS=("${FULL_PKGS[@]}"); else PKGS=("${LEAN_PKGS[@]}"); fi
MISSING=()
for p in "${PKGS[@]}"; do pacman -Qq "$p" &>/dev/null || MISSING+=("$p"); done
if (( ${#MISSING[@]} == 0 )); then
  ok "All packages already installed"
else
  echo "  Installing: ${MISSING[*]}"
  echo "  If pacman asks about conflicts or replacements, read the prompt before answering."
  # stdin from /dev/tty so pacman's prompts work even when piped from curl
  run sudo pacman -S --needed "${MISSING[@]}" < "$TTY_IN"
  did "Packages installed"
fi

# ---------- 3. SDDM session picker ----------
step "3/7 Login screen session picker"
if [[ ! -f /usr/share/wayland-sessions/plasma.desktop ]] && (( ! DRY_RUN )); then
  die "/usr/share/wayland-sessions/plasma.desktop is missing; the Plasma install didn't complete."
fi
if [[ ! -f /usr/local/share/wayland-sessions/omarchy.desktop && ! -f /usr/share/wayland-sessions/omarchy.desktop ]]; then
  warn "No omarchy.desktop session found. You may only see plain 'Hyprland' at login."
fi
THEME_LINES=""
if [[ -d /usr/share/sddm/themes/breeze ]] || (( DRY_RUN )); then
  THEME_LINES=$'\n[Theme]\nCurrent=breeze'
else
  warn "SDDM breeze theme not found; keeping Omarchy's login theme (it may hide the session menu)"
fi
# Run the login screen on KWin instead of Omarchy's Hyprland greeter. Hyprland
# auto-scales from the monitor's reported size, and virtual displays (VMware)
# report misleading sizes, so the greeter came up at 2x and ran off the screen.
COMPOSITOR_LINES=""
if command -v kwin_wayland >/dev/null || (( DRY_RUN )); then
  COMPOSITOR_LINES=$'\n[Wayland]\nCompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1'
else
  warn "kwin_wayland not found; keeping Omarchy's Hyprland login screen"
fi
write_root_file "$SDDM_OVERRIDE" <<EOF
# Added by omarchy-plasma. Remove this file to restore Omarchy's auto-login.
[Autologin]
User=
${THEME_LINES}
${COMPOSITOR_LINES}
EOF
did "Auto-login off; pick Plasma (Wayland) or Omarchy at the login screen"
if [[ -n "$COMPOSITOR_LINES" ]]; then did "Login screen runs on KWin (correct scaling in VMs)"; fi

# ---------- 4. kitty decorations and size (Plasma only) ----------
step "4/7 Kitty window settings for Plasma"
run mkdir -p "$KITTY_DIR"
if [[ -f "$KITTY_DIR/kitty.conf" ]] && grep -qxF "$INCLUDE_LINE" "$KITTY_DIR/kitty.conf"; then
  ok "Per-desktop include already present"
else
  if (( DRY_RUN )); then
    echo "  [dry-run] append to $KITTY_DIR/kitty.conf: $INCLUDE_LINE"
  else
    printf '\n# Per-desktop overrides (added by omarchy-plasma)\n%s\n' "$INCLUDE_LINE" >> "$KITTY_DIR/kitty.conf"
  fi
  did "Added per-desktop include to kitty.conf"
fi
if (( DRY_RUN )); then
  echo "  [dry-run] write $KITTY_DIR/KDE.conf and touch $KITTY_DIR/Hyprland.conf"
else
  [[ -f "$KITTY_DIR/KDE.conf" ]] && cp "$KITTY_DIR/KDE.conf" "$KITTY_DIR/KDE.conf.bak"
  cat > "$KITTY_DIR/KDE.conf" <<'EOF'
# Plasma-only kitty settings (added by omarchy-plasma)
hide_window_decorations no
remember_window_size no
initial_window_width 128c
initial_window_height 32c
EOF
  touch "$KITTY_DIR/Hyprland.conf"
fi
did "Title bar, borders and 128x32 default size in Plasma; Omarchy unchanged"

# ---------- 5. kitty color theme ----------
step "5/7 Kitty color theme"
if (( ! DO_KITTY_THEME )); then
  warn "Skipped (--no-kitty-theme)"
elif ! command -v kitten >/dev/null; then
  warn "kitten not found (is kitty installed?); skipping theme"
else
  # Non-interactive: applies the theme to current-theme.conf and adds the
  # BEGIN/END_KITTY_THEME block to kitty.conf. Downloads the theme list on first use.
  if run kitten themes --reload-in=none "$KITTY_THEME" < /dev/null; then
    did "Applied \"$KITTY_THEME\" (both sessions; delete the BEGIN_KITTY_THEME block in kitty.conf to undo)"
  else
    warn "Couldn't apply \"$KITTY_THEME\" (no network, or unknown name). Run 'kitten themes' later to pick one."
  fi
fi

# ---------- 6. btop ----------
step "6/7 btop colors"
if (( ! DO_BTOP )); then
  warn "Skipped (--no-btop)"
elif [[ -f "$BTOP_CONF" ]]; then
  if grep -q '^color_theme = "TTY"' "$BTOP_CONF"; then
    ok "btop already uses the TTY theme"
  else
    run cp "$BTOP_CONF" "$BTOP_CONF.bak"
    run sed -i 's/^color_theme = .*/color_theme = "TTY"/' "$BTOP_CONF"
    did "btop now follows the terminal's colors (backup: btop.conf.bak)"
  fi
else
  warn "No btop.conf yet. Run btop once, then re-run this script (or set Color theme to TTY in btop's options)."
fi

# ---------- 7. desktop folder ----------
step "7/7 Desktop folder"
# Omarchy registers the home folder itself as the XDG Desktop folder (Hyprland
# shows no desktop icons), so Plasma's desktop displays every folder in $HOME.
# Give the desktop its own ~/Desktop folder instead, like Windows does.
USER_DIRS="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
DESKTOP_MARKER="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-plasma/desktop-was-home"
# shellcheck disable=SC2016  # user-dirs.dirs stores a literal $HOME
if (( ! DO_DESKTOP )); then
  warn "Skipped (--no-desktop-folder)"
elif [[ -f "$USER_DIRS" ]] && grep -qE '^XDG_DESKTOP_DIR="\$HOME/?"' "$USER_DIRS"; then
  run mkdir -p "$HOME/Desktop" "$(dirname "$DESKTOP_MARKER")"
  if command -v xdg-user-dirs-update >/dev/null; then
    run xdg-user-dirs-update --set DESKTOP "$HOME/Desktop"
  else
    # shellcheck disable=SC2016  # user-dirs.dirs stores a literal $HOME
    run sed -i 's|^XDG_DESKTOP_DIR=.*|XDG_DESKTOP_DIR="$HOME/Desktop"|' "$USER_DIRS"
  fi
  run touch "$DESKTOP_MARKER"
  did "Desktop now uses its own ~/Desktop folder instead of showing your whole home folder"
else
  ok "Desktop folder already separate from your home folder"
fi

# ---------- done ----------
step "Done"
cat <<'EOF'
  Reboot, then use the session menu at the bottom-left of the login screen:
    • Plasma (Wayland)  → KDE
    • Omarchy           → your normal Omarchy desktop
  (Don't pick plain "Hyprland" or "Hyprland (uwsm)"; they skip Omarchy's setup.)

  Don't start Plasma from a text console while Hyprland is running; it will crash.
  To undo everything:
    curl -fsSL https://raw.githubusercontent.com/paulcfry67/omarchy-plasma/main/uninstall.sh | bash
EOF
