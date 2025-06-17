import { App } from "astal/gtk3"
import { Variable } from "astal"
import { LauncherProvider, SearchResult, PreviewContent } from "./types"
import { AppProvider } from "./providers/AppProvider"
import { CalculatorProvider } from "./providers/CalculatorProvider"
import { GoogleProvider } from "./providers/GoogleProvider"

//TODO: This need to be refactored to be more modular and easier to maintain.

class SmartAppLauncherService {
    private static instance: SmartAppLauncherService
    private providers: LauncherProvider[] = []

    // Public reactive state
    public text = Variable("")
    public isVisible = Variable(false)
    public previewContent = Variable<PreviewContent | null>(null)

    constructor() {
        // Register providers (order matters for priority)
        this.providers = [
            new CalculatorProvider(),
            new AppProvider(),
            // Add more providers here easily:
             new GoogleProvider(),  // Uncomment to enable Google search
            // new FileProvider(),
            // new WebProvider(),
        ].sort((a, b) => b.priority - a.priority)

        // React to text changes
        this.text.subscribe((query) => {
            this.updatePreview(query)
        })

        // Track launcher visibility
        const window = App.get_window("launcher")
        if (window) {
            window.connect("notify::visible", () => {
                this.isVisible.set(window.visible)
            })
        }
    }

    static getInstance(): SmartAppLauncherService {
        if (!SmartAppLauncherService.instance) {
            SmartAppLauncherService.instance = new SmartAppLauncherService()
        }
        return SmartAppLauncherService.instance
    }

    private updatePreview(query: string) {
        if (!query.trim()) {
            this.previewContent.set(null)
            return
        }

        // Find the highest priority provider that can handle this query
        for (const provider of this.providers) {
            if (provider.canHandle(query) && provider.getPreview) {
                const preview = provider.getPreview(query)
                if (preview) {
                    this.previewContent.set(preview)
                    return
                }
            }
        }
        
        this.previewContent.set(null)
    }

    activateSelected() {
        const query = this.text.get().trim()
        console.log(`🚀 ModularService.activateSelected() called with: "${query}"`)
        
        if (!query) {
            console.log(`❌ Empty query, returning`)
            return
        }
        
        // Find the first provider that can handle this query and get its best result
        for (const provider of this.providers) {
            console.log(`🔍 Checking provider: ${provider.name} (priority: ${provider.priority})`)
            
            if (provider.canHandle(query)) {
                console.log(`✅ Provider ${provider.name} can handle "${query}"`)
                
                const results = provider.search(query)
                const bestResult = Array.isArray(results) 
                    ? results[0] 
                    : results instanceof Promise 
                        ? null 
                        : results[0]
                
                console.log(`🎯 Best result from ${provider.name}:`, bestResult?.title || 'none')
                
                if (bestResult) {
                    console.log(`🚀 Executing action for: ${bestResult.title}`)
                    bestResult.action()
                    this.hide()
                    return
                }
            } else {
                console.log(`❌ Provider ${provider.name} cannot handle "${query}"`)
            }
        }
        
        console.log(`❌ No provider could handle "${query}"`)
    }

    // Window management
    toggle() {
        const window = App.get_window("launcher")
        if (window) {
            if (window.visible) {
                this.hide()
            } else {
                this.show()
            }
        }
    }

    show() {
        const window = App.get_window("launcher")
        if (window) {
            window.visible = true
            this.clearText()
        }
    }

    hide() {
        const window = App.get_window("launcher")
        if (window) {
            window.visible = false
            this.clearText()
        }
    }

    // Text management
    setText(newText: string) {
        this.text.set(newText)
    }

    clearText() {
        this.text.set("")
        this.previewContent.set(null)
    }

    // Getters for compatibility
    getText() {
        return this.text.get()
    }
}

export default SmartAppLauncherService.getInstance() 