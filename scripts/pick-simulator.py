#!/usr/bin/env python3
"""Print the UDID of an available iPhone simulator.

Order of preference:
  1. A booted iPhone (matching NAME if given)
  2. An iPhone named NAME (newest iOS runtime first)
  3. Any iPhone on the newest installed iOS runtime (Pro models first)

Usage: scripts/pick-simulator.py [NAME]        e.g. scripts/pick-simulator.py "iPhone 17 Pro"
Exit code 1 (with a message on stderr) when no iPhone simulator is available.
"""
import json
import re
import subprocess
import sys


def runtime_version(key):
    match = re.search(r"iOS-(\d+)-(\d+)(?:-(\d+))?", key)
    return tuple(int(part or 0) for part in match.groups()) if match else (0, 0, 0)


def main():
    wanted = sys.argv[1].strip() if len(sys.argv) > 1 else ""
    try:
        raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
    except (OSError, subprocess.CalledProcessError) as exc:
        sys.exit("Could not list simulators (is Xcode installed and selected?): %s" % exc)

    devices = []
    for runtime, entries in json.loads(raw)["devices"].items():
        if "iOS" not in runtime:
            continue
        for device in entries:
            if device.get("isAvailable", True) and device["name"].startswith("iPhone"):
                devices.append((runtime_version(runtime), device))

    if not devices:
        sys.exit("No iPhone simulators found. Install an iOS runtime: Xcode > Settings > Components.")

    devices.sort(key=lambda item: item[0], reverse=True)
    newest = devices[0][0]

    def matches(device):
        return not wanted or device["name"] == wanted

    for _, device in devices:
        if device["state"] == "Booted" and matches(device):
            print(device["udid"])
            return
    if wanted:
        for _, device in devices:
            if device["name"] == wanted:
                print(device["udid"])
                return
        print("No simulator named %r; using the newest iPhone instead." % wanted, file=sys.stderr)

    on_newest = [d for version, d in devices if version == newest]
    on_newest.sort(key=lambda d: ("Pro" not in d["name"], "Max" in d["name"], d["name"]))
    print(on_newest[0]["udid"])


if __name__ == "__main__":
    main()
