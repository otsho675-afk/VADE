"""Package sources plus generated native hosts; exclude caches and credentials."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parent.parent
excluded_dirs = {".git", ".dart_tool", ".idea", ".vscode", ".gradle",
                 "build", "dist", "node_modules", "Pods", ".symlinks", "ephemeral", "__pycache__"}
excluded_names = {"local.properties", "key.properties", ".DS_Store",
                  ".flutter-plugins", ".flutter-plugins-dependencies", ".env"}
(root / "dist").mkdir(exist_ok=True)
with ZipFile(root / "dist/VADESI.zip", "w", ZIP_DEFLATED) as archive:
    for path in sorted(root.rglob("*")):
        rel = path.relative_to(root)
        if not path.is_file() or path.is_symlink():
            continue
        if any(part in excluded_dirs for part in rel.parts):
            continue
        if path.name in excluded_names or path.suffix in {".jks", ".keystore", ".p12", ".mobileprovision", ".p8"}:
            continue
        if path.name.startswith(".env") or (rel.parts[0] == "config" and not path.name.endswith(".example.json")):
            continue
        if str(rel) == "backend/admin/config.js" or "service-account" in path.name:
            continue
        archive.write(path, Path("VADESI") / rel)
