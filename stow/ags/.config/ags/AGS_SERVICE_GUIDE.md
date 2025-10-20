# AGS Service Configuration Guide

## What Was Wrong

### Problem Summary

AGS service was freezing and consuming 100% GPU due to:

1. **Missing config path** - AGS didn't know where to find `app.ts`
2. **Terminal errors** - `cava` subprocess tried to open `/dev/tty` in systemd context
3. **Missing GTK flag** - Service didn't specify `--gtk 4` flag
4. **No working directory** - AGS couldn't resolve relative paths

### Symptoms

- `Error opening terminal: unknown` in logs
- Service restart loops
- High CPU/GPU usage
- Child processes (cava) failing to start

## How AGS/Astal Works

### Architecture Overview

```
systemd user service (ags.service)
    └─> /usr/bin/ags run --gtk 4 ~/.config/ags/app.ts
            └─> gjs (GJS JavaScript runtime)
                    ├─> GTK4 widgets (your bar/panels)
                    ├─> Astal libraries (via GObject introspection)
                    └─> Subprocesses (cava, etc.)
```

### Key Components

1. **AGS CLI** (`/usr/bin/ags`)
   - Entry point that launches the GJS runtime
   - Compiles TypeScript to JavaScript on-the-fly
   - Sets up GTK application context

2. **GJS Runtime**
   - GNOME JavaScript bindings for GLib/GTK
   - Executes your TypeScript code (after compilation)
   - Provides GObject introspection for native libraries

3. **Astal Libraries**
   - Native libraries accessed via GObject introspection
   - Examples: AstalHyprland, AstalBattery, AstalNetwork
   - Provide real-time system information

4. **App Lifecycle**
   ```typescript
   app.start({
     css: style,
     main() {
       // Create windows for each monitor
       app.get_monitors().map(Bar);
     },
   });
   ```

## Systemd Service Configuration

### Current Setup

```ini
[Unit]
Description=AGS (Aylur's GTK Shell)
Documentation=https://github.com/aylur/ags
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
WorkingDirectory=%h/.config/ags
ExecStart=/usr/bin/ags run --gtk 4 %h/.config/ags/app.ts
Restart=on-failure
RestartSec=3
KillMode=mixed
TimeoutStopSec=5

# Ensure proper environment for GTK/Wayland
Environment=GDK_BACKEND=wayland,x11
Environment=QT_QPA_PLATFORM=wayland;xcb
Environment=SDL_VIDEODRIVER=wayland
Environment=CLUTTER_BACKEND=wayland

# Prevent cava from trying to open terminal
Environment=TERM=dumb

[Install]
WantedBy=graphical-session.target
```

### Key Configuration Options

1. **WorkingDirectory=%h/.config/ags**
   - Sets context for relative paths
   - Required for resolving `widget/cava/config/config`

2. **ExecStart with full path**
   - `--gtk 4`: Uses GTK4 (required for AGS v2)
   - Full path to `app.ts`: Explicit entry point

3. **Environment Variables**
   - `GDK_BACKEND=wayland,x11`: GTK uses Wayland first, X11 fallback
   - `TERM=dumb`: Prevents terminal operations in subprocesses
   - Wayland variables: Ensure proper compositor integration

4. **Service Type**
   - `Type=simple`: Service is ready when process starts
   - Alternative: `Type=dbus` for D-Bus activated apps

5. **KillMode=mixed**
   - Sends SIGTERM to main process
   - Sends SIGKILL to all child processes on stop
   - Ensures clean shutdown of cava and other subprocesses

## Wakeup/Resume Handling

### Resume Hook System

AGS has a systemd resume hook that automatically restarts it after sleep/suspend:

```bash
/etc/systemd/system/ags-resume-hook.service
```

```ini
[Unit]
Description=AGS Resume Hook - Restart AGS after sleep
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl --user -M %u@ restart ags.service

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
```

### How It Works

1. **Trigger Events**
   - Activates after: `suspend.target`, `hibernate.target`, `hybrid-sleep.target`
   - Runs as oneshot service (executes once and exits)

2. **Execution**
   - `-M %u@`: Targets the user systemd instance
   - Restarts `ags.service` for the user who suspended

3. **Why It's Needed**
   - GTK/Wayland connections may break after suspend
   - GObject connections may become stale
   - Subprocesses (cava) may lose audio connections
   - Clean restart ensures fresh state

### Installation

The resume hook is installed by:

```bash
./install/config/ags.sh
```

This script:

1. Creates `/etc/systemd/system/ags-resume-hook.service`
2. Enables the service
3. Reloads systemd daemon

