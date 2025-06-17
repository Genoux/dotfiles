export interface SearchResult {
    id: string
    title: string
    subtitle?: string
    icon: string
    score: number
    action: () => void
}

export interface PreviewContent {
    type: 'text'
    value: string
    icon?: string
}

export interface LauncherProvider {
    name: string
    priority: number
    
    // Core methods
    canHandle(query: string): boolean
    search(query: string): Promise<SearchResult[]> | SearchResult[]
    getPreview?(query: string): PreviewContent | null
    
    // Optional lifecycle
    onActivate?(): void
    onDeactivate?(): void
}

export interface LauncherState {
    query: string
    results: SearchResult[]
    selectedIndex: number
    isVisible: boolean
    preview: string
    previewIcon: string
} 