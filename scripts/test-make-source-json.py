#!/usr/bin/env python3
"""Unit check for make-source-json.py. Run: python scripts/test-make-source-json.py (exit 0 = pass)."""
import copy
import importlib.util
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("mk", os.path.join(HERE, "make-source-json.py"))
mk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mk)

URL = "https://github.com/bman7222/clip-deck/releases/download"
SHA = "ab" * 32


def rel(tag, when, build="7", pre=False, draft=False, size=1000, assets=True, body=None, digest=True):
    return {
        "tag_name": tag, "prerelease": pre, "draft": draft, "published_at": when,
        "body": body if body is not None else f"Unsigned build.\nBuild number: {build}\n\n### Third-party software\nFFmpeg.",
        "assets": [
            {"name": "ClipDeck.ipa", "size": size, "browser_download_url": f"{URL}/{tag}/ClipDeck.ipa",
             "digest": f"sha256:{SHA}" if digest else None},
            {"name": "ClipDeck.ipa.sha256", "size": 79, "browser_download_url": f"{URL}/{tag}/ClipDeck.ipa.sha256"},
        ] if assets else [],
    }


FIXTURE = [
    rel("v0.2.0", "2026-11-21T09:00:00Z", build="12", size=5000),
    rel("v0.3.0-rc1", "2026-11-22T09:00:00Z", pre=True),        # pre-release: excluded
    rel("v0.4.0", "2026-11-23T09:00:00Z", draft=True),          # draft: excluded
    rel("v0.1.1", "2026-11-20T09:00:00Z", build="3", digest=False),
    rel("v01.2.3", "2026-11-19T09:00:00Z"),                     # leading zero: skipped
    rel("v0.1.0", "2026-11-18T09:00:00Z", assets=False),        # no IPA: skipped
    rel("v0.0.9", "2026-11-17T09:00:00Z", body="no build line"),  # skipped
    rel("nightly", "2026-11-16T09:00:00Z"),                     # not a version tag: skipped
]

failures = []


def expect(cond, msg):
    if not cond:
        failures.append(msg)
        print("FAIL", msg)


warnings = []
data = mk.build_source(FIXTURE, warn=warnings.append)
app = data["apps"][0]
vs = app["versions"]
expect(data["name"] == "Clip Deck" and data["identifier"], "source name/identifier")
expect(app["bundleIdentifier"] == "dev.brent.clipdeck" and app["name"] == "Clip Deck", "app ids")
expect([v["version"] for v in vs] == ["0.2.0", "0.1.1"], f"versions newest first, stable only: {[v['version'] for v in vs]}")
expect(vs[0] == {
    "version": "0.2.0", "buildVersion": "12", "date": "2026-11-21T09:00:00Z",
    "downloadURL": f"{URL}/v0.2.0/ClipDeck.ipa", "size": 5000, "minOSVersion": "17.0",
    "localizedDescription": "Clip Deck 0.2.0. What's new: https://github.com/bman7222/clip-deck/releases/tag/v0.2.0",
    "sha256": SHA,
}, f"first version exact: {vs[0]}")
expect("sha256" not in vs[1], "no sha256 when the release has no digest")
expect(app["iconURL"].startswith("https://raw.githubusercontent.com/bman7222/clip-deck/v0.2.0/"), "icon at newest tag")
expect(len(warnings) == 4, f"4 skip warnings, got {warnings}")
expect(mk.check_source(data) == [], f"generated file passes check: {mk.check_source(data)}")
expect("download" not in vs[0]["localizedDescription"].lower() and "share" not in vs[0]["localizedDescription"].lower(),
       "SideStore notes do not tell the user to download and share the IPA")

# A hotfix for an older line published AFTER the newer release: v0.3.0 first, then v0.2.1 (published later).
hotfix = mk.build_source([
    rel("v0.2.0", "2026-11-21T09:00:00Z", build="12"),
    rel("v0.3.0", "2026-11-22T09:00:00Z", build="20"),
    rel("v0.2.1", "2026-11-23T09:00:00Z", build="21"),
    rel("v0.10.0", "2026-11-24T09:00:00Z", build="22"),
], warn=lambda m: None)
hv = [v["version"] for v in hotfix["apps"][0]["versions"]]
expect(hv == ["0.10.0", "0.3.0", "0.2.1", "0.2.0"], f"ordered by semantic version, not date: {hv}")
hotfix2 = mk.build_source([
    rel("v0.3.0", "2026-11-22T09:00:00Z", build="20"),
    rel("v0.2.1", "2026-11-23T09:00:00Z", build="21"),
], warn=lambda m: None)
expect([v["version"] for v in hotfix2["apps"][0]["versions"]] == ["0.3.0", "0.2.1"], "v0.3.0 stays first after a later v0.2.1")
expect(hotfix2["apps"][0]["iconURL"].startswith("https://raw.githubusercontent.com/bman7222/clip-deck/v0.3.0/"),
       "icon comes from the newest version's tag")
