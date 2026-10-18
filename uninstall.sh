#!/bin/sh
# Undo install.sh: back to the stock xpad driver and default SDL behavior.

# Stop at the first failed step, so a partial undo is visible.
set -e

cd "$(dirname "$0")"

MARK_BEGIN="# >>> xbox-trigger-rumble >>>"
MARK_END="# <<< xbox-trigger-rumble <<<"

./trigger-rumble off

rm -f ~/.config/environment.d/60-sdl-libusb.conf
if [ -f ~/.xprofile ]; then
    sed -i "/^$MARK_BEGIN\$/,/^$MARK_END\$/d" ~/.xprofile
fi

# Our Steam launcher copies; a launcher the user had before is put back.
STEAM_MARK="# Written by xbox-trigger-rumble install.sh"
for f in ~/.local/share/applications/steam.desktop ~/.config/autostart/steam.desktop; do
    if [ -f "$f" ] && grep -qF "$STEAM_MARK" "$f"; then
        rm -f "$f"
        if [ -f "$f.bak-xbox-trigger-rumble" ]; then
            mv "$f.bak-xbox-trigger-rumble" "$f"
        fi
    fi
done

echo "Removed. Log out and back in to clear the session setting."
