#!/usr/bin/env python3
"""
Animate system.txt banner using TerminalTextEffects.
Uses TTE CLI via subprocess for reliability.
Effect: beams — beam colors follow the matugen palette (same as AGS _theme.scss).
"""

from __future__ import annotations

import re
import sys
import os
from typing import Optional
import subprocess
import shutil
import termios
import tty


def _disable_terminal_input():
    try:
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        new_settings = termios.tcgetattr(fd)
        new_settings[3] = new_settings[3] & ~termios.ECHO & ~termios.ICANON
        termios.tcsetattr(fd, termios.TCSADRAIN, new_settings)
        return old_settings
    except (termios.error, OSError, AttributeError):
        return None


def _restore_terminal_input(old_settings):
    if old_settings is None:
        return
    try:
        fd = sys.stdin.fileno()
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    except (termios.error, OSError, AttributeError):
        pass


def get_matugen_colors_from_scss(
    theme_path: Optional[str] = None,
) -> Optional[dict[str, str]]:
    """Read $baseXX: #rrggbb from the matugen-generated AGS theme."""
    path = theme_path or os.path.expanduser(
        "~/.config/ags/styles/abstracts/_theme.scss"
    )
    if not os.path.isfile(path):
        return None
    colors: dict[str, str] = {}
    pat = re.compile(r"^\$base([0-9A-Fa-f]+):\s*#([0-9a-fA-F]{6})")
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = pat.match(line.strip())
            if m:
                key = "base" + m.group(1)
                colors[key] = "#" + m.group(2)
    return colors or None


def animate_beams(banner_file: str, frame_rate: int = 100) -> bool:
    if not os.path.exists(banner_file):
        return False

    tte_cmd = shutil.which("tte") or shutil.which("terminaltexteffects")
    if not tte_cmd:
        return False

    theme_colors = get_matugen_colors_from_scss()
    old_settings = _disable_terminal_input()

    try:
        cmd = [
            tte_cmd,
            "--frame-rate", str(frame_rate),
            "--input-file", banner_file,
            "beams",
            "--beam-delay", "5",
            "--beam-row-speed-range", "20-60",
            "--beam-column-speed-range", "10-20",
            "--final-wipe-speed", "2",
        ]

        if theme_colors:
            b = theme_colors.get("base0B", "#80d5d2")
            a = theme_colors.get("base0A", b)
            cmd.extend(["--beam-gradient-stops", b, a])
            cmd.extend(["--final-gradient-stops", b])

        with open(os.devnull, "r") as devnull:
            subprocess.run(cmd, stdin=devnull, check=True)
        return True
    except subprocess.CalledProcessError:
        return False
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return False
    finally:
        _restore_terminal_input(old_settings)


if __name__ == "__main__":
    banner_file = sys.argv[1] if len(sys.argv) > 1 else None
    frame_rate = int(sys.argv[2]) if len(sys.argv) > 2 else 100

    if not banner_file:
        sys.exit(1)

    success = animate_beams(banner_file, frame_rate)
    sys.exit(0 if success else 1)
