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
