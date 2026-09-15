#!/usr/bin/env python3
"""
poco-power-daemon.py
Automated AMOLED Screen Saver, Power Key Handler and Idle Watcher for POCO F4 (munch)
- Blanks AMOLED screen (brightness 0) after 60 seconds of idle.
- Wakes up immediately on any input event (USB mouse, keyboard, buttons, touch).
- Handles Power button (KEY_POWER = 116) to toggle screen instantly on/off.
"""

import os
import glob
import time
import select
import struct
import sys

IDLE_TIMEOUT_SECS = 60

def find_brightness_file():
    for b in glob.glob("/sys/class/backlight/*"):
        bf = os.path.join(b, "brightness")
        if os.path.exists(bf):
            return bf
    return "/sys/class/backlight/ae94000.dsi.0/brightness"

BRIGHTNESS_FILE = find_brightness_file()
DEFAULT_BRIGHTNESS = 600
KEY_POWER = 116

def log(msg):
    print(f"[{time.strftime('%X')}] {msg}", flush=True)

def get_brightness():
    try:
        with open(BRIGHTNESS_FILE, "r") as f:
            return int(f.read().strip())
    except:
        return 0

def set_brightness(val):
    try:
        with open(BRIGHTNESS_FILE, "w") as f:
            f.write(str(val))
    except Exception as e:
        log(f"Error setting brightness to {val}: {e}")
        if val > 0:
            try:
                # If KMS output is disabled, DSI host will reject DCS brightness commands.
                # Recover output via wlr-randr and retry.
                os.system("su - poco -c 'WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 wlr-randr --output DSI-1 --on --scale 2' >/dev/null 2>&1")
                time.sleep(0.1)
                with open(BRIGHTNESS_FILE, "w") as f:
                    f.write(str(val))
                log(f"Recovered DSI-1 output via wlr-randr and restored brightness to {val}")
            except Exception as e2:
                log(f"Recovery failed: {e2}")

class ScreenController:
    def __init__(self):
        self.saved_brightness = DEFAULT_BRIGHTNESS
        self.is_on = get_brightness() > 0
        self.last_activity = time.time()

    def turn_off(self):
        if not self.is_on:
            return
        curr = get_brightness()
        if curr > 0:
            self.saved_brightness = curr
        set_brightness(0)
        self.is_on = False
        log("Screen turned OFF (saving power & preventing AMOLED burn-in)")

    def turn_on(self):
        if self.is_on and get_brightness() > 0:
            self.last_activity = time.time()
            return
        target = self.saved_brightness if self.saved_brightness > 0 else DEFAULT_BRIGHTNESS
        # Ensure DSI-1 is on
        os.system("su - poco -c 'WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 wlr-randr --output DSI-1 --on --scale 2' >/dev/null 2>&1")
        time.sleep(0.05)
        set_brightness(target)
        self.is_on = True
        self.last_activity = time.time()
        log(f"Screen turned ON (brightness: {target})")

    def toggle(self):
        if self.is_on and get_brightness() > 0:
            self.turn_off()
        else:
            self.turn_on()

    def touch_activity(self):
        if not self.is_on or get_brightness() == 0:
            self.turn_on()
        else:
            self.last_activity = time.time()

def open_input_devices():
    fds = {}
    for dev_path in glob.glob("/dev/input/event*"):
        try:
            fd = os.open(dev_path, os.O_RDONLY | os.O_NONBLOCK)
            fds[fd] = dev_path
        except:
            pass
    return fds

def main():
    log("=== POCO F4 AMOLED Power & Idle Daemon Started ===")
    log(f"Idle timeout set to {IDLE_TIMEOUT_SECS} seconds.")
    
    screen = ScreenController()
    fds = open_input_devices()
    log(f"Monitoring {len(fds)} input devices: {list(fds.values())}")
    last_dev_scan = time.time()

    # struct input_event format: timeval (2x long), __u16 type, __u16 code, __s32 value
    # On arm64 Linux: 8 + 8 + 2 + 2 + 4 = 24 bytes
    EVENT_FORMAT = "qqHHi"
    EVENT_SIZE = struct.calcsize(EVENT_FORMAT)

    while True:
        now = time.time()

        # Rescan for newly attached USB input devices every 5 seconds
        if now - last_dev_scan > 5.0:
            current_paths = set(fds.values())
            for path in glob.glob("/dev/input/event*"):
                if path not in current_paths:
                    try:
                        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                        fds[fd] = path
                        log(f"Discovered new input device: {path}")
                    except:
                        pass
            last_dev_scan = now

        # Check idle timeout
        if screen.is_on and (now - screen.last_activity >= IDLE_TIMEOUT_SECS):
            screen.turn_off()

        # Wait for input events with a timeout of 1 second
        poll_timeout = 1.0
        rlist, _, _ = select.select(list(fds.keys()), [], [], poll_timeout)

        for fd in rlist:
            try:
                data = os.read(fd, EVENT_SIZE * 16)
                if not data:
                    continue
                
                # Parse events
                for i in range(0, len(data) - EVENT_SIZE + 1, EVENT_SIZE):
                    chunk = data[i:i+EVENT_SIZE]
                    sec, usec, ev_type, ev_code, ev_val = struct.unpack(EVENT_FORMAT, chunk)

                    # ev_type == 1 is EV_KEY
                    if ev_type == 1:
                        if ev_code == KEY_POWER and ev_val == 1: # Key down
                            log("Power button pressed -> Toggle screen")
                            screen.toggle()
                            break
                        elif ev_val in (1, 2): # Key down or repeat
                            screen.touch_activity()
                    elif ev_type in (2, 3): # EV_REL (mouse movement) or EV_ABS (touchscreen)
                        screen.touch_activity()
            except OSError:
                # Device disconnected
                try:
                    os.close(fd)
                except:
                    pass
                fds.pop(fd, None)

if __name__ == "__main__":
    main()
