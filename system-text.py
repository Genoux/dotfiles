#!/usr/bin/env python3
"""
Animate system.txt banner using TerminalTextEffects.
Uses TTE CLI via subprocess for reliability.
Effect: beams - beams travel over canvas illuminating characters
"""

import sys
import os
import subprocess
import shutil
import yaml
import termios
import tty
from pathlib import Path

def _disable_terminal_input():
    """Disable terminal input to prevent keyboard input during animation."""
    try:
        # Save current terminal settings
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        # Create new settings: disable echo and canonical mode
        new_settings = termios.tcgetattr(fd)
        # Disable echo (ECHO) and canonical mode (ICANON)
        new_settings[3] = new_settings[3] & ~termios.ECHO & ~termios.ICANON
        # Apply new settings
        termios.tcsetattr(fd, termios.TCSADRAIN, new_settings)
        return old_settings
    except (termios.error, OSError, AttributeError):
        # If we can't modify terminal settings, return None
        return None

def _restore_terminal_input(old_settings):
    """Restore terminal input settings."""
    if old_settings is None:
        return
    try:
        fd = sys.stdin.fileno()
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    except (termios.error, OSError, AttributeError):
        pass

def get_flavours_colors():
    """Get current flavours theme colors from scheme file.
    Returns dict with base00-base0F colors from current theme."""
    # Try to get current theme from flavours
    flavours_cmd = shutil.which("flavours") or shutil.which(os.path.expanduser("~/.cargo/bin/flavours"))
    if not flavours_cmd:
        return None
    
    try:
        # Get current theme name
        result = subprocess.run([flavours_cmd, "current"], capture_output=True, text=True, check=True)
        current_theme = result.stdout.strip()
        if not current_theme or current_theme == "none":
            return None
        
        # Try to find scheme file in dotfiles first, then home config
        dotfiles_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        scheme_paths = [
            os.path.join(dotfiles_dir, "stow", "flavours", ".config", "flavours", "schemes", current_theme, f"{current_theme}.yaml"),
            os.path.join(dotfiles_dir, "stow", "flavours", ".config", "flavours", "schemes", "default", "default.yaml"),
            os.path.expanduser(f"~/.config/flavours/schemes/{current_theme}/{current_theme}.yaml"),
        ]
        
        for scheme_path in scheme_paths:
            if os.path.exists(scheme_path):
                with open(scheme_path, 'r') as f:
                    scheme = yaml.safe_load(f)
                    # Return all base16 colors from scheme
                    return scheme
        
        return None
    except Exception:
        return None

def animate_beams(banner_file: str, frame_rate: int = 100):
    """Animate with beams effect - beams travel over canvas illuminating characters.
    Uses current flavours theme colors if available."""
    if not os.path.exists(banner_file):
        return False
    
    tte_cmd = shutil.which("tte") or shutil.which("terminaltexteffects")
    if not tte_cmd:
        return False
    
    # Get theme colors
    theme_colors = get_flavours_colors()
    
    # Disable terminal input during animation
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
            "--final-wipe-speed", "2"
        ]
        
        # Add theme colors if available - use only green (base0B) as single solid color
        if theme_colors:
            theme_color = theme_colors.get('base06')
            # Beam gradient: use same color for solid (no gradient)
            cmd.extend([
                "--beam-gradient-stops",
                theme_color,
                theme_color,
            ])
            # Final gradient: use same color for solid (no gradient)
            cmd.extend([
                "--final-gradient-stops",
                    theme_color,
            ])
        
        # Redirect stdin to /dev/null to prevent any input from reaching TTE
        with open(os.devnull, 'r') as devnull:
            result = subprocess.run(cmd, stdin=devnull, check=True)
        return result.returncode == 0
    except subprocess.CalledProcessError:
        return False
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return False
    finally:
        # Always restore terminal input
        _restore_terminal_input(old_settings)

if __name__ == "__main__":
    banner_file = sys.argv[1] if len(sys.argv) > 1 else None
    frame_rate = int(sys.argv[2]) if len(sys.argv) > 2 else 100  # 100 = default TTE frame rate
    
    if not banner_file:
        sys.exit(1)
    
    success = animate_beams(banner_file, frame_rate)
    sys.exit(0 if success else 1)

