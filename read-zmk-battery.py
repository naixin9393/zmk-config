#!/usr/bin/env python3
"""Read split-half battery levels from the ZMK dongle's USB HID battery interface.

The firmware module (zmk-usb-reporting) exposes a second HID interface with two
HID Feature reports on the Power Device usage page:
    report 0x05 -> peripheral 0 (left)
    report 0x06 -> peripheral 1 (right)
This reads them directly via the HIDRAW HIDIOCGFEATURE ioctl. No third-party
packages required.

Usage: read-zmk-battery.py [/dev/hidrawN | /dev/zmk-battery]
"""

import fcntl
import glob
import os
import sys

# HIDIOCGFEATURE(len) = _IOC(_IOC_READ|_IOC_WRITE, 'H', 0x07, len)
HIDIOCGFEATURE = lambda n: (3 << 30) | (n << 16) | (ord("H") << 8) | 0x07

BATTERY_REPORTS = ((0x05, "peripheral-0 (left)"), (0x06, "peripheral-1 (right)"))


def find_battery_hidraw():
    if os.path.exists("/dev/zmk-battery"):
        return "/dev/zmk-battery"
    for path in sorted(glob.glob("/dev/hidraw*")):
        name = os.path.basename(path)
        try:
            desc = open(
                f"/sys/class/hidraw/{name}/device/report_descriptor", "rb"
            ).read()
        except OSError:
            continue
        # Power Device page (0x84) + report id 0x05 in the report descriptor
        if b"\x05\x84" in desc and b"\x85\x05" in desc:
            return path
    return None


def get_feature(fd, report_id):
    buf = bytearray(2)  # [report_id, level]
    buf[0] = report_id
    fcntl.ioctl(fd, HIDIOCGFEATURE(2), buf, True)
    return buf[1]


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else find_battery_hidraw()
    if not path:
        print("ZMK battery HID interface not found", file=sys.stderr)
        return 1

    fd = os.open(path, os.O_RDWR)
    try:
        print(f"interface: {path}")
        for report_id, label in BATTERY_REPORTS:
            level = get_feature(fd, report_id)
            print(f"  {label:24s} {level}%")
    finally:
        os.close(fd)
    return 0


if __name__ == "__main__":
    sys.exit(main())
