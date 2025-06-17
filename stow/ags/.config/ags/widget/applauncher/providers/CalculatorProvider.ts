import { LauncherProvider, SearchResult, PreviewContent } from "../types"

export class CalculatorProvider implements LauncherProvider {
    name = "calculator"
    priority = 200 // Higher priority than apps for math expressions

    canHandle(query: string): boolean {
        const trimmed = query.trim()
        
        // Must contain only math characters
        if (!/^[\d\s+\-*/().,]+$/.test(trimmed) || trimmed.length === 0) {
            return false
        }
        
        // Must contain at least one operator to be a calculation
        // Don't show for plain numbers like "4" or "42"
        return /[+\-*/()]/.test(trimmed)
    }

    search(query: string): SearchResult[] {
        if (!this.canHandle(query)) return []

        try {
            const result = this.evaluateExpression(query.trim())
            if (result !== null) {
                return [{
                    id: `calc-${query}`,
                    title: `${query} = ${result}`,
                    subtitle: "Press Enter to copy result",
                    icon: "accessories-calculator",
                    score: 1000, // High score for exact math matches
                    action: () => this.copyToClipboard(result.toString())
                }]
            }
        } catch (error) {
            // Invalid expression, no results
        }

        return []
    }

    getPreview(query: string): PreviewContent | null {
        if (!this.canHandle(query)) return null

        try {
            const result = this.evaluateExpression(query.trim())
            if (result !== null) {
                return {
                    type: 'text',
                    value: ` = ${result}`,
                    icon: "accessories-calculator"
                }
            }
        } catch (error) {
            // Invalid expression
        }

        return null
    }

    private evaluateExpression(expr: string): number | null {
        try {
            // Simple safe evaluation for basic math
            // Replace common symbols
            const sanitized = expr
                .replace(/[^0-9+\-*/.() ]/g, '')
                .replace(/\s+/g, '')

            if (!sanitized) return null

            // Use Function constructor for safe evaluation (no variables accessible)
            const result = new Function(`"use strict"; return (${sanitized})`)()
            
            if (typeof result === 'number' && !isNaN(result) && isFinite(result)) {
                return Math.round(result * 1000000) / 1000000 // Round to 6 decimal places
            }
        } catch (error) {
            // Invalid expression
        }

        return null
    }

    private copyToClipboard(text: string) {
        // Basic clipboard copying (might need to implement based on your system)
        console.log(`Copying to clipboard: ${text}`)
        // You can implement actual clipboard functionality here
    }
} 