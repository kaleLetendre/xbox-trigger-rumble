# Findings

## Hardware / system

- Controller: Xbox Series X|S, `045e:0b12`, wired USB. Bluetooth had problems, so it's on cable.
- Driver: in-kernel `xpad` (+ `ff_memless`), Debian kernel 6.12.
- Steam's controller log (`~/.steam/steam/logs/controller*.txt`) shows Steam opening the
  pad through the kernel evdev device (SDL mapping GUID `0300f5a35e04...`, `platform:Linux`).

## Why trigger rumble doesn't work by default

- `xpad` sends GIP rumble packets with both trigger-motor bytes set to 0. The Linux FF
  API (`FF_RUMBLE`) has only strong/weak magnitudes and no trigger channel.
- Wired Xbox One/Series pads use GIP (vendor class), not HID, so there's no hidraw node.
  Over Bluetooth they are HID; xpadneo supports trigger rumble there.
- Proton/XInput games: XInput has no trigger rumble. Only games using
  Windows.Gaming.Input / GameInput request it.

## Paths to trigger rumble

1. **SDL over libusb (testing first).** Steam's bundled `libSDL3.so.0` is built with libusb
   support, the HIDAPI Xbox One driver, and the `SDL_HIDAPI_LIBUSB_WHITELIST` hint. SDL's
   Xbox One HIDAPI driver has supported trigger rumble on Microsoft pads since 2021. On
   Linux the whitelist is on by default and doesn't include Xbox One pads, so SDL needs
   `SDL_HIDAPI_LIBUSB_WHITELIST=0` plus user access to `/dev/bus/usb/...`.
   - Open question: does Steam Input then pass a game's trigger rumble through? Its
     virtual pad on Linux is an Xbox 360 device with no trigger motors.
2. **xone-impulse-triggers fork** (DKMS kernel driver). Drives the trigger motors over USB,
   but the strength comes from the normal rumble value scaled by how far each trigger is
   pressed, not from separate per-trigger game data. Tested on `045e:0b12`.
3. **Write our own:** a userspace GIP driver over libusb that exposes a device carrying the
   four channels end to end. Last resort.

## Sources

- SDL hidapi libusb whitelist: https://github.com/libsdl-org/SDL/blob/main/src/hidapi/SDL_hidapi.c
- SDL hint docs: https://wiki.libsdl.org/SDL3/SDL_HINT_HIDAPI_LIBUSB
- SDL trigger rumble for Microsoft pads: https://discourse.libsdl.org/t/sdl-added-note-about-trigger-rumble-availability-across-third-party-xbox-one-controllers/39669
- Steam Input → Xbox One rumble passthrough issue: https://github.com/libsdl-org/SDL/issues/6298
- xone-impulse-triggers: https://github.com/Firefoxray/xone-impulse-triggers
- xpadneo trigger rumble issue: https://github.com/atar-axis/xpadneo/issues/374
- Arch forum, kernel trigger FF status: https://bbs.archlinux.org/viewtopic.php?id=297910
