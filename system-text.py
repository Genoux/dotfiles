#!/usr/bin/env python3
"""
Animate system.txt banner using TerminalTextEffects.
Uses TTE CLI via subprocess for reliability.
Three preconfigured effects: print, slide, beams
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

def animate_print(banner_file: str, frame_rate: int = 100):
    """Animate with print effect - fast character-by-character printing.
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
            "print",
            "--print-speed", "50",
            "--print-head-return-speed", "2.0"
        ]
        
        # Add theme colors if available
        if theme_colors:
            cmd.extend([
                "--final-gradient-stops",
                theme_colors['base0D'],  # Blue
                theme_colors['base0C'],  # Cyan
                theme_colors['base0B'],  # Green
                theme_colors['base07'],  # Light text
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

def animate_slide(banner_file: str, frame_rate: int = 100):
    """Animate with slide effect - characters slide in from outside.
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
            "slide",
            "--movement-speed", "1.5",
            "--grouping", "row",
            "--gap", "1"
        ]
        
        # Add theme colors if available
        if theme_colors:
            cmd.extend([
                "--final-gradient-stops",
                theme_colors['base0D'],  # Blue
                theme_colors['base0E'],  # Purple/Keyword
                theme_colors['base0C'],  # Cyan
                theme_colors['base07'],  # Light text
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

def get_flavours_colors():
    """Get current flavours theme colors from scheme file."""
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
                    # Extract colors - use blue color scheme
                    colors = {
                        'base0D': scheme.get('base0D', '41a6b5'),  # Blue (color12)
                        'base0C': scheme.get('base0C', '1abc9c'),  # Cyan (color14)
                        'base0B': scheme.get('base0B', '9ece6a'),  # Green
                        'base07': scheme.get('base07', 'fafafa'),  # Primary text (for other effects)
                    }
                    return colors
        
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
        
        # Add theme colors if available
        if theme_colors:
            # Use subtle blue gradient (matching gum's blue scheme)
            # Beam gradient: blue → cyan
            cmd.extend([
                "--beam-gradient-stops",
                theme_colors['base0D'],  # Blue
                theme_colors['base0C'],  # Cyan
            ])
            # Final gradient: subtle blue transition
            cmd.extend([
                "--final-gradient-stops",
                theme_colors['base0D'],  # Blue
                theme_colors['base0C'],  # Cyan
                theme_colors['base0B'],  # Green
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
    effect = sys.argv[2] if len(sys.argv) > 2 else "print"
    frame_rate = int(sys.argv[3]) if len(sys.argv) > 3 else 100  # 100 = default TTE frame rate
    
    if not banner_file:
        sys.exit(1)
    
    success = False
    if effect == "print":
        success = animate_print(banner_file, frame_rate)
    elif effect == "slide":
        success = animate_slide(banner_file, frame_rate)
    elif effect == "beams":
        success = animate_beams(banner_file, frame_rate)
    else:
        print(f"Unknown effect: {effect}. Use: print, slide, or beams", file=sys.stderr)
        sys.exit(1)
    
    sys.exit(0 if success else 1)

