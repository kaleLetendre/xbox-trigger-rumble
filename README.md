# xbox-trigger-rumble

Impulse-trigger rumble (the small motors behind LT/RT) for wired Xbox One and
Xbox Series controllers on Linux, through Steam and other SDL programs.

Linux's built-in `xpad` driver only runs the two big grip motors. It always sends
zero to the trigger motors. This project hands the controller to SDL (the library
Steam uses for controllers), which talks to it over raw USB and can drive all four motors.

**Status**
- Works: all four motors from SDL, and Steam opening the controller over raw USB.
- Not yet confirmed: a game's trigger rumble reaching the controller through Steam,
  and whether a game with Steam Input disabled can open the controller while Steam holds it.

**Tested on**
- Debian 13 (XFCE, SDDM login screen), kernel 6.12
- Xbox Series X|S controller `045e:0b12`, wired
- Steam client with bundled SDL 3.4

---

## Setup

You need:
- the controller on a USB cable (Bluetooth isn't covered here)
- Steam installed
- sudo rights

1. Run the installer as your normal user. It asks for your sudo password:

       ./install.sh

2. Unplug the controller and plug it back in.
3. Log out and back in, so Steam starts with the new session setting.
4. Check it:

       ./trigger-rumble status

   You want to see:

       mode: on (trigger rumble; pads only visible to SDL/Steam)
       xpad module: not loaded
       pad 045e:0b12 at 3-6.3: driver usbfs (SDL/libusb)
       steam: running with SDL_HIDAPI_LIBUSB_WHITELIST=0

   `driver usbfs` means Steam (or another SDL program) is holding the controller.
   If Steam isn't running, you'll see `driver none (unclaimed)`, which is fine.

5. Feel it. Close Steam first, because only one program can hold the controller over raw USB:

       steam -shutdown
       python3 scripts/sdl_trigger_test.py --libusb

   It should print `trigger rumble: True`. The grips buzz, then the left trigger,
   then the right trigger. Start Steam again afterwards.

The setup survives reboots. Everything lives in `/etc` and your home directory.

### What install.sh changes

| What | Where | Why |
|---|---|---|
| udev rule | `/etc/udev/rules.d/70-xbox-gip-uaccess.rules` | Lets your user open the controller's raw USB device. It's root-only by default. |
| xpad blacklist | `/etc/modprobe.d/blacklist-xpad.conf` | Stops the kernel driver from taking the controller first (see [How it works](#how-it-works)). |
| Session setting | `~/.xprofile` and `~/.config/environment.d/60-sdl-libusb.conf` | Sets `SDL_HIDAPI_LIBUSB_WHITELIST=0` so Steam's SDL is allowed to use raw USB for the controller. |

The session setting goes in two files because desktops differ. `~/.xprofile` is
read by X11 login screens (SDDM, LightDM, GDM on X11), which covers XFCE.
`environment.d` is read by systemd-managed sessions (GNOME/KDE on Wayland).

---

## Daily use

Plug in the controller and play. The mode stays on across reboots.

> **Steam Input must be enabled for every game you play with the controller.**
> In `on` mode, Steam is the only program holding the controller, and games only
> get input through Steam Input's virtual gamepad. Steam leaves Steam Input *off*
> for Xbox controllers by default, so without this step a game sees no controller
> at all (Unity's log says `found 0 gamepad(s)`).
>
> Per game: **Properties → Controller → Enable Steam Input**.
> For every game at once: **Steam → Settings → Controller → Enable Steam Input
> for Xbox controllers**.
>
> Check while the game is running: `/proc/bus/input/devices` lists
> `Microsoft X-Box 360 pad 0` (`28de:11ff`), and
> `~/.steam/steam/config/virtualgamepadinfo.txt` lists your controller.

- **Steam games:** Steam owns the controller and passes it to games through Steam Input.
- **Trigger rumble in games:** few PC games use it. Known ones: Forza Horizon 4/5,
  Forza Motorsport, Gears 5, Halo MCC. Games built on old XInput (most Proton
  games) only ask for grip rumble.
- **Trigger rumble from the game itself:** with Steam Input, games see a virtual
  Xbox 360 controller, which has no trigger motors. So a game's own trigger rumble
  can't get through. Trigger rumble reaches the controller only from code that
  calls Steam Input's `TriggerVibrationExtended` (e.g. a mod like
  [over-the-hill-trigger-rumble](https://github.com/kaleLetendre/over-the-hill-trigger-rumble)). With Steam
  Input disabled, the game gets no controller at all in `on` mode.
- **If the controller stops responding in Steam**, run `./trigger-rumble status`:
  - `steam: running WITHOUT ...`: Steam was started without the session
    setting (e.g. it restarted itself after an update). Fix:

        steam -shutdown
        SDL_HIDAPI_LIBUSB_WHITELIST=0 steam

  - `mode: MIXED`: run `./trigger-rumble on` (or `off`).
  - `driver none` while Steam is running: replug the controller.
- **If a game sees no controller** (menus don't respond, Unity logs
  `found 0 gamepad(s)`), Steam Input is off for that game. See the box above.
- **After a Steam update**, if trigger rumble stops but grips still work, rerun
  the test in step 5 of Setup. Steam bundles its own SDL, and an update can change it.

---

## Turning it on and off

    ./trigger-rumble on       trigger rumble; controller only usable from SDL programs
    ./trigger-rumble off      stock Linux driver; works everywhere, no trigger rumble
    ./trigger-rumble status   current mode, what's holding the controller, Steam's setting

- `on` and `off` need sudo.
- Switching takes effect immediately: no reboot, no Steam restart. If the
  controller doesn't show up within about 10 seconds, replug it.
- The mode stays as you left it across reboots.
- Use `off` when you need the controller in something from the list below, then `on` again after.

`on` always changes the udev rule and the xpad blacklist together. Raw USB access
with xpad still loaded is worse than either mode, because SDL and xpad keep taking
the controller from each other and it works nowhere. If you edit the files by hand,
change both.

### Removing it completely

    ./uninstall.sh

This switches to `off`, then deletes the session setting from `~/.xprofile` and
`environment.d`. Log out and back in afterwards.

---

## Interactions with other programs

`on` mode applies to the **whole machine**: every user account and every program.

### Works in `on` mode

- **Steam**, and games launched from it **with Steam Input enabled** for that game.
- **SDL programs started from your desktop session**, which get the session
  setting: most native Linux games, and emulators set to an SDL input driver.
- **Bluetooth Xbox controllers.** They use `hid-microsoft`/xpadneo, not xpad, so they're unaffected.
- **PlayStation, Switch and other non-Xbox controllers.** They don't use xpad.

### Stops working in `on` mode (use `off` for these)

- **Programs that read `/dev/input` directly.** The controller no longer appears
  as `/dev/input/js*` or `event*`. This includes:
  - browser games (Gamepad API in Firefox and Chromium)
  - `jstest`, `evtest`, `jstest-gtk`, and controller-test websites
  - emulators set to an evdev/udev input driver (e.g. RetroArch's `udev` driver;
    switch it to `sdl2` instead)
  - Wine/Proton set to its evdev backend, and some native games that read evdev
  - key mappers built on evdev (AntiMicroX in evdev mode, input-remapper)
- **Other controllers that use xpad**, because xpad is blocked for all of them:
  wired Xbox 360 controllers, the Xbox 360 wireless receiver, and many
  third-party XInput-style pads (Logitech F310/F710, PowerA, PDP, Mad Catz,
  many arcade sticks). The udev rule here only covers Xbox One/Series-style
  (GIP) controllers, so don't expect those others to work through SDL either.
- **Games with Steam Input disabled**, including games that turn it off themselves.
  They get no controller at all.
- **Other user accounts.** The session setting is per-user. Another account's
  Steam won't see the controller unless that user adds the same lines to their
  own `~/.xprofile` (copy the block `install.sh` added to yours).
- **SDL programs started outside your desktop session** (over SSH, from a
  systemd service, or from a terminal that started before you set this up)
  won't have the setting. Start them with `SDL_HIDAPI_LIBUSB_WHITELIST=0` in front.

### One program at a time

Over raw USB, only one program can hold the controller. While Steam has it, a
second SDL program (like `sdl_trigger_test.py`) won't see it. With Steam Input
on, that's fine: Steam passes input and rumble to the game through its virtual
controller. With Steam Input off for a game, Steam doesn't release the controller,
and the game sees none (seen with Over the Hill: `found 0 gamepad(s)`).

---

## How it works

Wired Xbox One/Series controllers speak Microsoft's GIP protocol over USB (not
HID). Getting the trigger motors running needed three things:

1. **Raw USB access.** SDL 3's `GIP` driver sends per-trigger motor levels, and
   Steam bundles that SDL. It can only reach the controller through libusb, which
   needs write access to `/dev/bus/usb/...`. That's the udev rule.
2. **SDL allowed to use libusb for this controller.** On Linux, SDL only uses
   libusb for a short built-in list of devices. `SDL_HIDAPI_LIBUSB_WHITELIST=0`
   lifts that.
3. **xpad out of the way.** When a controller connects it sends a one-time
   "hello" message, and SDL needs it. xpad starts the controller as soon as it's
   plugged in, so SDL never sees the hello. SDL waits 2 s and sends a reset; the
   controller drops off USB and reconnects; the kernel loads xpad again and xpad
   grabs it first. That loops forever. Unbinding xpad once doesn't survive the
   reset, so xpad has to be blacklisted.

Full investigation, traces and sources: [notes/findings.md](notes/findings.md)
and [notes/log.md](notes/log.md).

### Other controller models

The udev rule matches the GIP USB interface (`ff/47/d0`), not one product ID, so
it should cover other wired Xbox One/Series controllers. Only `045e:0b12` has
been tested. Check yours with `./trigger-rumble status`, which lists every GIP
controller it finds. Run `scripts/sdl_trigger_test.py --libusb` to see whether
SDL reports trigger rumble for it. SDL deliberately turns trigger rumble off for
many third-party controllers.

---

## Files

| Path | Purpose |
|---|---|
| `install.sh` / `uninstall.sh` | One-time setup and full removal |
| `trigger-rumble` | `on` / `off` / `status` |
| `udev/70-xbox-gip-uaccess.rules` | Raw USB access for GIP controllers |
| `modprobe/blacklist-xpad.conf` | Keeps xpad from loading |
| `environment.d/60-sdl-libusb.conf` | Session setting for systemd sessions |
| `scripts/sdl_trigger_test.py [--libusb] [--sdl PATH]` | Opens the controller with Steam's SDL (or `PATH`), reports the backend and trigger-rumble support, fires each motor |
| `scripts/evdev_rumble.py <event-node>` | Grip rumble through the kernel driver (only in `off` mode) |
| `scripts/build-sdl.sh [ref]` | Builds a debug SDL 3 into `build/` (no root) for protocol tracing; use with `--sdl build/sdl-build/libSDL3.so.0` and `SDL_LOGGING='*=verbose'` |
| `notes/findings.md` | What was found and why, with sources |
| `notes/log.md` | Dated experiment log |
