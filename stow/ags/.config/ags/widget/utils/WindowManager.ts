import { App, Astal, Widget, Gdk } from "astal/gtk3"
import { Variable } from "astal"

// Simple, clean interfaces
interface WindowConfig {
  name: string
  type: 'popup' | 'launcher' | 'persistent'
  layer?: Astal.Layer
  anchor?: Astal.WindowAnchor
  content?: any
  className?: string
  exclusive?: boolean  // Only one exclusive window at a time
  autoClose?: boolean  // Close on ESC, outside click, workspace change
}

interface ManagedWindow {
  name: string
  config: WindowConfig
  window: Widget.Window
  isVisible: Variable<boolean>
  show: () => void
  hide: () => void
  toggle: () => void
  clickCatcher?: Widget.Window | null
}

class UnifiedWindowManager {
  private static instance: UnifiedWindowManager
  private windows = new Map<string, ManagedWindow>()
  private activeExclusiveWindow: string | null = null
  private hypr: any = null

  constructor() {
    this.initializeHyprland()
    this.setupGlobalHandlers()
  }

  static getInstance(): UnifiedWindowManager {
    if (!UnifiedWindowManager.instance) {
      UnifiedWindowManager.instance = new UnifiedWindowManager()
    }
    return UnifiedWindowManager.instance
  }

  /**
   * Create and register a window - handles everything
   */
  createWindow(config: WindowConfig): ManagedWindow {
    const isVisible = Variable(false)
    
    // Create click-outside-to-close overlay if needed
    let clickCatcher: Widget.Window | null = null
    if (config.autoClose) {
      clickCatcher = this.createClickCatcher(config.name)
    }
    
    // Create the window with consistent defaults
    const window = new Widget.Window({
      name: config.name,
      className: config.className || `window-${config.name}`,
      layer: config.layer || (config.type === 'persistent' ? Astal.Layer.BOTTOM : Astal.Layer.OVERLAY),
      anchor: config.anchor || this.getDefaultAnchor(config.type),
      visible: false,
      keymode: config.type === 'launcher' ? Astal.Keymode.ON_DEMAND : Astal.Keymode.NONE,
      exclusivity: Astal.Exclusivity.NORMAL,
      child: config.content || new Widget.Box()
    })

    // Apply cursor management
    this.applyCursorManagement(window)

    // Set up key handling
    window.connect("key-press-event", (_, event: Gdk.Event) => {
      const keyval = event.get_keyval()[1]
      if (keyval === Gdk.KEY_Escape && config.autoClose) {
        this.hide(config.name)
        return true
      }
      return false
    })

    // Create managed window interface
    const managedWindow: ManagedWindow = {
      name: config.name,
      config,
      window,
      isVisible,
      show: () => this.show(config.name),
      hide: () => this.hide(config.name),
      toggle: () => this.toggle(config.name),
      clickCatcher
    }

    // Register the window
    this.windows.set(config.name, managedWindow)
    
    console.log(`📋 Created window: ${config.name} (${config.type})`)
    return managedWindow
  }

  /**
   * Show window with all rules applied
   */
  show(windowName: string): boolean {
    const managedWindow = this.windows.get(windowName)
    if (!managedWindow) {
      console.warn(`⚠️ Window not found: ${windowName}`)
      return false
    }

    const { config, window, isVisible } = managedWindow

    // RULE: Launcher closes ALL windows
    if (config.type === 'launcher') {
      this.hideAll()
    }
    // RULE: Exclusive windows close other exclusive windows
    else if (config.exclusive && this.activeExclusiveWindow && this.activeExclusiveWindow !== windowName) {
      this.hide(this.activeExclusiveWindow)
    }

    // Show click catcher first (if it exists)
    if (managedWindow.clickCatcher) {
      managedWindow.clickCatcher.visible = true
    }

    // Show the window
    window.visible = true
    isVisible.set(true)

    // Track exclusive windows
    if (config.exclusive) {
      this.activeExclusiveWindow = windowName
    }

    console.log(`✅ Showed window: ${windowName}`)
    return true
  }

  /**
   * Hide window with cleanup - supports "*" to hide all
   */
  hide(windowName: string): boolean {
    // Special case: hide all windows
    if (windowName === "*" || windowName === "any" || windowName === "all") {
      this.hideAll()
      return true
    }

    const managedWindow = this.windows.get(windowName)
    if (!managedWindow || !managedWindow.window.visible) {
      return false
    }

    managedWindow.window.visible = false
    managedWindow.isVisible.set(false)

    // Hide click catcher too
    if (managedWindow.clickCatcher) {
      managedWindow.clickCatcher.visible = false
    }

    // Clear active exclusive window
    if (this.activeExclusiveWindow === windowName) {
      this.activeExclusiveWindow = null
    }

    console.log(`❌ Hid window: ${windowName}`)
    return true
  }

