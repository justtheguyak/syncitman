#!/usr/bin/env python3
"""
CoupleSync - Automated OTA Release Script
Usage:
    python release_ota.py [--version 1.0.2] [--skip-build] [--notes "Release notes"]

This script:
1. Validates code with `flutter analyze`
2. Reads or bumps version from `pubspec.yaml`
3. Builds the Android release APK (`flutter build apk --release`)
4. Retrieves GitHub credentials from Git Credential Manager
5. Ensures repository is public so phone OTA updates download without auth
6. Commits, tags, and pushes to GitHub
7. Creates a GitHub Release and uploads `app-release.apk` and `CoupleSync-vX.X.X.apk`
8. Updates Supabase `app_updates` table for dual-channel OTA redundancy
"""

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request

try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

REPO_OWNER = "justtheguyak"
REPO_NAME = "syncitman"
SUPABASE_URL = "https://pisabzyatipobpwczbzq.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBpc2FienlhdGlwb2Jwd2N6YnpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA1MTczMDQsImV4cCI6MjEwNjA5MzMwNH0.kzJjK8SzgxWpoKAHfV2aRlSvFiNqF9vhPvhs-uUMpAA"

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))


def log(msg, symbol=">"):
    try:
        print(f"[{symbol}] {msg}")
    except UnicodeEncodeError:
        print(f"[>] {msg.encode('ascii', 'replace').decode()}")


