import { createState } from "ags";
import { timeout } from "ags/time";

/**
 * Global OSD manager - ensures only one OSD is visible at a time
 */
const globalOSDManager = {
  activeOSDs: new Set<() => void>(),
  
  /**
   * Register an OSD instance's hide function
   */
  register(hideFn: () => void) {
    this.activeOSDs.add(hideFn);
  },
  
  /**
   * Unregister an OSD instance
   */
  unregister(hideFn: () => void) {
    this.activeOSDs.delete(hideFn);
  },
  
  /**
   * Hide all OSDs except the one being shown
   */
  hideAllExcept(currentHideFn: () => void) {
    this.activeOSDs.forEach((hideFn) => {
      if (hideFn !== currentHideFn) {
        hideFn();
      }
    });
  },
};

/**
 * Generic OSD (On-Screen Display) service
 * Provides common functionality for managing OSD visibility and auto-hide behavior
 * 
 * @param hideDelay - Time in milliseconds before auto-hiding (default: 2000)
 * @returns Object containing visibility state, show/hide functions, and initialization helpers
 */
export function createOSDService(hideDelay: number = 2000) {
  const [isVisible, setIsVisible] = createState(false);
  let hideTimeoutId = 0;
  let isInitializing = true;

  /**
   * Hide the OSD immediately
   */
  function hide() {
    setIsVisible(false);
    // Invalidate any pending hide timeout
    hideTimeoutId++;
  }

  // Register this OSD instance with the global manager
  globalOSDManager.register(hide);

  /**
   * Show the OSD and schedule auto-hide
   * Uses a timeout ID counter to invalidate previous timeouts
   * Also hides all other OSDs to ensure only one is visible at a time
   */
  function show() {
    // Hide all other OSDs before showing this one
    globalOSDManager.hideAllExcept(hide);
    
    setIsVisible(true);

    // Increment timeout ID to invalidate previous timeouts
    const currentTimeoutId = ++hideTimeoutId;

    // Set new timeout to hide OSD
    timeout(hideDelay, () => {
      // Only hide if this is still the latest timeout
      if (currentTimeoutId === hideTimeoutId) {
        setIsVisible(false);
      }
    });
  }

  /**
   * Mark initialization as complete
   */
  function finishInitialization() {
    isInitializing = false;
  }

  /**
   * Reset initialization state (useful for testing)
   */
  function resetInitialization() {
    isInitializing = true;
  }

  return {
    isVisible,
    show,
    hide,
    get initializing() {
      return isInitializing;
    },
    finishInitialization,
    resetInitialization,
  };
}