  /**
   * Toggle window
   */
  toggle(windowName: string): boolean {
    const managedWindow = this.windows.get(windowName)
    if (!managedWindow) return false

    if (managedWindow.window.visible) {
      return this.hide(windowName)
    } else {
      return this.show(windowName)
    }
  }

  /**
   * Hide all auto-close windows
   */
  hideAll(): void {
    const hiddenWindows: string[] = []
    
    this.windows.forEach((managedWindow, name) => {
      if (managedWindow.config.autoClose && managedWindow.window.visible) {
        this.hide(name)
        hiddenWindows.push(name)
      }
    })

    if (hiddenWindows.length > 0) {
      console.log(`🧹 Hid all windows: ${hiddenWindows.join(', ')}`)
    }
  }



  /**
   * Get window reference for external use
   */
  getWindow(windowName: string): ManagedWindow | undefined {
    return this.windows.get(windowName)
  }

  /**
   * Check if window is visible
   */
  isVisible(windowName: string): boolean {
    const managedWindow = this.windows.get(windowName)
    return managedWindow ? managedWindow.window.visible : false
  }

  /**
   * Get all registered windows
   */
  getAllWindows(): string[] {
    return Array.from(this.windows.keys())
  }

  /**
   * Get currently active exclusive window
   */
  getActiveWindow(): string | null {
    return this.activeExclusiveWindow
  }

  // Private helper methods
  private getDefaultAnchor(type: string): Astal.WindowAnchor {
    switch (type) {
      case 'launcher':
        return Astal.WindowAnchor.TOP | Astal.WindowAnchor.BOTTOM | 
               Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT
      case 'popup':
        return Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT
      case 'persistent':
        return Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT
      default:
        return Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT
    }
  }

  private applyCursorManagement(window: Widget.Window): void {
    // Recursive function to apply cursor to all buttons
    const applyToAllButtons = (widget: any) => {
      if (!widget) return

      // Check if it's a button
      if (widget.constructor.name.includes('Button') || 
          widget.get_style_context?.()?.has_class?.('button')) {
        
        widget.connect('enter-notify-event', () => {
          const display = widget.get_display()
          const cursor = Gdk.Cursor.new_from_name(display, 'pointer')
          widget.get_window()?.set_cursor(cursor)
        })
        
        widget.connect('leave-notify-event', () => {
          widget.get_window()?.set_cursor(null)
        })
      }

      // Recursively apply to children
      if (widget.get_children) {
        widget.get_children().forEach(applyToAllButtons)
      }
    }

    if (window.child) {
      applyToAllButtons(window.child)
    }
  }

  private async initializeHyprland(): Promise<void> {
    try {
      const AstalHyprland = await import("gi://AstalHyprland").catch(() => null)
      if (AstalHyprland) {
        this.hypr = AstalHyprland.default.get_default()
        
        // Close all auto-close windows on workspace change
        this.hypr.connect("notify::focused-workspace", () => {
          console.log("🔄 Workspace changed - hiding auto-close windows")
          this.hideAll()
        })
        
        console.log("🚀 UnifiedWindowManager: Hyprland integration active")
      }
    } catch (error) {
      console.warn("⚠️ UnifiedWindowManager: Hyprland not available:", error)
    }
  }

  private setupGlobalHandlers(): void {
    // Global ESC key handler will be handled by individual windows
    // Global click outside handler will be implemented via overlay windows
    console.log("🔧 Global handlers initialized")
  }

  private createClickCatcher(windowName: string): Widget.Window {
    // Create FULLSCREEN invisible overlay - includes AGS bar and everything
    const clickCatcher = new Widget.Window({
      name: `${windowName}-click-catcher`,
      layer: Astal.Layer.TOP,
      anchor: Astal.WindowAnchor.TOP | Astal.WindowAnchor.BOTTOM | 
              Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT,
      visible: false,
      keymode: Astal.Keymode.NONE,
      exclusivity: Astal.Exclusivity.IGNORE,
      // NO margins - truly fullscreen to catch clicks on AGS bar too
      child: new Widget.EventBox({
        onButtonPressEvent: () => {
          // Hide the window when clicking ANYWHERE (including AGS bar)
          this.hide(windowName)
          return true
        },
        child: new Widget.Box({
          css: "background-color: transparent;",
          expand: true
        })
      })
    })

    return clickCatcher
  }

  /**
   * Debug helper
   */
  debug(): void {
    console.log("🔍 UnifiedWindowManager State:")
    console.log(`  Active exclusive window: ${this.activeExclusiveWindow}`)
    console.log(`  Registered windows: ${this.getAllWindows().join(', ')}`)
    this.windows.forEach((managedWindow, name) => {
      console.log(`    ${name}: ${managedWindow.window.visible ? 'visible' : 'hidden'} (${managedWindow.config.type})`)
    })
  }
}

export const windowManager = UnifiedWindowManager.getInstance()
export type { WindowConfig, ManagedWindow } 