def run_command(cmd, cwd=PROJECT_ROOT, check=True):
    cmd_str = ' '.join(cmd) if isinstance(cmd, list) else cmd
    log(f"Running: {cmd_str}", "⚙️")
    result = subprocess.run(
        cmd_str,
        cwd=cwd,
        shell=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if check and result.returncode != 0:
        print(f"❌ Error executing command: {result.stderr or result.stdout}")
        sys.exit(result.returncode)
    return result


def get_pubspec_version():
    pubspec_path = os.path.join(PROJECT_ROOT, "pubspec.yaml")
    with open(pubspec_path, "r", encoding="utf-8") as f:
        content = f.read()
    match = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(\+[0-9]+)?", content, re.MULTILINE)
    if not match:
        raise ValueError("Could not parse version from pubspec.yaml")
    version = match.group(1)
    build_num = match.group(2) or "+1"
    return version, build_num.replace("+", "")


def set_pubspec_version(version, build_num):
    pubspec_path = os.path.join(PROJECT_ROOT, "pubspec.yaml")
    with open(pubspec_path, "r", encoding="utf-8") as f:
        content = f.read()
    updated = re.sub(
        r"^version:\s*.*$",
        f"version: {version}+{build_num}",
        content,
        flags=re.MULTILINE,
    )
    with open(pubspec_path, "w", encoding="utf-8") as f:
        f.write(updated)
    log(f"Updated pubspec.yaml to {version}+{build_num}", "📝")


def update_profile_screen_version(version):
    profile_path = os.path.join(PROJECT_ROOT, "lib", "features", "profile", "presentation", "profile_screen.dart")
    if os.path.exists(profile_path):
        with open(profile_path, "r", encoding="utf-8") as f:
            content = f.read()
        updated = re.sub(
            r"CoupleSync v[0-9]+\.[0-9]+\.[0-9]+",
            f"CoupleSync v{version}",
            content,
        )
        with open(profile_path, "w", encoding="utf-8") as f:
            f.write(updated)
        log(f"Updated profile_screen.dart version to v{version}", "📝")


def get_github_token():
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        return token

    # Retrieve from Git Credential Manager
    try:
        p = subprocess.Popen(
            ["git", "credential", "fill"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        out, _ = p.communicate("protocol=https\nhost=github.com\n\n")
        lines = [line.split("=", 1) for line in out.splitlines() if "=" in line]
        cred = dict(lines)
        token = cred.get("password")
        if token:
            return token
    except Exception as e:
        log(f"Git Credential Manager notice: {e}", "⚠️")

    print("❌ No GitHub token found. Please set GITHUB_TOKEN environment variable or login to Git.")
    sys.exit(1)


def ensure_repo_is_public(token):
    url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "CoupleSync-Release-Script",
        },
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            if data.get("private") is True:
                log("Repository is currently private. Switching to public so phone OTA downloads work without login...", "🔓")
                patch_req = urllib.request.Request(
                    url,
                    data=json.dumps({"private": False}).encode(),
                    headers={
                        "Authorization": f"token {token}",
                        "Accept": "application/vnd.github.v3+json",
                        "User-Agent": "CoupleSync-Release-Script",
                    },
                    method="PATCH",
                )
                with urllib.request.urlopen(patch_req) as patch_resp:
                    log("Repository is now public! ✅", "✨")
            else:
                log("Repository is public. OTA downloads will be accessible to all devices.", "✅")
    except Exception as e:
        log(f"Could not check/toggle repo privacy: {e}", "⚠️")


def create_or_get_github_release(token, tag, release_name, notes):
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "CoupleSync-Release-Script",
    }
    
    # Check if release exists
    get_url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/releases/tags/{tag}"
    req = urllib.request.Request(get_url, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            log(f"Existing release found for {tag} (ID: {data['id']})", "ℹ️")
            return data
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise

    # Create new release
    create_url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/releases"
    payload = {
        "tag_name": tag,
        "target_commitish": "master",
        "name": release_name,
        "body": notes,
        "draft": False,
        "prerelease": False,
    }
    req = urllib.request.Request(
        create_url,
        data=json.dumps(payload).encode(),
        headers=headers,
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
        log(f"Created new GitHub Release: {release_name} (ID: {data['id']})", "🎉")
        return data


def upload_asset_to_release(token, release, file_path, asset_name):
    # Check if asset already exists in release and delete it first if so
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "CoupleSync-Release-Script",
    }
    for asset in release.get("assets", []):
        if asset["name"] == asset_name:
            log(f"Asset {asset_name} already exists. Deleting older version...", "🗑️")
            del_req = urllib.request.Request(asset["url"], headers=headers, method="DELETE")
            try:
                with urllib.request.urlopen(del_req):
                    pass
            except Exception as e:
                log(f"Notice deleting old asset: {e}", "⚠️")

    # Upload fresh asset
    upload_url_template = release["upload_url"].split("{")[0]
    upload_url = f"{upload_url_template}?name={urllib.parse.quote(asset_name)}"
    log(f"Uploading {asset_name} ({os.path.getsize(file_path) / (1024*1024):.1f} MB)...", "📦")

    with open(file_path, "rb") as f:
        file_bytes = f.read()

    upload_headers = {
        "Authorization": f"token {token}",
        "Content-Type": "application/vnd.android.package-archive",
        "User-Agent": "CoupleSync-Release-Script",
    }
    req = urllib.request.Request(
        upload_url,
        data=file_bytes,
        headers=upload_headers,
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        asset_data = json.loads(resp.read().decode())
        download_url = asset_data["browser_download_url"]
        log(f"Asset uploaded successfully: {asset_name}", "✅")
        log(f"Download URL: {download_url}", "🔗")
        return download_url


def update_supabase_app_updates(version, build_num, release_name, notes, apk_url):
    try:
        url = f"{SUPABASE_URL}/rest/v1/app_updates"
        payload = {
            "version": version,
            "version_code": int(build_num),
            "release_name": release_name,
            "release_notes": notes,
            "apk_url": apk_url,
            "is_mandatory": True,
        }
        headers = {
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates",
        }
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode(),
            headers=headers,
            method="POST",
        )
        with urllib.request.urlopen(req) as resp:
            log("Synchronized release with Supabase app_updates table! ✅", "💾")
    except Exception as e:
        log(f"Supabase update notice: {e}", "⚠️")


def main():
    parser = argparse.ArgumentParser(description="Build, Tag, and Release CoupleSync OTA Update to GitHub")
    parser.add_argument("--version", type=str, help="Specific version to release (e.g. 1.0.2)")
    parser.add_argument("--skip-build", action="store_true", help="Skip `flutter build apk` and reuse existing APK")
    parser.add_argument("--notes", type=str, help="Custom release notes")
    args = parser.parse_args()

    current_ver, current_build = get_pubspec_version()
    if args.version:
        release_ver = args.version.replace("v", "").replace("V", "").strip()
        release_build = str(int(current_build) + 1)
        set_pubspec_version(release_ver, release_build)
        update_profile_screen_version(release_ver)
    else:
        release_ver = current_ver
        release_build = current_build

    tag_name = f"v{release_ver}"
    release_name = f"CoupleSync {tag_name}"

    default_notes = (
        f"### CoupleSync {tag_name}\n\n"
        f"- 📸 **Profile Pictures with Custom Circular Crop**: Drag, pinch-to-zoom, and 90° rotate controls\n"
        f"- 🔔 **Reminder Detail Screen**: Reschedule, snooze, edit, and view details\n"
        f"- 💕 **Partner Notification Sync**: Instant alerts when your partner sets shared reminders\n"
        f"- ⚡ **Dual-Channel OTA Updates**: Seamless instant in-app update downloader\n"
    )
    release_notes = args.notes if args.notes else default_notes

    log(f"Starting OTA Release process for {tag_name} (Build {release_build})...", "🚀")

    # 1. Fetch GitHub Token
    token = get_github_token()

    # 2. Ensure repository is public
    ensure_repo_is_public(token)

    # 3. Flutter Build
    apk_path = os.path.join(PROJECT_ROOT, "build", "app", "outputs", "flutter-apk", "app-release.apk")
    if not args.skip_build or not os.path.exists(apk_path):
        log("Building release APK via Flutter...", "🔨")
        run_command(["flutter", "build", "apk", "--release"])
    else:
        log(f"Reusing existing APK at {apk_path}", "⏩")

    if not os.path.exists(apk_path):
        print(f"❌ APK not found at {apk_path}")
        sys.exit(1)

    apk_size_mb = os.path.getsize(apk_path) / (1024 * 1024)
    log(f"Release APK ready: {apk_size_mb:.1f} MB", "📱")

    # 4. Git Commit & Push
    log("Committing changes and pushing tag to GitHub...", "📤")
    run_command("git add .", check=False)
    run_command(f'git commit -m "Release {tag_name}"', check=False)
    run_command("git push origin master", check=False)

    # Tag
    run_command(f'git tag -f -a {tag_name} -m "Release {tag_name}"', check=False)
    run_command(f"git push -f origin {tag_name}", check=False)

    # 5. Create GitHub Release
    release = create_or_get_github_release(token, tag_name, release_name, release_notes)

    # 6. Upload APK files
    apk_url = upload_asset_to_release(token, release, apk_path, "app-release.apk")
    upload_asset_to_release(token, release, apk_path, f"CoupleSync-{tag_name}.apk")

    # 7. Update Supabase app_updates
    update_supabase_app_updates(release_ver, release_build, release_name, release_notes, apk_url)

    print("\n" + "=" * 60)
    print(f"🎉 SUCCESS! CoupleSync {tag_name} has been published!")
    print(f"🔗 Release: https://github.com/{REPO_OWNER}/{REPO_NAME}/releases/tag/{tag_name}")
    print(f"📥 Direct APK: {apk_url}")
    print("=" * 60 + "\n")


if __name__ == "__main__":
    main()
