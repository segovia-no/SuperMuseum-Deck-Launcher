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
BRANCH="${SMDL_BRANCH:-main}"   # set SMDL_BRANCH=develop to test the develop branch
ART_URL="https://raw.githubusercontent.com/segovia-no/SuperMuseum-Deck-Launcher/$BRANCH/art"
ART_DIR="$HOME/.local/share/supermuseum-deck-launcher/art"
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

# Prints "<grid dir> <appid>" for every Steam user that has a shortcut named $NAME.
find_shortcut() {
  python3 - "$NAME" <<'PY'
import glob, os, sys

name = sys.argv[1].lower()

def read_str(b, i):
    j = b.index(b"\x00", i)
    return b[i:j].decode("utf-8", "replace"), j + 1

def parse(b, i):
    d = {}
    while i < len(b):
        t = b[i]; i += 1
        if t == 0x08:
            return d, i
        key, i = read_str(b, i)
        if t == 0x00:
            d[key], i = parse(b, i)
        elif t == 0x01:
            d[key], i = read_str(b, i)
        elif t == 0x02:
            d[key] = int.from_bytes(b[i:i + 4], "little"); i += 4
        elif t == 0x03:
            i += 4
        elif t == 0x07:
            i += 8
        else:
            raise ValueError("unknown type %d" % t)
    return d, i

for vdf in glob.glob(os.path.expanduser("~/.steam/steam/userdata/*/config/shortcuts.vdf")):
    try:
        data, _ = parse(open(vdf, "rb").read(), 0)
    except Exception:
        continue
    for entry in data.get("shortcuts", {}).values():
        e = {k.lower(): v for k, v in entry.items()}
        if str(e.get("appname", "")).lower() == name and e.get("appid"):
            print(os.path.join(os.path.dirname(vdf), "grid"), e["appid"])
PY
}

# Downloads artwork from the repo's art/ folder. Missing files are skipped.
download_art() {
  mkdir -p "$ART_DIR"
  for f in cover wide hero logo icon; do
    curl -fsSL "$ART_URL/$f.png" -o "$ART_DIR/$f.png.tmp" 2>>"$LOG" \
      && mv "$ART_DIR/$f.png.tmp" "$ART_DIR/$f.png" \
      || rm -f "$ART_DIR/$f.png.tmp"
  done
}

# Copies artwork into Steam's grid folder, waiting up to 60s for Steam to save the shortcut.
apply_art() {
  ls "$ART_DIR"/*.png >/dev/null 2>&1 || return 0
  local tries=0 found=""
  while [ $tries -lt 30 ]; do
    found="$(find_shortcut)"
    [ -n "$found" ] && break
    sleep 2; tries=$((tries + 1))
  done
  [ -z "$found" ] && return 1
  while read -r grid id; do
    mkdir -p "$grid"
    [ -f "$ART_DIR/cover.png" ] && cp "$ART_DIR/cover.png" "$grid/${id}p.png"
    [ -f "$ART_DIR/wide.png" ]  && cp "$ART_DIR/wide.png"  "$grid/${id}.png"
    [ -f "$ART_DIR/hero.png" ]  && cp "$ART_DIR/hero.png"  "$grid/${id}_hero.png"
    [ -f "$ART_DIR/logo.png" ]  && cp "$ART_DIR/logo.png"  "$grid/${id}_logo.png"
    [ -f "$ART_DIR/icon.png" ]  && cp "$ART_DIR/icon.png"  "$grid/${id}_icon.png"
    echo "[*] Artwork copied to $grid for appid $id" >> "$LOG"
  done <<< "$found"
  return 0
}

remove_art() {
  find_shortcut 2>/dev/null | while read -r grid id; do
    rm -f "$grid/${id}p.png" "$grid/${id}.png" "$grid/${id}_hero.png" "$grid/${id}_logo.png" "$grid/${id}_icon.png"
  done
}

uninstall() {
  remove_art
  rm -f "$DESKTOP"
  rm -rf "$PROFILE" "$(dirname "$ART_DIR")"
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

  step "Downloading artwork..."
  download_art

  ICON="applications-games"
  [ -f "$ART_DIR/icon.png" ] && ICON="$ART_DIR/icon.png"

  step "Creating Chrome profile and launcher..."
  mkdir -p "$PROFILE" "$(dirname "$DESKTOP")"
  cat > "$DESKTOP" <<EOF
[Desktop Entry]
Name=$NAME
Comment=Play Super Museum in Chrome kiosk mode
Exec=flatpak run --branch=stable --arch=x86_64 --command=/app/bin/chrome $CHROME_ID --user-data-dir=$PROFILE --kiosk --no-first-run --start-fullscreen --autoplay-policy=no-user-gesture-required "$URL"
Icon=$ICON
Type=Application
Categories=Game;
EOF
  chmod +x "$DESKTOP"

  if command -v steamos-add-to-steam >/dev/null 2>&1; then
    step "Adding to Steam (confirm the prompt if Steam shows one)..."
    steamos-add-to-steam "$DESKTOP" >>"$LOG" 2>&1
    step "Applying artwork (waiting for Steam to save the shortcut)..."
    apply_art || echo "[!] Shortcut not found in Steam config, artwork skipped" >> "$LOG"
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
  0)  info "$NAME was added to Steam.\n\nSwitch back to Game Mode and find it under Non-Steam in your library.\n\nRestart Steam (or reboot) if the game or its artwork does not show up." ;;
  10) fail "flatpak is not available. This script is meant for SteamOS." ;;
  11) fail "steamos-add-to-steam was not found.\n\nThe launcher was created at:\n$DESKTOP\n\nAdd it manually in Steam: Games > Add a Non-Steam Game to My Library." ;;
  *)  fail "Something went wrong. See the log:\n$LOG" ;;
esac
