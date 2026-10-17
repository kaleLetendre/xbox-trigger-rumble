# xbox-trigger-rumble

Impulse-trigger rumble (the small motors behind LT/RT) for wired Xbox One and
Xbox Series controllers on Linux, through Steam and other SDL programs.

Linux's built-in `xpad` driver only runs the two big grip motors. It always sends
zero to the trigger motors. This project hands the controller to SDL (the library
Steam uses for controllers), which talks to it over raw USB and can drive all four motors.

**Status**
- Works: all four motors from SDL. Steam owns the controller over raw USB, and
  Steam Input's `TriggerVibrationExtended` reaches the trigger motors (used by the
  [Over the Hill mod](https://github.com/kaleLetendre/over-the-hill-trigger-rumble)).
- Doesn't work: a game's *own* trigger rumble. Through Steam Input, games see a
  virtual Xbox 360 controller, which has no trigger motors.

**Tested on**
- Debian 13 (XFCE, SDDM login screen), kernel 6.12
- Xbox Series X|S controller `045e:0b12`, wired
- Steam installed from Debian's package (not Flatpak or Snap), with its bundled SDL 3.4

Other distros with systemd and udev should work, but haven't been tried. Flatpak and
Snap Steam haven't been tried at all.

---

## Step-by-step setup

Takes about 10 minutes. You'll type a few commands into a terminal; each step says
exactly what to type and what you should see. If a step doesn't match, stop and
look at [Troubleshooting](#troubleshooting) before going on.

### Before you start

You need:

- [ ] Linux, with Steam installed and working
- [ ] An Xbox One or Xbox Series controller, **plugged in with a USB cable**
      (Bluetooth isn't covered here)
- [ ] An account that can use `sudo` (the installer asks for your password)
- [ ] Git, or a way to unzip a download

Open a terminal. On most desktops, press the Super/Windows key, type `terminal`,
and press Enter.

### Step 1: Get the files

Either clone the repository:

    git clone https://github.com/kaleLetendre/xbox-trigger-rumble.git

or download it: on the GitHub page, click **Code → Download ZIP**, then unzip it in
your home folder. That gives you a folder named `xbox-trigger-rumble-main`; use that
name instead in the next command.

Go into the folder:

    cd xbox-trigger-rumble

### Step 2: Run the installer

    ./install.sh

When it asks `[sudo] password for <you>:`, type your login password and press
Enter. Nothing appears on screen while you type the password; that's normal.

It ends with:

    Done. Log out and back in so Steam starts with the session setting, then check:

If it stops earlier with an error instead, nothing was half-installed past that
point. See [Troubleshooting](#troubleshooting).

### Step 3: Replug the controller

Unplug the USB cable from the controller and plug it back in. This applies the new
USB permission to the controller.

### Step 4: Log out and back in

Use your desktop's normal **Log Out** (not just locking the screen), then log in
again. A reboot works too.

This step matters: Steam only picks up the new setting when it starts in a fresh
login session.

### Step 5: Turn on Steam Input for Xbox controllers

In `on` mode, games only get your controller through Steam Input, and Steam leaves
it **off** for Xbox controllers by default. Without this, games see no controller.

1. Open Steam.
2. Click **Steam** (top-left menu) → **Settings** → **Controller**.
3. Turn on **Enable Steam Input for Xbox controllers**.

To do it for one game only instead: right-click the game in your library →
**Properties** → **Controller** → set the override to **Enable Steam Input**.

### Step 6: Check everything

Back in the terminal, in the `xbox-trigger-rumble` folder, with Steam running:

    ./trigger-rumble status

You want all four lines to look like this (your pad ID and USB port may differ):

    mode: on (trigger rumble; pads only visible to SDL/Steam)
    xpad module: not loaded
    pad 045e:0b12 at 3-6.3: driver usbfs (SDL/libusb)
    steam: running with SDL_HIDAPI_LIBUSB_WHITELIST=0

What each line means:

| Line | Good | If not |
|---|---|---|
| `mode:` | `on` | Run `./trigger-rumble on` |
| `xpad module:` | `not loaded` | Replug the controller, or reboot |
| `pad ... driver` | `usbfs (SDL/libusb)`: Steam is holding it | `none` while Steam runs: replug the controller |
| `steam:` | `running with ...=0` | See [Steam can't see the controller](#troubleshooting) |

If there's no `pad` line at all, the controller isn't connected by USB, or it isn't
an Xbox One/Series-style controller.

### Step 7 (optional): Feel the trigger motors

This test talks to the controller directly, so Steam has to let go of it first:

    steam -shutdown
    python3 scripts/sdl_trigger_test.py --libusb

It prints `trigger rumble: True`, then buzzes the grips, the left trigger, and the
right trigger, about one second each. Start Steam again afterwards.

### Step 8: Use it in a game

Games don't use the trigger motors through Steam on their own (see Status above).
You need something that asks Steam for trigger rumble, like the
[Over the Hill mod](https://github.com/kaleLetendre/over-the-hill-trigger-rumble).

That's it. The setup survives reboots, and you don't need to run anything again.

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

## Troubleshooting

Start with `./trigger-rumble status`. It shows most problems.

**A game sees no controller (menus don't react to the pad)**
Steam Input is off for that game. Do [Step 5](#step-5-turn-on-steam-input-for-xbox-controllers),
then quit and restart the game. Unity games log `found 0 gamepad(s)` when this happens.

**Steam can't see the controller / `status` says `steam: running WITHOUT ...`**
Steam was started without the session setting. That happens before you've logged
out and in once after installing, or when Steam restarts itself (e.g. after an
update). Fix it now:

    steam -shutdown
    SDL_HIDAPI_LIBUSB_WHITELIST=0 steam

If it keeps coming back after every login, your login screen may not read
`~/.xprofile`. Wayland sessions (GNOME, KDE) read `~/.config/environment.d`
instead, and `install.sh` writes both. Open an issue with your distro and desktop.

**`pad ... driver none` while Steam is running**
Unplug the controller and plug it back in. If that doesn't help, restart Steam
with the two commands above.

**`xpad module: loaded` in `on` mode**
Something loaded it again. Run `./trigger-rumble on`, then replug the controller.

**`mode: MIXED`**
Only one of the two system files is in place. Run `./trigger-rumble on` (or `off`).

**`install.sh` fails with `sudo: command not found` or "not in the sudoers file"**
Your account can't use sudo. Ask whoever administers the machine, or run it from
an account that can.

**`./install.sh: Permission denied`**
The download lost its executable flag (common with ZIP downloads). Run:

    chmod +x install.sh uninstall.sh trigger-rumble

**`sdl_trigger_test.py` says `no gamepads found`**
Steam is still holding the controller. Run `steam -shutdown` first. If Steam isn't
at `~/.steam/steam`, pass its SDL library: `--sdl /path/to/ubuntu12_64/libSDL3.so.0`.

**The trigger motors stopped working after a Steam update**
Run Step 7 again. Steam bundles its own SDL, and an update can change it. Open an
issue with the output.

**Something else uses the controller and stopped working** (a browser game, an emulator)
That's expected in `on` mode. See [Interactions with other programs](#interactions-with-other-programs).
Switch with `./trigger-rumble off` while you use it, and `./trigger-rumble on` after.

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
