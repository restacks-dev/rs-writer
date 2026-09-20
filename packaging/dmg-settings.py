"""Finder layout, written headlessly by dmgbuild (no AppleScript session needed)."""
from pathlib import Path

root = Path(defines["root"])
app = Path(defines["app"])
format = "UDZO"
filesystem = "HFS+"
files = [(str(app), "RS Writer.app")]
symlinks = {"Applications": "/Applications"}
background = str(root / "packaging/dmg-background.png")
# Finder's saved window height includes its title bar. Keep all 360 points
# of artwork visible below it.
window_rect = ((160, 160), (720, 392))
default_view = "icon-view"
show_toolbar = False
show_status_bar = False
show_tab_view = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False
arrange_by = None
icon_size = 96
text_size = 13
label_pos = "bottom"
# Do not set FinderInfo on the signed bundle; strict codesign rejects it.
hide_extensions = []
icon_locations = {
    "RS Writer.app": (180, 230),
    "Applications": (540, 230),
}
