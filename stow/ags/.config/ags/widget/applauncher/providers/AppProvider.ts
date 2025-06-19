import Apps from "gi://AstalApps"
import { GLib } from "astal"
import { LauncherProvider, SearchResult, PreviewContent } from "../types"

const USAGE_FILE = `${GLib.get_user_cache_dir()}/ags-app-usage.json`

interface AppUsage {
    [appId: string]: {
        count: number
        lastUsed: number
        name: string
    }
}

export class AppProvider implements LauncherProvider {
    name = "apps"
    priority = 100 // High priority for apps
    
    private apps = new Apps.Apps()
    private appUsage: AppUsage = {}

    constructor() {
        this.loadUsageData()
    }

    canHandle(query: string): boolean {
        return query.trim().length > 0
    }

    search(query: string): SearchResult[] {
        if (!query.trim()) return []

        const bestApps = this.findBestMatches(query, 8)
        return bestApps.map(app => ({
            id: `app-${app.executable || app.name}`,
            title: app.name,
            subtitle: app.description || undefined,
            icon: app.iconName || "application-x-executable",
            score: this.calculateMatchScore(query.toLowerCase(), app),
            action: () => this.launchApp(app)
        }))
    }

    getPreview(query: string): PreviewContent | null {
        const bestMatch = this.findBestMatch(query)
        if (!bestMatch) return null

        const queryLower = query.toLowerCase()
        const nameLower = bestMatch.name.toLowerCase()
        
        // Only show completion for prefix matches
        if (nameLower.startsWith(queryLower)) {
            return {
                type: 'text',
                value: bestMatch.name.substring(query.length),
                icon: bestMatch.iconName || "application-x-executable"
            }
        }
        
        return null
    }

    private findBestMatch(query: string): Apps.Application | null {
        const queryLower = query.toLowerCase().trim()
        if (!queryLower) return null
        
        const allApps = this.apps.get_list()
        let bestApp: Apps.Application | null = null
        let bestScore = 0
        
        for (const app of allApps) {
            const score = this.calculateMatchScore(queryLower, app)
            if (score > bestScore) {
                bestScore = score
                bestApp = app
            }
        }
        
        return bestApp
    }

    private findBestMatches(query: string, limit: number): Apps.Application[] {
        const queryLower = query.toLowerCase().trim()
        if (!queryLower) return []
        
        const allApps = this.apps.get_list()
        const scoredApps: Array<{app: Apps.Application, score: number}> = []
        
        for (const app of allApps) {
            const score = this.calculateMatchScore(queryLower, app)
            if (score > 0) {
                scoredApps.push({app, score})
            }
        }
        
        return scoredApps
            .sort((a, b) => b.score - a.score)
            .slice(0, limit)
            .map(item => item.app)
    }

    private calculateMatchScore(query: string, app: Apps.Application): number {
        const name = app.name.toLowerCase()
        const executable = (app.executable || "").toLowerCase()
        
        let score = 0
        let debugInfo = `${app.name}: `
        
        // Exact match gets highest priority
        if (name === query) return 1000
        
        // Prefix matches are highly valued
        if (name.startsWith(query)) {
            const prefixScore = 500 + Math.max(0, 50 - name.length)
            score += prefixScore
            debugInfo += `prefix(${prefixScore}) `
        }
        
        if (executable.startsWith(query)) {
            score += 400
            debugInfo += `exec(400) `
        }
        
        // Word boundary matches
        const nameWords = name.split(/[\s\-_.]/)
        for (const word of nameWords) {
            if (word.startsWith(query)) {
                score += 300
                debugInfo += `word(300) `
                break
            }
        }
        
        // Substring matches
        if (name.includes(query)) {
            const substringScore = 200 + Math.max(0, 50 - name.indexOf(query))
            score += substringScore
            debugInfo += `substring(${substringScore}) `
        }
        
        if (executable.includes(query)) {
            score += 150
            debugInfo += `execSub(150) `
        }
        
        // Fuzzy matching
        const fuzzyScore = this.getFuzzyMatchScore(query, name)
        if (fuzzyScore > 0) {
            score += fuzzyScore
            debugInfo += `fuzzy(${fuzzyScore}) `
        }
        
        // 🧠 SMART USAGE BOOST - The key feature!
        const appId = app.executable || app.name
        const usage = this.appUsage[appId]
        if (usage) {
            // Usage frequency boost (MUCH STRONGER!)
            const usageScore = Math.min(usage.count * 50, 800) // 50 points per use, up to 800!
            score += usageScore
            debugInfo += `usage(${usageScore}|${usage.count}x) `
            
            // Recency boost - apps used in last 7 days get extra points
            const daysSinceUsed = (Date.now() - usage.lastUsed) / (1000 * 60 * 60 * 24)
            if (daysSinceUsed < 7) {
                const recencyScore = Math.max(0, 200 - daysSinceUsed * 20) // Up to 200 points!
                score += recencyScore
                debugInfo += `recency(${Math.round(recencyScore)}) `
            }
            
            // Heavy usage bonus - if you've used this app A LOT
            if (usage.count > 5) { // Lower threshold
                score += 200 // Even bigger boost
                debugInfo += `heavy(200) `
            }
            
            // Super heavy usage bonus
            if (usage.count > 15) { // Lower threshold
                score += 300 // Massive boost
                debugInfo += `super(300) `
            }
        }
        
        // Debug logging for "fi" queries
        if (query === "fi" && (name.includes("fire") || name.includes("file"))) {
            console.log(`${debugInfo}= ${score}`)
        }
        
        return score
    }

