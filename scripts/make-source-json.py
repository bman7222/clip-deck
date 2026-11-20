#!/usr/bin/env python3
"""Build or check the SideStore / AltStore source file (apps.json) for Clip Deck.

  python scripts/make-source-json.py --out apps.json              # fetch the releases from GitHub
  python scripts/make-source-json.py --releases rel.json --out apps.json   # use a saved release list
  python scripts/make-source-json.py --check apps.json            # validate a file, exit 1 if broken

Which releases go in: published (not draft), NOT pre-release, tag like v1.2.3 (no leading zeros), with a
ClipDeck.ipa asset and a "Build number: N" line in the notes (release.yml writes it). Anything else is skipped
with a warning on stderr. Pre-releases (rc tags) are left out on purpose: they would show up as updates.

Format: SideStore (AltStore source format, "versions" list). See docs/INSTALL_ON_IPHONE.md and
.loop/tasks/T-010-sidestore-source.md for the cited SideStore code. Python standard library only.
"""
import argparse
import json
import os
import re
import sys
import urllib.request
from urllib.parse import urlparse

DEFAULT_REPO = "bman7222/clip-deck"
BUNDLE_ID = "dev.brent.clipdeck"
IPA_NAME = "ClipDeck.ipa"
ICON_PATH = "ios/ClipDeck/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
TAG_RE = re.compile(r"^v((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))$")
BUILD_RE = re.compile(r"^Build number: ([0-9]+)[ \t]*\r?$", re.MULTILINE)
SHA_RE = re.compile(r"^sha256:([0-9a-fA-F]{64})$")

APP_KEYS = ["name", "bundleIdentifier", "developerName", "iconURL", "localizedDescription", "versions"]
VERSION_KEYS = ["version", "buildVersion", "date", "downloadURL", "size", "minOSVersion", "localizedDescription"]


def fetch_releases(repo):
    """All releases of the repo from the public GitHub API (GH_TOKEN/GITHUB_TOKEN is used if set)."""
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    out, page = [], 1
    while True:
        req = urllib.request.Request(
            f"https://api.github.com/repos/{repo}/releases?per_page=100&page={page}",
            headers={"Accept": "application/vnd.github+json", "User-Agent": "clip-deck-source-builder"},
        )
        if token:
            req.add_header("Authorization", f"Bearer {token}")
        with urllib.request.urlopen(req, timeout=60) as r:
            batch = json.load(r)
        out.extend(batch)
        if len(batch) < 100:
            return out
        page += 1


def build_versions(releases, warn=lambda m: print(m, file=sys.stderr)):
    versions = []
    for rel in releases:
        tag = rel.get("tag_name") or ""
        if rel.get("draft") or rel.get("prerelease"):
            continue  # drafts are unpublished; pre-releases are deliberately left out
        m = TAG_RE.match(tag)
        if not m:
            warn(f"skip {tag!r}: tag is not like v1.2.3")
            continue
        asset = next((a for a in rel.get("assets") or [] if a.get("name") == IPA_NAME), None)
        if not asset or not asset.get("browser_download_url") or not isinstance(asset.get("size"), int):
            warn(f"skip {tag}: no {IPA_NAME} asset")
            continue
        body = rel.get("body") or ""
        b = BUILD_RE.search(body)
        if not b:
            warn(f"skip {tag}: notes have no 'Build number: N' line")
            continue
        if not rel.get("published_at"):
            warn(f"skip {tag}: no published_at")
            continue
        notes = re.sub(r"\n{3,}", "\n\n", BUILD_RE.sub("", body)).strip()
        v = {
            "version": m.group(1),
            "buildVersion": b.group(1),
            "date": rel["published_at"],
            "downloadURL": asset["browser_download_url"],
            "size": asset["size"],
            "minOSVersion": "17.0",
            "localizedDescription": notes or f"Clip Deck {m.group(1)}",
        }
        sm = SHA_RE.match(asset.get("digest") or "")
        if sm:  # SideStore checks it when present (VerifyAppOperation)
            v["sha256"] = sm.group(1).lower()
        versions.append((rel["published_at"], v))
    versions.sort(key=lambda t: t[0], reverse=True)  # ISO 8601 UTC strings sort by time
    return [v for _, v in versions]


