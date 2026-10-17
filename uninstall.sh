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

echo "Removed. Log out and back in to clear the session setting."
