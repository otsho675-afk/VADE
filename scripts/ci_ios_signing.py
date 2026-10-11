#!/usr/bin/env python3
"""Configure App Store signing on an ephemeral GitHub macOS runner.

Only public signing metadata is written to the working tree. Never commit
.p12 certificates, provisioning profiles, or their passwords.
"""
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import plistlib
import re
import sys


BUNDLE_ID = "com.vadesi.vadesi"
PROJECT = Path("ios/Runner.xcodeproj/project.pbxproj")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: ci_ios_signing.py PROFILE_PLIST EXPORT_OPTIONS_PLIST")
    profile_path = Path(sys.argv[1])
    export_path = Path(sys.argv[2])
    profile = plistlib.loads(profile_path.read_bytes())

    team_ids = profile.get("TeamIdentifier") or []
    if len(team_ids) != 1 or not re.fullmatch(r"[A-Z0-9]{10}", team_ids[0]):
        raise SystemExit("Apple distribution profile has no valid TeamIdentifier.")
    team_id = team_ids[0]
    entitlements = profile.get("Entitlements") or {}
    app_id = entitlements.get("application-identifier")
    if app_id != f"{team_id}.{BUNDLE_ID}":
        raise SystemExit(f"Profile app identifier does not match {BUNDLE_ID}.")
    if entitlements.get("get-task-allow") is not False:
        raise SystemExit("Use an App Store distribution profile, not a development profile.")
    if profile.get("ProvisionedDevices") or profile.get("ProvisionsAllDevices"):
        raise SystemExit("Use an App Store distribution profile, not Ad Hoc/Enterprise.")
    expires = profile.get("ExpirationDate")
    if expires is not None:
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires <= datetime.now(timezone.utc):
            raise SystemExit("The iOS provisioning profile is expired.")

    profile_name = profile.get("Name")
    if not isinstance(profile_name, str) or not profile_name:
        raise SystemExit("The provisioning profile is missing a name.")
    if not PROJECT.is_file():
        raise SystemExit("Flutter iOS Xcode project does not exist.")

    # Apply manual signing to Runner's Release and Profile configurations
    # only. Test and Pods targets must not use the app provisioning profile.
    pbx = PROJECT.read_text(encoding="utf-8")
    pattern = re.compile(
        r"\t\t[A-F0-9]{24} /\* (Release|Profile) \*/ = \{\n.*?\n\t\t\};",
        re.DOTALL,
    )
    updated = [0]
    quoted_name = profile_name.replace("\\", "\\\\").replace('"', '\\"')

    def patch(match: re.Match[str]) -> str:
        block = match.group(0)
        if f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};" not in block:
            return block
        updated[0] += 1
        # This is a fresh checkout, but do not duplicate existing overrides.
        block = re.sub(
            r"(?m)^\s*(?:CODE_SIGN_STYLE|CODE_SIGN_IDENTITY|DEVELOPMENT_TEAM|PROVISIONING_PROFILE_SPECIFIER) = .*;\n",
            "",
            block,
        )
        settings = (
            "\t\t\t\tCODE_SIGN_STYLE = Manual;\n"
            '\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";\n'
            f"\t\t\t\tDEVELOPMENT_TEAM = {team_id};\n"
            f'\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{quoted_name}";\n'
        )
        return block.replace("buildSettings = {\n", "buildSettings = {\n" + settings, 1)

    modified = pattern.sub(patch, pbx)
    if updated[0] != 2:
        raise SystemExit(f"Expected Runner Release/Profile settings; found {updated[0]}.")
    PROJECT.write_text(modified, encoding="utf-8")

    export = {
        "method": "app-store-connect",
        "destination": "export",
        "signingStyle": "manual",
        "teamID": team_id,
        "provisioningProfiles": {BUNDLE_ID: profile_name},
        "manageAppVersionAndBuildNumber": False,
        "stripSwiftSymbols": True,
    }
    export_path.parent.mkdir(parents=True, exist_ok=True)
    export_path.write_bytes(plistlib.dumps(export))
    print(f"Signing prepared for {BUNDLE_ID}, Apple Team {team_id}.")


if __name__ == "__main__":
    main()