    private getFuzzyMatchScore(query: string, text: string): number {
        let score = 0
        let queryIndex = 0
        let consecutiveMatches = 0
        
        for (let i = 0; i < text.length && queryIndex < query.length; i++) {
            if (text[i] === query[queryIndex]) {
                queryIndex++
                consecutiveMatches++
                score += consecutiveMatches * 2
            } else {
                consecutiveMatches = 0
            }
        }
        
        return queryIndex === query.length ? score : 0
    }

    private launchApp(app: Apps.Application) {
        app.launch()
        this.trackAppUsage(app)
    }

    public trackAppUsage(app: Apps.Application) {
        const appId = app.executable || app.name
        const now = Date.now()
        
        if (this.appUsage[appId]) {
            this.appUsage[appId].count++
            this.appUsage[appId].lastUsed = now
        } else {
            this.appUsage[appId] = {
                count: 1,
                lastUsed: now,
                name: app.name
            }
        }
        
        this.saveUsageData()
    }

    private loadUsageData() {
        try {
            if (GLib.file_test(USAGE_FILE, GLib.FileTest.EXISTS)) {
                const [success, contents] = GLib.file_get_contents(USAGE_FILE)
                if (success) {
                    this.appUsage = JSON.parse(new TextDecoder().decode(contents))
                }
            }
        } catch (error) {
            console.warn("Failed to load app usage data:", error)
            this.appUsage = {}
        }
    }

    private saveUsageData() {
        try {
            const data = JSON.stringify(this.appUsage, null, 2)
            GLib.file_set_contents(USAGE_FILE, new TextEncoder().encode(data))
        } catch (error) {
            console.warn("Failed to save app usage data:", error)
        }
    }

    // Get the last 3 used apps for display in the launcher
    getRecentApps(): Apps.Application[] {
        
        // If we have usage data, use it
        if (Object.keys(this.appUsage).length > 0) {
            const recentUsage = Object.entries(this.appUsage)
                .sort((a, b) => b[1].lastUsed - a[1].lastUsed)
                .slice(0, 3)
                .map(([appId]) => appId)

            const allApps = this.apps.get_list()
            const recentApps: Apps.Application[] = []

            for (const appId of recentUsage) {
                const app = allApps.find(app => 
                    (app.executable === appId) || (app.name === appId)
                )
                if (app) {
                    recentApps.push(app)
                }
            }

            console.log("📱 Found recent apps from usage:", recentApps.map(app => app.name))
            return recentApps
        }
        
        // Fallback: show 3 commonly used apps if no usage data
        const allApps = this.apps.get_list()
        const fallbackApps = allApps
            .filter(app => {
                const name = app.name.toLowerCase()
                return name.includes('firefox') || 
                       name.includes('chrome') || 
                       name.includes('terminal') ||
                       name.includes('kitty') ||
                       name.includes('code') ||
                       name.includes('file') ||
                       name.includes('nautilus')
            })
            .slice(0, 3)

        console.log("📱 Using fallback apps:", fallbackApps.map(app => app.name))
        return fallbackApps
    }
} 