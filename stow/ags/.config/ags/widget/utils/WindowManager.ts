import { App } from "astal/gtk3"
import { closeAllWindows } from "./WindowHelper"

/**
 * Global Window Manager
 * Automatically manages ALL AGS popup/overlay windows:
 * - Closes any open popup when Hyprland workspace changes
 * - Ensures mutual exclusivity between popup windows
 * - Works with both App windows and Widget windows (WindowHelper)
 */
class WindowManager {
  private static instance: WindowManager
  private hypr: any = null
  private isInitialized = false

  constructor() {
    this.initHyprland()
  }

  static getInstance(): WindowManager {
    if (!WindowManager.instance) {
      WindowManager.instance = new WindowManager()
    }
    return WindowManager.instance
  }

  private async initHyprland() {
    if (this.isInitialized) return
    
    try {
      // Dynamic import to handle potential missing dependency
      const AstalHyprland = await import("gi://AstalHyprland").catch(() => null)
      if (AstalHyprland) {
        this.hypr = AstalHyprland.default.get_default()
        this.setupGlobalHyprlandDetection()
        this.isInitialized = true
        console.log("🚀 WindowManager: Global Hyprland detection enabled")
      }
    } catch (error) {
      console.warn("⚠️ WindowManager: Hyprland integration not available:", error)
    }
  }

  private setupGlobalHyprlandDetection() {
    if (!this.hypr) return

    // GLOBAL: Close ANY open AGS popup when workspace changes
    this.hypr.connect("notify::focused-workspace", () => {
      console.log("🔄 Workspace changed - closing all AGS popups")
      this.closeAllPopupWindows()
    })

    // GLOBAL: Close ANY open AGS popup when window focus changes to different workspace
    this.hypr.connect("notify::focused-client", () => {
      // Small delay to allow for normal interactions
      setTimeout(() => {
        const focusedClient = this.hypr.focusedClient
        if (focusedClient) {
          // If focus moved to a different workspace, close popups
          const currentWorkspace = this.hypr.focusedWorkspace?.id
          const clientWorkspace = focusedClient.workspace?.id
          
          if (currentWorkspace && clientWorkspace && currentWorkspace !== clientWorkspace) {
            console.log("🔄 Focus moved to different workspace - closing all AGS popups")
            this.closeAllPopupWindows()
          }
        }
      }, 100)
    })
  }

  /**
   * GLOBAL: Close ALL popup windows automatically
   * Works with both App windows and WindowHelper windows
   */
  private closeAllPopupWindows() {
    console.log("🔄 Closing all popup windows...")
    
    // Close App windows (like launcher)
    const allAppWindows = App.get_windows()
    allAppWindows.forEach(window => {
      if (this.isPopupWindow(window) && window.visible) {
        console.log(`🔄 Closing App window: ${window.name}`)
        window.visible = false
      }
    })

    // Close WindowHelper managed windows (control-panel, notification-center)
    closeAllWindows()
    console.log("🔄 Closed WindowHelper windows")
  }

  /**
   * Automatically detect if a window is a popup/overlay that should be closed
   * Based on window properties, not manual registration
   */
  private isPopupWindow(window: any): boolean {
    // Skip the bar and persistent windows
    const persistentWindows = ['bar', 'osd', 'notification-popup']
    if (persistentWindows.some(name => window.name?.includes(name))) {
      return false
    }

    // Detect popup characteristics
    const isOverlay = window.layer === 'overlay' || window.layer === 2 // LAYER.OVERLAY = 2
    const isModal = window.layer === 'top' || window.layer === 1 // LAYER.TOP = 1
    const hasAutoClose = window.name?.includes('center') || 
                        window.name?.includes('panel') || 
                        window.name?.includes('launcher')

    return isOverlay || isModal || hasAutoClose
  }

  /**
   * Show a window and automatically close others (mutual exclusivity)
   * Works with both App windows and WindowHelper windows
   */
  showExclusiveWindow(windowName: string) {
    console.log(`🔄 Showing exclusive window: ${windowName}`)
    
    // Close all other popup windows first
    this.closeAllPopupWindows()

    // Try to show App window first
    const appWindow = App.get_window(windowName)
    if (appWindow) {
      console.log(`🔄 Found App window: ${windowName}`)
      appWindow.visible = true
      return
    }

    // If not found as App window, it might be managed by WindowHelper
    // In that case, the calling service should handle showing it
    console.log(`ℹ️ Window '${windowName}' not found as App window, assuming WindowHelper managed`)
  }

  /**
   * Manual trigger to close all popups (for external use)
   */
  closeAllPopups() {
    this.closeAllPopupWindows()
  }

  /**
   * Check if any popup window is currently open
   */
  isAnyPopupOpen(): boolean {
    // Check App windows
    const allAppWindows = App.get_windows()
    const hasOpenAppPopup = allAppWindows.some(window => 
      this.isPopupWindow(window) && window.visible
    )
    
    // Note: Can't easily check WindowHelper windows without refactoring
    // This is a limitation of the current architecture
    return hasOpenAppPopup
  }

  /**
   * Get list of currently open popup windows
   */
  getOpenPopups(): string[] {
    const allAppWindows = App.get_windows()
    return allAppWindows
      .filter(window => this.isPopupWindow(window) && window.visible)
      .map(window => window.name || 'unnamed')
  }

  // Legacy compatibility - these methods are no longer needed but kept for transition
  /** @deprecated Use automatic detection instead */
  registerExclusiveWindow(windowName: string) {
    console.log(`ℹ️ WindowManager: registerExclusiveWindow('${windowName}') is deprecated - now using automatic detection`)
  }

  /** @deprecated Use closeAllPopups() instead */
  closeAllExclusiveWindows() {
    this.closeAllPopups()
  }

  /** @deprecated Use isAnyPopupOpen() instead */
  isAnyExclusiveWindowOpen(): boolean {
    return this.isAnyPopupOpen()
  }
}

export const windowManager = WindowManager.getInstance() 