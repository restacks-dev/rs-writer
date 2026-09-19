#!/bin/bash
# Package only. Release signing and notarization are handled by release.sh.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app="${1:?Usage: scripts/make-dmg.sh APP_PATH OUTPUT_DMG}"
output="${2:?Usage: scripts/make-dmg.sh APP_PATH OUTPUT_DMG}"
[[ "$output" == *.dmg ]] || { echo 'Output must end in .dmg' >&2; exit 1; }
[[ -d "$app/Contents/MacOS" && -f "$app/Contents/Info.plist" ]] || {
  echo "Not an app bundle: $app" >&2; exit 1;
}
[[ ! -e "$output" ]] || { echo "Refusing to overwrite: $output" >&2; exit 1; }
for asset in packaging/dmg-background.png; do
  [[ -s "$root/$asset" ]] || { echo "Missing required asset: $asset" >&2; exit 1; }
done
app="$(cd "$(dirname "$app")" && pwd)/$(basename "$app")"
mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"
venv="$root/build/dmgbuild-venv"
if [[ ! -x "$venv/bin/python" ]]; then
  python3 -m venv "$venv"
fi
if ! "$venv/bin/python" - "$root/packaging/requirements.txt" <<'PY'
import importlib.metadata
import sys
try:
    for requirement in open(sys.argv[1]):
        name, version = requirement.strip().split("==")
        if importlib.metadata.version(name) != version:
            raise ValueError(requirement)
except (importlib.metadata.PackageNotFoundError, ValueError):
    sys.exit(1)
PY
then
  "$venv/bin/python" -m pip install --disable-pip-version-check -r "$root/packaging/requirements.txt"
fi

scratch="$(mktemp -d "${TMPDIR:-/tmp}/rs-writer-dmg.XXXXXX")"
mounted=0
cleanup() {
  local result=$?
  if [[ "$mounted" == 1 ]]; then
    hdiutil detach "$scratch/mount" -quiet || hdiutil detach "$scratch/mount" -force -quiet || true
  fi
  rm -rf "$scratch"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
volume_name='RS Writer'
[[ "$output" != *-UNSIGNED-PREVIEW.dmg ]] || volume_name='RS Writer — UNSIGNED PREVIEW'
"$venv/bin/dmgbuild" -s "$root/packaging/dmg-settings.py" \
  -D "root=$root" -D "app=$app" "$volume_name" "$scratch/installer.dmg"
hdiutil verify "$scratch/installer.dmg"
mkdir "$scratch/mount"
hdiutil attach "$scratch/installer.dmg" -mountpoint "$scratch/mount" -readonly -nobrowse -quiet
mounted=1
"$venv/bin/python" - "$scratch/mount" "$root" <<'PY'
from pathlib import Path
import plistlib
import sys
from ds_store import DSStore

mount, root = map(Path, sys.argv[1:])
app = mount / "RS Writer.app"
with (app / "Contents/Info.plist").open("rb") as source:
    info = plistlib.load(source)
assert (app / "Contents/MacOS" / info["CFBundleExecutable"]).is_file(), "Missing executable"
assert (mount / "Applications").is_symlink(), "Missing Applications symlink"
assert (mount / "Applications").readlink() == Path("/Applications"), "Wrong install target"
assert {item.name for item in mount.iterdir() if not item.name.startswith(".")} == {"RS Writer.app", "Applications"}, "Unexpected visible installer files"
assert (mount / ".background.png").read_bytes() == (root / "packaging/dmg-background.png").read_bytes()
with DSStore.open(str(mount / ".DS_Store"), "r") as store:
    bounds = store["."]["bwsp"]["WindowBounds"]
    assert bounds.replace(" ", "") == "{{160,160},{720,392}}", "Unexpected Finder window bounds"
    settings = store["."]["icvp"]
    assert settings["backgroundType"] == 2 and settings["backgroundImageAlias"], "Missing Finder background"
    assert settings["iconSize"] == 96, "Unexpected icon size"
    for name, position in {"RS Writer.app": (180, 230), "Applications": (540, 230)}.items():
        assert tuple(store[name]["Iloc"]) == position, f"Wrong position: {name}"
print("Verified app, install target, background and Finder layout.")
PY
hdiutil detach "$scratch/mount" -quiet
mounted=0
mv "$scratch/installer.dmg" "$output"
printf '\nDMG: %s\n' "$output"
