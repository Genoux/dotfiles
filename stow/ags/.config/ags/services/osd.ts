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

export function createOSDService(hideDelay: number = 2000) {
  const [isVisible, setIsVisible] = createState(false);
  let hideTimeoutId = 0;
  let isInitializing = true;
  let isDestroyed = false;

  function hide() {
    if (isDestroyed) return;
    hideTimeoutId++;
    setIsVisible(false);
  }

  globalOSDManager.register(hide);

  function show() {
    if (isDestroyed) return;

    globalOSDManager.hideAllExcept(hide);
    setIsVisible(true);

    const currentTimeoutId = ++hideTimeoutId;
    timeout(hideDelay, () => {
      if (!isDestroyed && currentTimeoutId === hideTimeoutId) {
        hide();
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
