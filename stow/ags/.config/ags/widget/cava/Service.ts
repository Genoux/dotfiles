import { Variable } from "astal"
import { subprocess } from "astal/process"

// CAVA data and state variables
export const cavaData = Variable<number[]>(new Array(8).fill(2))
export const isPlaying = Variable(false)

class CavaManager {
  private cavaProcess: any = null
  private isDisposed = false

  constructor() {
    this.startCava()
  }


  private normalizeValue(value: number): number {
    // Simple normalization: 0-1000 -> 2-16 (min height 2, max height 16)
    const normalized = Math.min(value / 1000, 1)
    return Math.round(2 + normalized * 14)
  }

  private startCava() {
    if (this.isDisposed) return
    
    try {
      this.cavaProcess = subprocess(
        ["cava", "-p", "/home/john/dotfiles/stow/cava/.config/cava/config"],
        (output) => {
          if (this.isDisposed) return
          if (output.trim()) {
            const values = output.trim().split(';').map(Number).filter(n => !isNaN(n))
            if (values.length >= 8) {
              const barHeights = values.slice(0, 8).map(val => this.normalizeValue(val))
              cavaData.set(barHeights)
              
              // Show visualizer if any bar is above minimum
              const hasAudio = barHeights.some(height => height > 3)
              isPlaying.set(hasAudio)
            }
          }
        },
        (error) => {
          if (this.isDisposed) return
          console.error("CAVA error:", error)
          this.restartCava()
        }
      )
    } catch (error) {
      console.error("Failed to start CAVA:", error)
    }
  }

  private restartCava() {
    if (this.isDisposed) return
    setTimeout(() => this.startCava(), 1000)
  }

  public dispose() {
    if (this.isDisposed) return
    
    this.isDisposed = true
    
    if (this.cavaProcess) {
      try {
        this.cavaProcess.kill()
        this.cavaProcess = null
      } catch (error) {
        console.error("Error terminating CAVA process:", error)
      }
    }
    
    // Reset state
    cavaData.set(new Array(8).fill(2))
    isPlaying.set(false)
  }

}

// Initialize manager and export for cleanup
export const cavaManager = new CavaManager()

// Utility function to calculate gradient opacity based on distance from center
export function calculateGradientOpacity(index: number, totalBars: number): number {
  const centerIndex = (totalBars - 1) / 2
  const distanceFromCenter = Math.abs(index - centerIndex)
  const maxDistance = Math.floor(totalBars / 2)
  
  // Calculate opacity based on distance from center
  // Center = 1.0, edges fade to 0.1
  const normalizedDistance = distanceFromCenter / maxDistance
  return 1.0 - (normalizedDistance * 0.9) // 1.0 to 0.1
}

 