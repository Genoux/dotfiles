import GLib from "gi://GLib";
import { createState } from "ags";
import { subprocess } from "ags/process";

// Update state interface
interface UpdateState {
  available: boolean;
  count: number;
  lastCheck: number;
  error?: string;
}

// State file path
const STATE_FILE = `${GLib.get_home_dir()}/.local/state/dotfiles/updates.state`;

// Reactive state
const [updateState, setUpdateState] = createState<UpdateState>({
  available: false,
  count: 0,
  lastCheck: 0,
});

// Read and parse the state file
function readUpdateState(): UpdateState {
  try {
    const [success, contents] = GLib.file_get_contents(STATE_FILE);
    
    if (!success || !contents) {
      return { available: false, count: 0, lastCheck: 0 };
    }
    
    const text = new TextDecoder().decode(contents);
    const lines = text.split('\n');
    
    let available = false;
    let count = 0;
    let lastCheck = 0;
    let error: string | undefined;
    
    for (const line of lines) {
      const [key, value] = line.split('=').map(s => s.trim());
      
      switch (key) {
        case 'UPDATES_AVAILABLE':
          available = value === 'true';
          if (value === 'error') {
            error = 'Check failed';
          }
          break;
        case 'COMMIT_COUNT':
          count = parseInt(value, 10) || 0;
          break;
        case 'LAST_CHECK':
          lastCheck = parseInt(value, 10) || 0;
          break;
        case 'ERROR_MESSAGE':
          error = value;
          break;
      }
    }
    
    return { available, count, lastCheck, error };
  } catch (err) {
    console.error('Failed to read update state:', err);
    return { available: false, count: 0, lastCheck: 0, error: 'Read failed' };
  }
}

// Monitor state file for changes using inotifywait
function startMonitoring() {
  // Initial read
  setUpdateState(readUpdateState());
  console.log('Initial dotfiles state:', JSON.stringify(readUpdateState()));
  
  // Ensure state directory exists
  const stateDir = GLib.path_get_dirname(STATE_FILE);
  GLib.mkdir_with_parents(stateDir, 0o755);
  
  // Create state file if it doesn't exist
  if (!GLib.file_test(STATE_FILE, GLib.FileTest.EXISTS)) {
    GLib.file_set_contents(STATE_FILE, 'UPDATES_AVAILABLE=false\nCOMMIT_COUNT=0\nLAST_CHECK=0\n');
  }
  
  // Monitor file changes with inotifywait
  subprocess(
    ["bash", "-c", `
      STATE_FILE="${STATE_FILE}"
      
      # Wait for state file to exist
      while [ ! -f "\${STATE_FILE}" ]; do
        sleep 1
      done
      
      # Watch the state file for any modifications
      while true; do
        inotifywait -q -e modify,create,moved_to,close_write "\${STATE_FILE}" 2>/dev/null && echo "changed" || sleep 5
      done
    `],
    (out) => {
      // File changed - reload state
      const newState = readUpdateState();
      console.log('Dotfiles state changed:', JSON.stringify(newState));
      setUpdateState(newState);
    },
    (err) => {
      console.error('[Dotfiles] Monitor error:', err);
    }
  );
  
  console.log('Monitoring dotfiles update state file:', STATE_FILE);
}

// Start monitoring when module loads
startMonitoring();

// Export functions
export function openDotfilesMenu() {
  try {
    GLib.spawn_command_line_async('launch-dotfiles-menu');
  } catch (error) {
    console.error("Failed to launch dotfiles menu:", error);
  }
}

export function hasUpdates() {
  return updateState((state: UpdateState) => state.available);
}

export function getUpdateState() {
  return updateState;
}