def build_source(releases, repo=DEFAULT_REPO, warn=lambda m: print(m, file=sys.stderr)):
    versions = build_versions(releases, warn)
    if not versions:
        raise SystemExit("error: no stable release with a ClipDeck.ipa found; nothing to publish")
    newest_tag = "v" + versions[0]["version"]
    return {
        "name": "Clip Deck",
        "identifier": BUNDLE_ID + ".source",
        "subtitle": "Updates for Clip Deck",
        "apps": [{
            "name": "Clip Deck",
            "bundleIdentifier": BUNDLE_ID,
            "developerName": "Brent",
            "subtitle": "Learn from your own videos",
            "localizedDescription": (
                "Offline video player for language learners: watch your own episodes with SRT/ASS subtitles "
                "and turn a subtitle line into an Anki card (audio clip, screenshot, sentence)."
            ),
            "iconURL": f"https://raw.githubusercontent.com/{repo}/{newest_tag}/{ICON_PATH}",
            "versions": versions,
        }],
    }


def check_source(data):
    """Return a list of problems (empty = valid)."""
    errs = []

    def need(obj, keys, where):
        if not isinstance(obj, dict):
            errs.append(f"{where}: not an object")
            return False
        for k in keys:
            if k not in obj or obj[k] in (None, ""):
                errs.append(f"{where}: missing '{k}'")
        return True

    def https_url(val, where):
        u = urlparse(val) if isinstance(val, str) else None
        if not u or u.scheme != "https" or not u.netloc:
            errs.append(f"{where}: not an absolute https URL: {val!r}")

    if not need(data, ["name", "identifier", "apps"], "source") or "apps" not in data:
        return errs
    if not isinstance(data["apps"], list) or not data["apps"]:
        errs.append("source: 'apps' must be a non-empty list")
        return errs
    for i, app in enumerate(data["apps"]):
        w = f"apps[{i}]"
        if not need(app, APP_KEYS, w):
            continue
        https_url(app.get("iconURL"), f"{w}.iconURL")
        vs = app.get("versions")
        if not isinstance(vs, list) or not vs:
            errs.append(f"{w}: 'versions' must be a non-empty list")
            continue
        for j, v in enumerate(vs):
            vw = f"{w}.versions[{j}]"
            if not need(v, VERSION_KEYS, vw):
                continue
            https_url(v.get("downloadURL"), f"{vw}.downloadURL")
            if not isinstance(v.get("size"), int) or isinstance(v.get("size"), bool) or v["size"] <= 0:
                errs.append(f"{vw}: 'size' must be a positive integer")
            if not re.match(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(Z|[+-]\d\d:\d\d)$", str(v.get("date"))):
                errs.append(f"{vw}: 'date' must be ISO 8601 with a time zone, like 2026-11-20T10:00:00Z")
            if "sha256" in v and not re.match(r"^[0-9a-f]{64}$", str(v["sha256"])):
                errs.append(f"{vw}: 'sha256' must be 64 lowercase hex characters")
        dates = [v.get("date", "") for v in vs if isinstance(v, dict)]
        if dates != sorted(dates, reverse=True):
            errs.append(f"{w}: versions are not newest first")
    return errs


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--check", metavar="FILE", help="validate an existing apps.json and exit")
    p.add_argument("--releases", metavar="FILE", help="read the release list (GitHub API JSON) from a file")
    p.add_argument("--repo", default=DEFAULT_REPO)
    p.add_argument("--out", default="apps.json")
    a = p.parse_args(argv)

    if a.check:
        try:
            with open(a.check, encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, ValueError) as e:
            print(f"FAIL {a.check}: {e}", file=sys.stderr)
            return 1
        errs = check_source(data)
        for e in errs:
            print(f"::error::{a.check}: {e}" if os.environ.get("GITHUB_ACTIONS") else f"FAIL {e}", file=sys.stderr)
        if not errs:
            print(f"ok: {a.check}")
        return 1 if errs else 0

    if a.releases:
        with open(a.releases, encoding="utf-8") as f:
            releases = json.load(f)
    else:
        releases = fetch_releases(a.repo)
    data = build_source(releases, a.repo)
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"wrote {a.out}: {len(data['apps'][0]['versions'])} version(s), newest {data['apps'][0]['versions'][0]['version']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