### Manual Control

```bash
# Check if resume hook is enabled
sudo systemctl status ags-resume-hook.service

# Test the hook manually (simulates resume)
sudo systemctl start ags-resume-hook.service

# Disable automatic restart on resume
sudo systemctl disable ags-resume-hook.service

# Re-enable
sudo systemctl enable ags-resume-hook.service
```

## Managing AGS Service

### User Service Commands

```bash
# Start AGS
systemctl --user start ags.service

# Stop AGS
systemctl --user stop ags.service

# Restart AGS
systemctl --user restart ags.service

# Check status
systemctl --user status ags.service

# View logs
journalctl --user -u ags.service -f

# Enable on login
systemctl --user enable ags.service

# Disable
systemctl --user disable ags.service

# Reload after editing service file
systemctl --user daemon-reload
systemctl --user restart ags.service
```

### Development Workflow

While developing, you may want to run AGS directly instead of via systemd:

```bash
# Stop the service
systemctl --user stop ags.service

# Run directly for development
cd ~/.config/ags
ags run --gtk 4

# Or use the dev script with hot reload
npm run dev
```

When done developing:

```bash
# Quit AGS
ags quit

# Start the service again
systemctl --user start ags.service
```

## Subprocess Management

### How Subprocesses Work

AGS uses the `subprocess()` function from `ags/process`:

```typescript
import { subprocess } from "ags/process";

subprocess(
  ["cava", "-p", "widget/cava/config/config"],
  (stdout) => {
    // Handle output
  },
  (stderr) => {
    console.error("Error:", stderr);
  }
);
```

### Subprocess Lifecycle

1. **Start**: When the service file is imported
2. **Run**: Continuously until AGS stops
3. **Stop**: Killed by systemd's `KillMode=mixed`

### Environment Variables

Subprocesses inherit environment from the systemd service:

- `TERM=dumb` prevents terminal operations
- Wayland variables for GUI subprocesses
- Working directory from `WorkingDirectory`

### Common Issues

1. **Terminal errors**: Set `TERM=dumb` in service
2. **Missing paths**: Set `WorkingDirectory`
3. **Zombie processes**: Use `KillMode=mixed`
4. **Audio issues after resume**: Resume hook restarts everything

## Troubleshooting

### High CPU Usage

**Symptoms**: AGS consuming 100% CPU/GPU
**Causes**:

- Infinite loops in polling functions
- Too frequent updates (check poll intervals)
- Terminal operations failing repeatedly

**Solution**:

```bash
# Check current resource usage
systemctl --user status ags.service

# View process tree
ps aux | grep -E "(ags|gjs|cava)"

# Check for errors
journalctl --user -u ags.service -n 50
```

### Service Failing to Start

**Symptoms**: Service status shows "failed"
**Check**:

```bash
# View detailed status
systemctl --user status ags.service -l

# Check logs
journalctl --user -u ags.service --no-pager
```

**Common issues**:

- Missing `--gtk 4` flag
- Wrong path to `app.ts`
- Missing dependencies
- Syntax errors in TypeScript

### After System Resume

**Symptoms**: AGS not visible after waking from sleep
**Check**:

```bash
# Is resume hook enabled?
sudo systemctl status ags-resume-hook.service

# Was it triggered?
journalctl -u ags-resume-hook.service -n 10

# Check AGS status
systemctl --user status ags.service
```

**Manual fix**:

```bash
systemctl --user restart ags.service
```

### Subprocess Issues

**Symptoms**: Features not working (audio visualizer, etc.)
**Check**:

```bash
# View process tree
pstree -p $(pgrep -f "ags run")

# Should show:
# ags(PID)───gjs(PID)───cava(PID)
```

**Debug**:

```bash
# Run cava manually to test
cd ~/.config/ags
TERM=dumb cava -p widget/cava/config/config

# If it works, issue is in AGS integration
# If it fails, issue is with cava setup
```

## Best Practices

1. **Always use full paths** in systemd service files
2. **Set WorkingDirectory** for relative path resolution
3. **Use --gtk 4 flag** for AGS v2
4. **Set environment variables** for all child processes
5. **Enable resume hook** for laptop/suspend usage
6. **Monitor logs** after making changes
7. **Test manually first** before enabling service
8. **Use KillMode=mixed** to clean up subprocesses

## References

- [AGS Documentation](https://github.com/aylur/ags)
- [Astal Libraries](https://github.com/aylur/astal)
- [systemd.service(5)](https://man.archlinux.org/man/systemd.service.5)
- [systemd.special(7)](https://man.archlinux.org/man/systemd.special.7)
