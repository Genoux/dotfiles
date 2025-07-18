import { LauncherProvider, SearchResult, PreviewContent } from "../types"
import { GLib } from "astal"


//TODO: This is a placeholder for the Google search provider.

export class GoogleProvider implements LauncherProvider {
    name = "google"
    priority = 80 // Lower than calculator and apps, but still decent

    canHandle(query: string): boolean {
        // Handle queries that start with 'g ', 'google ', or are longer than 3 words
        const trimmed = query.trim()
        const canHandle = (
            trimmed.startsWith("g ") ||
            trimmed.startsWith("google ") ||
            trimmed.split(" ").length > 3 // Long queries are probably searches
        )
        
        return canHandle
    }

    search(query: string): SearchResult[] {
        
        if (!this.canHandle(query)) {
            return []
        }

        const searchQuery = this.extractSearchQuery(query)
        
        if (!searchQuery) {
            return []
        }

        return [{
            id: `google-${searchQuery}`,
            title: `Search: ${searchQuery}`,
            subtitle: "Search Google in your browser",
            icon: "web-browser",
            score: 900, // High score for search queries
            action: () => this.searchGoogle(searchQuery)
        }]
    }

    getPreview(query: string): PreviewContent | null {
        if (!this.canHandle(query)) return null

        const searchQuery = this.extractSearchQuery(query)
        if (!searchQuery) {
            // Show typing hint when no search term yet
            const trimmed = query.trim()
            if (trimmed === "g" || trimmed === "google") {
                return {
                    type: 'text',
                    value: trimmed === "g" ? " <search term>" : " <search term>",
                    icon: "web-browser"
                }
            }
            return null
        }

        return {
            type: 'text',
            value: ` → Google: "${searchQuery}"`,
            icon: "web-browser"
        }
    }

    private extractSearchQuery(query: string): string | null {
        const trimmed = query.trim()
        
        if (trimmed.startsWith("g ")) {
            const searchTerm = trimmed.substring(2).trim()
            return searchTerm.length > 0 ? searchTerm : null
        }
        
        if (trimmed.startsWith("google ")) {
            const searchTerm = trimmed.substring(7).trim()
            return searchTerm.length > 0 ? searchTerm : null
        }
        
        // For long queries, use the whole thing
        if (trimmed.split(" ").length > 3) {
            return trimmed
        }
        
        return null
    }

    private searchGoogle(searchQuery: string) {
        
        // Use the approach that works: firefox + google.com
        const searchUrl = `google.com/search?q=${searchQuery.replace(/ /g, '+')}`
        const command = `firefox "${searchUrl}"`
        
        
        try {
            const result = GLib.spawn_command_line_async(command)
        } catch (error) {
            console.error(`❌ Error with firefox: ${error}`)
            
            // Fallback: try with full https URL
            try {
                const fullUrl = `https://www.google.com/search?q=${searchQuery.replace(/ /g, '+')}`
                const fallbackCommand = `xdg-open "${fullUrl}"`
                GLib.spawn_command_line_async(fallbackCommand)
            } catch (fallbackError) {
                console.error(`❌ Fallback failed: ${fallbackError}`)
            }
        }
    }
} 