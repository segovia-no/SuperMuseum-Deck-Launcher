#!/bin/bash
# SuperMuseum Deck Launcher
# Adds https://supermuseum.netlify.app/ to Steam as a non-Steam game on the Steam Deck,
# running in Google Chrome (Flatpak) kiosk mode. Installs Chrome if it is missing.
#
# Usage:
#   ./install.sh               install / reinstall
#   ./install.sh --uninstall   remove the launcher and its Chrome profile
#
# Not affiliated with SuperMuseum or its author (livercake).

NAME="Super Museum"
URL="https://supermuseum.netlify.app/"
SLUG="SuperMuseum"
CHROME_ID="com.google.Chrome"

DESKTOP="$HOME/.local/share/applications/${SLUG}.desktop"
PROFILE="$HOME/.var/app/${CHROME_ID}/config/webapps/${SLUG}"
LOG="/tmp/supermuseum-deck-launcher.log"
TITLE="SuperMuseum Deck Launcher"

has_gui() {
  command -v zenity >/dev/null 2>&1 && [ -n "$DISPLAY$WAYLAND_DISPLAY" ]
}

info() {
  if has_gui; then zenity --info --title="$TITLE" --width=360 --text="$1"; else printf "%b\n" "$1"; fi
}

fail() {
  if has_gui; then zenity --error --title="$TITLE" --width=360 --text="$1"; else printf "ERROR: %b\n" "$1" >&2; fi
  exit 1
}

step() {
  echo "# $1"
  echo "[*] $1" >> "$LOG"
}

uninstall() {
  rm -f "$DESKTOP"
  rm -rf "$PROFILE"
  info "Launcher files removed.\n\nTo remove the entry from Steam: open your library, select Super Museum, then Manage > Remove non-Steam game from your library."
  exit 0
}

work() {
  set -e

  if ! command -v flatpak >/dev/null 2>&1; then
    step "flatpak not found"
    exit 10
  fi

  if ! flatpak info "$CHROME_ID" >/dev/null 2>&1; then
    step "Installing Google Chrome (this can take a few minutes)..."
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >>"$LOG" 2>&1
    flatpak install --user -y --noninteractive flathub "$CHROME_ID" >>"$LOG" 2>&1
  else
    step "Google Chrome already installed"
  fi

  step "Creating Chrome profile and launcher..."
  mkdir -p "$PROFILE" "$(dirname "$DESKTOP")"
  cat > "$DESKTOP" <<EOF
[Desktop Entry]
Name=$NAME
Comment=Play Super Museum in Chrome kiosk mode
Exec=flatpak run --branch=stable --arch=x86_64 --command=/app/bin/chrome $CHROME_ID --user-data-dir=$PROFILE --kiosk --no-first-run --start-fullscreen --autoplay-policy=no-user-gesture-required "$URL"
Icon=applications-games
Type=Application
Categories=Game;
EOF
  chmod +x "$DESKTOP"

  if command -v steamos-add-to-steam >/dev/null 2>&1; then
    step "Adding to Steam (confirm the prompt if Steam shows one)..."
    steamos-add-to-steam "$DESKTOP" >>"$LOG" 2>&1
  else
    step "steamos-add-to-steam not found, skipping Steam step"
    exit 11
  fi

  step "Done"
}

[ "$1" = "--uninstall" ] && uninstall

: > "$LOG"

if has_gui; then
  work 2>>"$LOG" | zenity --progress --pulsate --auto-close --no-cancel \
    --title="$TITLE" --width=360 --text="Starting..."
  STATUS="${PIPESTATUS[0]}"
else
  work 2>>"$LOG" | sed 's/^# //'
  STATUS="${PIPESTATUS[0]}"
fi

case "$STATUS" in
  0)  info "$NAME was added to Steam.\n\nSwitch back to Game Mode and find it under Non-Steam in your library. If it does not show up, restart Steam." ;;
  10) fail "flatpak is not available. This script is meant for SteamOS." ;;
  11) fail "steamos-add-to-steam was not found.\n\nThe launcher was created at:\n$DESKTOP\n\nAdd it manually in Steam: Games > Add a Non-Steam Game to My Library." ;;
  *)  fail "Something went wrong. See the log:\n$LOG" ;;
esac
