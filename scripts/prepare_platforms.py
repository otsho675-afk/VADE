"""Prepare generated iOS metadata without touching signing credentials."""
from pathlib import Path
import plistlib

root = Path(__file__).resolve().parent.parent
info = root / "ios/Runner/Info.plist"
if info.exists():
    with info.open("rb") as stream:
        data = plistlib.load(stream)
    data["CFBundleDisplayName"] = "VADESİ"
    data["CFBundleName"] = "vadesi"
    with info.open("wb") as stream:
        plistlib.dump(data, stream)

# Current FlutterFire SDKs require iOS 15 or newer.
project = root / "ios/Runner.xcodeproj/project.pbxproj"
if project.exists():
    import re
    text = project.read_text()
    text = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 15.0;", text)
    project.write_text(text)
framework = root / "ios/Flutter/AppFrameworkInfo.plist"
if framework.exists():
    with framework.open("rb") as stream:
        data = plistlib.load(stream)
    data["MinimumOSVersion"] = "15.0"
    with framework.open("wb") as stream:
        plistlib.dump(data, stream)
podfile = root / "ios/Podfile"
if podfile.exists():
    text = podfile.read_text()
    import re
    text = re.sub(r"(?m)^[ \t]*#?[ \t]*platform :ios, '[^']+'", "platform :ios, '15.0'", text)
    podfile.write_text(text)

# Deliver local notifications while the iOS application is foregrounded.
delegate = root / "ios/Runner/AppDelegate.swift"
if delegate.exists():
    text = delegate.read_text()
    if "import UserNotifications" not in text:
        text = "import UserNotifications\n" + text
    if "UNUserNotificationCenter.current().delegate" not in text:
        marker = "return super.application("
        if marker not in text:
            raise RuntimeError("AppDelegate launch method changed; configure notification delegate manually.")
        text = text.replace(marker, "UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate\n    " + marker, 1)
    delegate.write_text(text)
