#!/bin/sh
# One-time setup for impulse-trigger rumble on wired Xbox One/Series pads
# through SDL/Steam. Run as your normal user; it calls sudo for the system parts.
# Safe to re-run.
#
#   1. SDL_HIDAPI_LIBUSB_WHITELIST=0 for your desktop session (~/.xprofile for
#      X11 display managers, ~/.config/environment.d for systemd/Wayland sessions)
#   2. ./trigger-rumble on  (udev access rule + xpad blacklist)
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

echo "== trigger-rumble mode on"
./trigger-rumble on

cat <<'EOF'

Done. Log out and back in so Steam starts with the session setting, then check:
  ./trigger-rumble status
  python3 scripts/sdl_trigger_test.py --libusb
EOF
