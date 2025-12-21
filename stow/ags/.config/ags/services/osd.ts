import { createState } from "ags";
import { timeout } from "ags/time";

const globalOSDManager = {
  activeOSDs: new Set<() => void>(),

  register(hideFn: () => void) {
    this.activeOSDs.add(hideFn);
  },

  unregister(hideFn: () => void) {
    this.activeOSDs.delete(hideFn);
  },

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
  let isDestroyed = false;

  function hide() {
    if (isDestroyed) return;
    setIsVisible(false);
    hideTimeoutId++;
  }

  globalOSDManager.register(hide);

  function show() {
    if (isDestroyed) return;

    globalOSDManager.hideAllExcept(hide);
    setIsVisible(true);

    const currentTimeoutId = ++hideTimeoutId;

    timeout(hideDelay, () => {
      if (!isDestroyed && currentTimeoutId === hideTimeoutId) {
        setIsVisible(false);
      }
    });
  }

  function finishInitialization() {
    isInitializing = false;
  }

  function resetInitialization() {
    isInitializing = true;
  }

  function destroy() {
    isDestroyed = true;
    globalOSDManager.unregister(hide);
    setIsVisible(false);
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
    destroy,
  };
}
