#!/usr/bin/env python3
"""Validate release versions and extract the reviewed changelog section."""
import argparse
import datetime
import pathlib
import re
import sys


def parse_tag(tag):
    if not re.fullmatch(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag):
        raise ValueError("Release tag must be vMAJOR.MINOR.PATCH (no prerelease or leading zeros).")
    return tag[1:]


def release_notes(changelog, version):
    sections = re.split(r"(?m)^(## .*)$", changelog)
    matches = []
    for heading, body in zip(sections[1::2], sections[2::2]):
        if re.match(r"^## \[" + re.escape(version) + r"\](?:\s|$)", heading):
            date = re.fullmatch(r"## \[" + re.escape(version) + r"\] - (\d{4}-\d{2}-\d{2})", heading)
            if not date:
                raise ValueError("Release heading must be ## [VERSION] - YYYY-MM-DD.")
            datetime.date.fromisoformat(date.group(1))
            if not re.search(r"(?m)^[-*] \S", body):
                raise ValueError("Release changelog must contain at least one bullet.")
            matches.append(heading + "\n\n" + body.strip() + "\n")
    if len(matches) != 1:
        raise ValueError("Expected exactly one dated changelog section for " + version)
    return matches[0]


def validate_project(root, version):
    source = (root / "project.yml").read_text()
    project = (root / "RSWriter.xcodeproj/project.pbxproj").read_text()
    source_values = re.findall(r"(?m)^\s*MARKETING_VERSION:\s*['\"]?([^\s'\"]+)", source)
    project_values = re.findall(r"MARKETING_VERSION = ([^;]+);", project)
    if not source_values or not project_values or any(value.strip('"') != version for value in source_values + project_values):
        raise ValueError("Tag must match MARKETING_VERSION in project.yml and the Xcode project.")
    if "<string>$(MARKETING_VERSION)</string>" not in (root / "Resources/Info.plist").read_text():
        raise ValueError("Info.plist must use MARKETING_VERSION.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parent.parent
    try:
        version = parse_tag(args.tag)
        validate_project(root, version)
        print(release_notes((root / "CHANGELOG.md").read_text(), version), end="")
    except (ValueError, OSError) as error:
        parser.exit(1, f"Release validation failed: {error}\n")


if __name__ == "__main__":
    main()
