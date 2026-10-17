#!/usr/bin/env python3
"""Probe trigger rumble through SDL3 (defaults to Steam's bundled copy).

Shows which backend SDL picked (kernel evdev vs HIDAPI/libusb), whether it
reports trigger rumble, then fires grip rumble and each trigger in turn.

Usage: sdl_trigger_test.py [--libusb] [--sdl PATH]
  --libusb   set SDL_HIDAPI_LIBUSB_WHITELIST=0 so SDL may open the pad over
             raw USB (needs write access to its /dev/bus/usb node)
"""
import argparse
import ctypes as C
import os
import time

DEFAULT_SDL = os.path.expanduser("~/.steam/steam/ubuntu12_64/libSDL3.so.0")
SDL_INIT_GAMEPAD = 0x2000
PROP_TRIGGER_RUMBLE = b"SDL.joystick.cap.trigger_rumble"
PROP_RUMBLE = b"SDL.joystick.cap.rumble"

ap = argparse.ArgumentParser()
ap.add_argument("--libusb", action="store_true")
ap.add_argument("--sdl", default=DEFAULT_SDL)
args = ap.parse_args()

sdl = C.CDLL(args.sdl)
sdl.SDL_SetHint.argtypes = [C.c_char_p, C.c_char_p]
sdl.SDL_Init.argtypes = [C.c_uint32]
sdl.SDL_Init.restype = C.c_bool
sdl.SDL_GetError.restype = C.c_char_p
sdl.SDL_GetGamepads.argtypes = [C.POINTER(C.c_int)]
sdl.SDL_GetGamepads.restype = C.POINTER(C.c_uint32)
sdl.SDL_OpenGamepad.argtypes = [C.c_uint32]
sdl.SDL_OpenGamepad.restype = C.c_void_p
for fn in ("SDL_GetGamepadName", "SDL_GetGamepadPath"):
    getattr(sdl, fn).argtypes = [C.c_void_p]
    getattr(sdl, fn).restype = C.c_char_p
sdl.SDL_GetGamepadProperties.argtypes = [C.c_void_p]
sdl.SDL_GetGamepadProperties.restype = C.c_uint32
sdl.SDL_GetBooleanProperty.argtypes = [C.c_uint32, C.c_char_p, C.c_bool]
sdl.SDL_GetBooleanProperty.restype = C.c_bool
sdl.SDL_RumbleGamepad.argtypes = [C.c_void_p, C.c_uint16, C.c_uint16, C.c_uint32]
sdl.SDL_RumbleGamepad.restype = C.c_bool
sdl.SDL_RumbleGamepadTriggers.argtypes = [C.c_void_p, C.c_uint16, C.c_uint16, C.c_uint32]
sdl.SDL_RumbleGamepadTriggers.restype = C.c_bool

if args.libusb:
    sdl.SDL_SetHint(b"SDL_HIDAPI_LIBUSB_WHITELIST", b"0")

if not sdl.SDL_Init(SDL_INIT_GAMEPAD):
    raise SystemExit(f"SDL_Init failed: {sdl.SDL_GetError().decode()}")

# Wait for a gamepad to show up. Over libusb the GIP driver only reports the
# pad after its startup handshake, which can take a few seconds.
n = C.c_int()
deadline = time.time() + 15
while True:
    sdl.SDL_UpdateGamepads()
    ids = sdl.SDL_GetGamepads(C.byref(n))
    if n.value or time.time() > deadline:
        break
    time.sleep(0.05)
if n.value == 0:
    raise SystemExit(f"no gamepads found ({sdl.SDL_GetError().decode()})")

gp = sdl.SDL_OpenGamepad(ids[0])
if not gp:
    raise SystemExit(f"open failed: {sdl.SDL_GetError().decode()}")
props = sdl.SDL_GetGamepadProperties(gp)
print("name:          ", sdl.SDL_GetGamepadName(gp).decode())
print("path:          ", (sdl.SDL_GetGamepadPath(gp) or b"?").decode())
print("rumble:        ", sdl.SDL_GetBooleanProperty(props, PROP_RUMBLE, False))
print("trigger rumble:", sdl.SDL_GetBooleanProperty(props, PROP_TRIGGER_RUMBLE, False))


def hold(seconds):
    end = time.time() + seconds
    while time.time() < end:
        sdl.SDL_UpdateGamepads()
        time.sleep(0.02)


for label, call in (
    ("grips", lambda: sdl.SDL_RumbleGamepad(gp, 0xC000, 0xC000, 1000)),
    ("left trigger", lambda: sdl.SDL_RumbleGamepadTriggers(gp, 0xFFFF, 0, 1000)),
    ("right trigger", lambda: sdl.SDL_RumbleGamepadTriggers(gp, 0, 0xFFFF, 1000)),
):
    ok = call()
    print(f"{label:14s} {'sent' if ok else 'FAILED: ' + sdl.SDL_GetError().decode()}")
    hold(1.3)

sdl.SDL_Quit()
