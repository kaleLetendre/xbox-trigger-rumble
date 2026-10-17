# Experiment log

## 2026-10-17

- `scripts/evdev_rumble.py /dev/input/event5`: grip rumble sent OK through xpad (user to confirm felt).
- `scripts/sdl_trigger_test.py` (Steam SDL3, default): path `/dev/input/event5`,
  rumble True, trigger rumble False, trigger calls fail with "not supported".
- Same with `--libusb`: identical. SDL still uses evdev because
  `/dev/bus/usb/003/009` is `root:root 664`, so libusb can't open it.
- Next: install `udev/70-xbox-series-usb-uaccess.rules`, replug, then rerun with `--libusb`.
- Installed udev rule, replugged. Node now `/dev/bus/usb/003/010`, ACL `user:kl:rw-`. Rule works.
- `sdl_trigger_test.py --libusb`: "no gamepads found". SDL verbose log: Steam SDL is
  `3.4.0-1576`, picks driver `SDL_JOYSTICK_HIDAPI_GIP` for path `3-6.3:1.0`.
  Mid-run the interface was bound to `usbfs` (libusb detached xpad).
- Upstream `SDL_hidapi_gip.c` sends `left/right_impulse_level` in `GIP_CMD_DIRECT_MOTOR`
  and reports `SDL_JOYSTICK_CAP_TRIGGER_RUMBLE`, so the driver supports triggers.
- 20 s watch: joysticks=0 the whole time; log shows a repeated Removing/Added HIDAPI
  device cycle. Cause: SDL and xpad keep taking the device from each other (detach →
  udev event → SDL re-enumerates → close reattaches xpad → repeat). No GIP packets
  are ever logged.
- `SDL_JOYSTICK_HIDAPI_GIP_RESET_FOR_METADATA=1` made no difference (it defaults to true anyway).
- Next: unbind xpad from `3-6.3:1.0` and rerun.
- User unbound xpad (`3-6.3:1.0`). Same remove/add loop with Steam SDL.
- Built upstream SDL `main` (3.5.0-0ae55ed) with `-DDEBUG_HIDAPI -DDEBUG_XBOX_PROTOCOL`
  via `scripts/build-sdl.sh`. Same behavior, so it isn't Steam-specific. Trace (LIBUSB_DEBUG=4):
  - claims ifaces 0 (alt 1), 1, 2. Bulk reads start. No hello from the pad, because xpad
    had already started it.
  - at 2.25 s (GIP hello timeout) SDL sends `05 20 01 01 07` (GIP power/reset).
  - pad answers two `0x03` status packets, then `bulk error -71` and USB disconnect
    (`detached: 1`). The read fails, `UpdateDevice` returns false, SDL closes and removes the device.
  - pad re-enumerates ~7 s later; xpad (autoloaded via modalias) grabs it again
    before SDL, so no hello again. Loop.
- Conclusion: xpad must not load at all. Added `modprobe/blacklist-xpad.conf`.
- Next: blacklist + `modprobe -r xpad`, replug, rerun (15 s wait).
- Blacklisted xpad, `modprobe -r xpad`, replugged. `sdl_trigger_test.py --libusb`
  (Steam SDL 3.4.0-1576): `GIP: Device hello from <device-id>`, firmware 5.9.2709,
  path `3-6.3:1.0`, rumble True, **trigger rumble True**, grips/left/right all sent
  without error. User felt both triggers buzz. **Trigger motors work from userspace.**
- Next: get the Steam client itself to use libusb (`SDL_HIDAPI_LIBUSB_WHITELIST=0`)
  and check whether games' trigger rumble reaches the pad through Steam Input.
- Restarted Steam as `SDL_HIDAPI_LIBUSB_WHITELIST=0 steam`. controller.txt:
  `Controller using HIDAPI driver, vid=0x045e, pid=0x0b12` (before: evdev mapping).
  Steam now sees the pad without a unit serial and made a new per-controller config
  set `configset_45e-b12-<serial>.vdf`, so per-controller bindings may need redoing.
- Installed `environment.d/60-sdl-libusb.conf` to `~/.config/environment.d/` so it
  applies after the next login.
- Next: in-game test of trigger rumble through Steam Input (Forza Horizon 4/5, Gears 5).
- Reboot check: xpad not in initramfs (only xpadneo's BT alias config), so the
  modprobe blacklist holds from boot. XFCE under SDDM doesn't inherit
  `~/.config/environment.d`; SDDM's Xsession sources `~/.xprofile`, so the hint goes there too.
- udev rule generalized to `ENV{ID_USB_INTERFACES}=="*:ff47d0:*"` (GIP interface),
  renamed `70-xbox-gip-uaccess.rules`. Added `install.sh` / `uninstall.sh`.
- Added `./trigger-rumble on|off|status` toggle. The udev rule and xpad blacklist
  always switch together: raw access with xpad loaded is the fight loop. The session
  hint stays in both modes (inert without access). install/uninstall now call it.
- Observed: Steam restarted at 14:09 without the hint (pid 1471483), so the pad was
  unclaimed and invisible to Steam. `status` now checks the running Steam's environment.
- Checked "over the hill" (appid 2929250, Funselektor, Windows Unity IL2CPP build under Proton)
  for trigger-rumble support by grepping `global-metadata.dat`:
  - Its haptics code (`Assets/Scripts/Haptics/UnityGamepadHapticOutput.cs`,
    `ControllerVibrationManager.cs`) goes through Unity Input System `IDualMotorRumble` /
    `DualMotorRumbleCommand` (low/high frequency only). Xbox pads are seen as
    `XInputControllerWindows`, and the game ships `xinput1_3.dll`. XInput has no trigger channel.
  - No Unity `XboxOneGamepad` trigger motors and no GameInput / Windows.Gaming.Input use found
    (`GameAssembly.dll` has 0 hits; `UnityPlayer.dll` has 1, from the generic engine).
  - Steamworks.NET bindings include `ISteamInput_TriggerVibrationExtended`, but that's the
    full binding set shipped with the library, not evidence the game calls it.
  - Verdict: almost certainly grips only, no trigger rumble. Not a useful test game.
- Over the Hill in on mode: no controller input, Unity `found 0 gamepad(s)`. Causes:
  (1) Steam running without the hint (pre-relogin); (2) Steam Input off for Xbox pads
  (Steam default). Mask `Opted-in Controller Mask ...: 1000`, `virtualgamepadinfo.txt`
  empty, no uinput pad. After **Properties → Controller → Enable Steam Input**: uinput
  `Microsoft X-Box 360 pad 0` (28de:11ff) appears, and virtualgamepadinfo lists
  `type=xboxone handle=<handle>`. Documented as a requirement of on mode.
- Games launched from Steam inherit `SDL_HIDAPI_LIBUSB_WHITELIST=0`. With Steam Input on,
  the real pad is claimed by Steam, so a game's own SDL can't open it (libusb claim fails).
