#!/usr/bin/env python3
"""Fail when private game content appears in the repository worktree."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


FORBIDDEN_SUFFIXES = {
    ".gb",
    ".gbc",
    ".sgb",
    ".sav",
    ".srm",
    ".rtc",
    ".love",
    ".pcm16le",
    ".rgba",
    ".sym",
    ".map",
    ".noi",
}

FORBIDDEN_DIRECTORIES = {
    ("assets", "generated"),
    ("data", "generated"),
    ("cache",),
    ("private",),
    ("captures",),
    ("screenshots",),
    ("save",),
    ("saves",),
}

# Header logo bytes found in licensed Game Boy cartridge images. Metadata and
# source code should never contain this binary sequence.
GAME_BOY_LOGO = bytes.fromhex(
    "CE ED 66 66 CC 0D 00 0B 03 73 00 83 00 0C 00 0D "
    "00 08 11 1F 88 89 00 0E DC CC 6E E6 DD DD D9 99 "
    "BB BB 67 63 6E 0E EC CC DD DC 99 9F BB B9 33 3E"
)

MAX_UNREVIEWED_BINARY_SIZE = 1024 * 1024
TEXT_SAMPLE_SIZE = 8192


def repository_files(root: Path) -> list[Path]:
    command = [
        "git",
        "-C",
        str(root),
        "ls-files",
        "--cached",
        "--others",
        "--exclude-standard",
        "-z",
    ]
    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return [
            path
            for path in root.rglob("*")
            if path.is_file() and ".git" not in path.parts
        ]

    paths = []
    for raw in result.stdout.split(b"\0"):
        if raw:
            paths.append(root / raw.decode("utf-8", errors="surrogateescape"))
    return paths


def is_forbidden_directory(relative: Path) -> bool:
    lowered = tuple(part.lower() for part in relative.parts)
    for forbidden in FORBIDDEN_DIRECTORIES:
        if lowered[: len(forbidden)] == forbidden:
            return True
    return False


def appears_binary(path: Path) -> bool:
    with path.open("rb") as handle:
        sample = handle.read(TEXT_SAMPLE_SIZE)
    return b"\0" in sample


def inspect_file(root: Path, path: Path) -> list[str]:
    relative = path.relative_to(root)
    problems = []

    if path.suffix.lower() in FORBIDDEN_SUFFIXES:
        problems.append(f"{relative}: forbidden private/generated extension")

    if is_forbidden_directory(relative):
        problems.append(f"{relative}: file is inside a private/generated path")

    try:
        size = path.stat().st_size
        with path.open("rb") as handle:
            payload = handle.read()
    except OSError as error:
        return [f"{relative}: could not inspect file: {error}"]

    if GAME_BOY_LOGO in payload:
        problems.append(f"{relative}: contains a Game Boy cartridge header logo")

    if size > MAX_UNREVIEWED_BINARY_SIZE and appears_binary(path):
        problems.append(
            f"{relative}: unreviewed binary is larger than "
            f"{MAX_UNREVIEWED_BINARY_SIZE} bytes"
        )

    return problems


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root to inspect",
    )
    args = parser.parse_args()
    root = args.root.resolve()

    problems = []
    for path in repository_files(root):
        if path.is_file():
            problems.extend(inspect_file(root, path.resolve()))

    if problems:
        print("Repository content policy failed:", file=sys.stderr)
        for problem in problems:
            print(f"- {problem}", file=sys.stderr)
        return 1

    print("Repository content policy passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
