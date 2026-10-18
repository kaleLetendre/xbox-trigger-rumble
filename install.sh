#!/bin/sh
# One-time setup for impulse-trigger rumble on wired Xbox One/Series pads
# through SDL/Steam. Run as your normal user; it calls sudo for the system parts.
# Safe to re-run.
#
#   1. SDL_HIDAPI_LIBUSB_WHITELIST=0 for your desktop session (~/.xprofile for
#      X11 display managers, ~/.config/environment.d for systemd/Wayland sessions)
#   2. A Steam launcher (~/.local/share/applications/steam.desktop, and the
#      autostart entry if there is one) that sets it too: some sessions (e.g.
#      XFCE with i3) read neither file, and then Steam can't see the pad at all
#   3. ./trigger-rumble on  (udev access rule + xpad blacklist)
#
# Switch modes later with ./trigger-rumble on|off|status. Remove everything
# with ./uninstall.sh.

# Stop at the first failed step, so nothing is left half-installed without notice.
set -e

cd "$(dirname "$0")"

MARK_BEGIN="# >>> xbox-trigger-rumble >>>"
MARK_END="# <<< xbox-trigger-rumble <<<"

echo "== session environment"
mkdir -p ~/.config/environment.d
install -m 644 environment.d/60-sdl-libusb.conf ~/.config/environment.d/
touch ~/.xprofile
if ! grep -qF "$MARK_BEGIN" ~/.xprofile; then
    cat >> ~/.xprofile <<EOF
$MARK_BEGIN
# Let SDL/Steam open Xbox pads over libusb (impulse-trigger rumble).
export SDL_HIDAPI_LIBUSB_WHITELIST=0
$MARK_END
EOF
fi

echo "== Steam launcher"
# Copy of Steam's own launcher with every Exec line run through env. Marked so
# uninstall.sh only removes our copy. A file we didn't write is kept as .bak.
STEAM_MARK="# Written by xbox-trigger-rumble install.sh"
steam_launcher() {
    src=$1
    dst=$2
    if [ -f "$dst" ] && [ ! -L "$dst" ] && ! grep -qF "$STEAM_MARK" "$dst"; then
        cp "$dst" "$dst.bak-xbox-trigger-rumble"
    fi
    {
        echo "$STEAM_MARK"
        sed -e 's#^Exec=\(env SDL_HIDAPI_LIBUSB_WHITELIST=0 \)*#Exec=env SDL_HIDAPI_LIBUSB_WHITELIST=0 #' "$src"
    } > "$dst.tmp"
    mv -f "$dst.tmp" "$dst"
    echo "  $dst"
}
STEAM_SRC=""
for f in /usr/share/applications/steam.desktop ~/.steam/debian-installation/deb-installer/steam.desktop; do
    if [ -f "$f" ]; then
        STEAM_SRC=$f
        break
    fi
done
if [ -n "$STEAM_SRC" ]; then
    mkdir -p ~/.local/share/applications
    steam_launcher "$STEAM_SRC" ~/.local/share/applications/steam.desktop
    if [ -e ~/.config/autostart/steam.desktop ]; then
        steam_launcher "$STEAM_SRC" ~/.config/autostart/steam.desktop
    fi
else
    echo "  no steam.desktop found; start Steam with: SDL_HIDAPI_LIBUSB_WHITELIST=0 steam"
fi

echo "== trigger-rumble mode on"
./trigger-rumble on

cat <<'EOF'

Done. Quit Steam (steam -shutdown) and start it again from your app menu, or log
out and back in, so Steam starts with the setting. Then check:
  ./trigger-rumble status
  python3 scripts/sdl_trigger_test.py --libusb
EOF