expect(mk.check_source(hotfix2) == [], "semver-ordered file passes check")

# Tester (T-013): v0.10.0 published BEFORE v0.3.0. Date order and string order both put 0.3.0 first; only a
# numeric version sort puts 0.10.0 first. check_source must also judge order by number, not by date or text.
early = mk.build_source([
    rel("v0.3.0", "2026-11-25T09:00:00Z", build="30"),
    rel("v0.10.0", "2026-11-24T09:00:00Z", build="22"),
    rel("v0.9.1", "2026-11-26T09:00:00Z", build="31"),
], warn=lambda m: None)
ev = [v["version"] for v in early["apps"][0]["versions"]]
expect(ev == ["0.10.0", "0.9.1", "0.3.0"], f"0.10.0 first even when published before 0.3.0: {ev}")
expect(early["apps"][0]["iconURL"].startswith("https://raw.githubusercontent.com/bman7222/clip-deck/v0.10.0/"),
       "icon from v0.10.0")
expect(mk.check_source(early) == [], f"numeric order passes check: {mk.check_source(early)}")
swapped = copy.deepcopy(early)
vs_ = swapped["apps"][0]["versions"]
vs_[0], vs_[2] = vs_[2], vs_[0]  # 0.3.0, 0.9.1, 0.10.0: dates newest first, numbers not
expect(mk.check_source(swapped) != [], "check rejects 0.3.0 listed before 0.10.0")
expect(early["apps"][0]["versions"][0]["localizedDescription"]
       == "Clip Deck 0.10.0. What's new: https://github.com/bman7222/clip-deck/releases/tag/v0.10.0",
       "notes point to the release page")
withurl = mk.build_source([dict(rel("v1.0.0", "2026-11-27T09:00:00Z", build="40"),
                                html_url="https://github.com/bman7222/clip-deck/releases/tag/v1.0.0")],
                         warn=lambda m: None)
expect(withurl["apps"][0]["versions"][0]["localizedDescription"].endswith("/releases/tag/v1.0.0"), "html_url used")

# Checks that must fail.
def broken(mutator, label):
    d = copy.deepcopy(data)
    mutator(d)
    expect(mk.check_source(d) != [], f"check should fail: {label}")


broken(lambda d: d["apps"][0]["versions"][0].update(downloadURL="http://x/y.ipa"), "http URL")
broken(lambda d: d["apps"][0]["versions"][0].update(downloadURL="/relative.ipa"), "relative URL")
broken(lambda d: d["apps"][0]["versions"][0].pop("size"), "missing size")
broken(lambda d: d["apps"][0]["versions"][0].update(size=0), "zero size")
broken(lambda d: d["apps"][0].pop("bundleIdentifier"), "missing bundleIdentifier")
broken(lambda d: d["apps"][0].update(versions=[]), "empty versions")
broken(lambda d: d["apps"][0]["versions"][0].update(date="2026-11-21"), "date without time")
broken(lambda d: d["apps"][0]["versions"][0].update(version="v0.2"), "malformed version")
broken(lambda d: d["apps"][0]["versions"].reverse(), "oldest first")
broken(lambda d: d.pop("apps"), "no apps")
broken(lambda d: d["apps"][0].update(iconURL="icon.png"), "relative icon")

# No stable release at all is an error, not an empty file.
try:
    mk.build_source([rel("v1.0.0-rc1", "2026-11-20T09:00:00Z", pre=True)], warn=lambda m: None)
    expect(False, "no stable release should exit")
except SystemExit:
    pass

# CLI round trip, including --check on a broken file.
with tempfile.TemporaryDirectory() as d:
    rp, op, bp = (os.path.join(d, n) for n in ("rel.json", "apps.json", "bad.json"))
    with open(rp, "w") as f:
        json.dump(FIXTURE, f)
    script = os.path.join(HERE, "make-source-json.py")
    r = subprocess.run([sys.executable, script, "--releases", rp, "--out", op], capture_output=True, text=True)
    expect(r.returncode == 0, f"cli build: {r.stderr}")
    r = subprocess.run([sys.executable, script, "--check", op], capture_output=True, text=True)
    expect(r.returncode == 0, f"cli check good: {r.stderr}")
    with open(op) as f:
        bad = json.load(f)
    bad["apps"][0]["versions"][0]["downloadURL"] = "http://nope"
    with open(bp, "w") as f:
        json.dump(bad, f)
    r = subprocess.run([sys.executable, script, "--check", bp], capture_output=True, text=True)
    expect(r.returncode == 1, "cli check bad exits 1")
    with open(bp, "w") as f:
        f.write("{not json")
    r = subprocess.run([sys.executable, script, "--check", bp], capture_output=True, text=True)
    expect(r.returncode == 1, "cli check invalid json exits 1")

print("FAILED" if failures else "all checks passed")
sys.exit(1 if failures else 0)
