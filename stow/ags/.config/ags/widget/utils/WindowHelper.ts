// utils/WindowHelper.ts
import { Widget, Astal, Gdk } from "astal/gtk3"
import { Variable } from "astal"

interface WindowConfig {
  name: string
  className?: string
  content: any
  anchor?: Astal.WindowAnchor
  autoClose?: boolean
}

// Global click catcher - pre-create for speed
let globalClickCatcher: Widget.Window | null = null
const openWindows = new Set<{ close: () => void, autoClose: boolean }>()

function createGlobalClickCatcher() {
  if (globalClickCatcher) return globalClickCatcher

  globalClickCatcher = new Widget.Window({
    name: "global-click-catcher",
    anchor: Astal.WindowAnchor.TOP | Astal.WindowAnchor.BOTTOM | 
            Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT,
    visible: false,
    layer: Astal.Layer.TOP,
    keymode: Astal.Keymode.ON_DEMAND,
    exclusivity: Astal.Exclusivity.IGNORE,
    marginBottom: 24,
    child: new Widget.EventBox({
      onButtonPressEvent: () => {
        closeAllWindows()
        return true
      },
      child: new Widget.Box({
        css: "background-color: transparent;",
        expand: true,
      })
    })
  })

  globalClickCatcher.connect("key-press-event", (_, event: Gdk.EventKey) => {
    if (event.keyval === Gdk.KEY_Escape) {
      closeAllWindows()
      return true
    }
    return false
  })

  return globalClickCatcher
}

// Pre-create click catcher on first use
const getClickCatcher = () => {
  if (!globalClickCatcher) {
    createGlobalClickCatcher()
  }
  return globalClickCatcher!
}

export function closeAllWindows() {
  const autoCloseWindows = Array.from(openWindows).filter(w => w.autoClose)
  autoCloseWindows.forEach(w => w.close())
  autoCloseWindows.forEach(w => openWindows.delete(w))
  
  const hasAutoCloseWindows = Array.from(openWindows).some(w => w.autoClose)
  if (!hasAutoCloseWindows && globalClickCatcher) {
    globalClickCatcher.visible = false
  }
}

function forceCloseAllWindows() {
  openWindows.forEach(w => w.close())
  openWindows.clear()
  if (globalClickCatcher) {
    globalClickCatcher.visible = false
  }
}

export function getCurrentWindowClose(): (() => void) | null {
  if (openWindows.size > 0) {
    return Array.from(openWindows)[openWindows.size - 1].close
  }
  return null
}

export function createWindow(config: WindowConfig) {
  const isVisible = Variable(false)
  
  const close = () => {
    window.visible = false
    isVisible.set(false)
    
    const windowEntry = Array.from(openWindows).find(w => w.close === close)
    if (windowEntry) {
      openWindows.delete(windowEntry)
    }
    
    const hasAutoCloseWindows = Array.from(openWindows).some(w => w.autoClose)
    if (!hasAutoCloseWindows && globalClickCatcher) {
      globalClickCatcher.visible = false
    }
  }

  const window = new Widget.Window({
    name: config.name,
    className: config.className,
    anchor: config.anchor || (Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT),
    visible: false,
    layer: Astal.Layer.OVERLAY,
    keymode: Astal.Keymode.NONE, // Don't steal keyboard focus
    exclusivity: Astal.Exclusivity.NORMAL, // Don't interfere with other windows
    child: config.content
  })

  const toggle = () => {
    const visible = !isVisible.get()
    
    if (visible) {
      // Fast close - no delays
      forceCloseAllWindows()
      
      // Fast tracking
      const windowEntry = { close, autoClose: config.autoClose || false }
      openWindows.add(windowEntry)
      
      // Fast show - pre-created click catcher
      if (config.autoClose) {
        const clickCatcher = getClickCatcher()
        clickCatcher.visible = true
        clickCatcher.present()
      }
      
      // Show window - GTK3/Wayland has known hover state issues after overlay opens
      // This is a documented limitation - mouse needs slight movement to refresh hover
      window.visible = true
      isVisible.set(true)
    } else {
      close()
    }
  }

  return { window, isVisible, toggle, close }
}