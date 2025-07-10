import Apps from "gi://AstalApps";
import { GLib } from "astal";
import { LauncherProvider, SearchResult, PreviewContent } from "../types";
import Hyprland from "gi://AstalHyprland";

const USAGE_FILE = `${GLib.get_user_cache_dir()}/ags-app-usage.json`;

interface AppUsage {
  [appId: string]: {
    count: number;
    lastUsed: number;
    name: string;
  };
}

export class AppProvider implements LauncherProvider {
  name = "apps";
  priority = 100; // High priority for apps

  private apps = new Apps.Apps();
  private appUsage: AppUsage = {};
  private hypr = Hyprland.get_default();
  private clientsCache: any[] = [];
  private clientsCacheTime = 0;
  private readonly CACHE_DURATION = 2000; // 2 seconds cache

  constructor() {
    this.loadUsageData();
  }

  canHandle(query: string): boolean {
    return query.trim().length > 0;
  }

  search(query: string): SearchResult[] {
    if (!query.trim()) return [];

    const bestApps = this.findBestMatches(query, 8);
    return bestApps.map((app) => ({
      id: `app-${app.executable || app.name}`,
      title: app.name,
      subtitle: app.description || undefined,
      icon: app.iconName || "application-x-executable",
      score: this.calculateMatchScore(query.toLowerCase(), app),
      action: () => this.launchApp(app),
    }));
  }

  getPreview(query: string): PreviewContent | null {
    const bestMatch = this.findBestMatch(query);
    if (!bestMatch) return null;

    const queryLower = query.toLowerCase();
    const nameLower = bestMatch.name.toLowerCase();

    // Only show completion for prefix matches
    if (nameLower.startsWith(queryLower)) {
      return {
        type: "text",
        value: bestMatch.name.substring(query.length),
        icon: bestMatch.iconName || "application-x-executable",
      };
    }

    return null;
  }

  private findBestMatch(query: string): Apps.Application | null {
    const queryLower = query.toLowerCase().trim();
    if (!queryLower) return null;

    const allApps = this.apps.get_list();
    let bestApp: Apps.Application | null = null;
    let bestScore = 0;

    for (const app of allApps) {
      const score = this.calculateMatchScore(queryLower, app);
      if (score > bestScore) {
        bestScore = score;
        bestApp = app;
      }
    }

    return bestApp;
  }

  private findBestMatches(query: string, limit: number): Apps.Application[] {
    const queryLower = query.toLowerCase().trim();
    if (!queryLower) return [];

    const allApps = this.apps.get_list();
    const scoredApps: Array<{ app: Apps.Application; score: number }> = [];

    for (const app of allApps) {
      const score = this.calculateMatchScore(queryLower, app);
      if (score > 0) {
        scoredApps.push({ app, score });
      }
    }

    return scoredApps
      .sort((a, b) => b.score - a.score)
      .slice(0, limit)
      .map((item) => item.app);
  }

  private calculateMatchScore(query: string, app: Apps.Application): number {
    const name = app.name.toLowerCase();
    const executable = (app.executable || "").toLowerCase();

    let score = 0;
    let hasTextMatch = false;
    let debugInfo = "";

    // Exact match gets highest priority
    if (name === query) return 1000;

    let nameMatched = false;
    let execMatched = false;

    // Prefix matches are highly valued
    if (name.startsWith(query)) {
      hasTextMatch = true;
      nameMatched = true;
      score += 100;
      debugInfo += "prefix(100) ";
    } else {
      // Only check word boundaries if not already a full name prefix match
      const nameWords = name.split(/[\s\-_.]/);
      for (const word of nameWords) {
        if (word.startsWith(query)) {
          hasTextMatch = true;
          nameMatched = true;
          score += 50;
          debugInfo += "word(50) ";
          break;
        }
      }
    }

    if (executable.startsWith(query)) {
      hasTextMatch = true;
      execMatched = true;
      score += 80;
      debugInfo += "exec(80) ";
    }

    // Substring matches - only if not already matched as prefix
    if (!nameMatched && name.includes(query)) {
      hasTextMatch = true;
      score += 30;
      debugInfo += "substring(30) ";
    }

    if (!execMatched && executable.includes(query)) {
      hasTextMatch = true;
      score += 20;
      debugInfo += "execSub(20) ";
    }

    // Fuzzy matching
    const fuzzyScore = this.getFuzzyMatchScore(query, name);
    if (fuzzyScore > 0) {
      hasTextMatch = true;
      score += Math.min(fuzzyScore, 10);
      debugInfo += `fuzzy(${Math.min(fuzzyScore, 10)}) `;
    }

    // Only apply usage boost if there's an actual text match
    if (hasTextMatch) {
      const appId = app.executable || app.name;
      const usage = this.appUsage[appId];
      if (usage) {
        const usageBoost = Math.min(usage.count * 30, 500);
        score += usageBoost;
        debugInfo += `usage(${usageBoost}|${usage.count}x) `;
      }
    }

    return score;
  }

  private getFuzzyMatchScore(query: string, text: string): number {
    let score = 0;
    let queryIndex = 0;
    let consecutiveMatches = 0;

    for (let i = 0; i < text.length && queryIndex < query.length; i++) {
      if (text[i] === query[queryIndex]) {
        queryIndex++;
        consecutiveMatches++;
        score += consecutiveMatches * 2;
      } else {
        consecutiveMatches = 0;
      }
    }

    return queryIndex === query.length ? score : 0;
  }

  public async launchApp(app: Apps.Application) {
    try {
      // macOS Spotlight behavior: focus existing or launch new
      const existingWindows = this.countAppWindows(app);
      
      if (existingWindows > 0) {
        this.focusExistingWindow(app);
      } else {
        app.launch();
      }
      
      this.trackAppUsage(app);
    } catch (error: any) {
      console.warn(`Failed to launch ${app.name}:`, error?.message);
    }
  }

  private getCachedClients(): any[] {
    const now = Date.now();
    if (now - this.clientsCacheTime > this.CACHE_DURATION || this.clientsCache.length === 0) {
      try {
        this.clientsCache = this.hypr.clients;
        this.clientsCacheTime = now;
      } catch (error) {
        console.warn("Failed to get clients:", error);
        return [];
      }
    }
    return this.clientsCache;
  }

  private countAppWindows(app: Apps.Application): number {
    try {
      const clients = this.getCachedClients();
      const classNames = this.getPossibleClassNames(app);
      let count = 0;
      
      for (const className of classNames) {
        for (const client of clients) {
          if (client.class.toLowerCase().includes(className.toLowerCase())) {
            count++;
          }
        }
      }
      
      return count;
    } catch (error) {
      console.warn("Failed to count app windows:", error);
      return 0;
    }
  }

  private focusExistingWindow(app: Apps.Application): boolean {
    try {
      const clients = this.getCachedClients();
      const classNames = this.getPossibleClassNames(app);
      
      for (const className of classNames) {
        for (const client of clients) {
          if (client.class.toLowerCase().includes(className.toLowerCase())) {
            this.hypr.dispatch("focuswindow", `class:${client.class}`);
            return true;
          }
        }
      }
    } catch (error) {
      console.warn("Failed to focus window:", error);
    }
    return false;
  }

  private getPossibleClassNames(app: Apps.Application): string[] {
    const appName = app.name.toLowerCase();
    const executable = app.executable || "";
    
    // Extract executable name without path and arguments
    const execName = executable.split(/[\s]/).shift()?.split('/').pop()?.toLowerCase() || "";
    
    const classNames: string[] = [];
    
    // Add cleaned app name
    const cleanAppName = appName.replace(/[^a-zA-Z0-9]/g, "");
    if (cleanAppName) classNames.push(cleanAppName);
    
    // Add executable name
    if (execName && execName !== cleanAppName) classNames.push(execName);
    
    // Add original app name
    if (appName !== cleanAppName) classNames.push(appName);
    
    // Add capitalized versions
    classNames.push(cleanAppName.charAt(0).toUpperCase() + cleanAppName.slice(1));
    if (execName) classNames.push(execName.charAt(0).toUpperCase() + execName.slice(1));
    
    return [...new Set(classNames)]; // Remove duplicates
  }

  public trackAppUsage(app: Apps.Application) {
    const appId = app.executable || app.name;
    const now = Date.now();

    if (this.appUsage[appId]) {
      this.appUsage[appId].count++;
      this.appUsage[appId].lastUsed = now;
    } else {
      this.appUsage[appId] = {
        count: 1,
        lastUsed: now,
        name: app.name,
      };
    }

    this.saveUsageData();
  }

  private loadUsageData() {
    try {
      if (GLib.file_test(USAGE_FILE, GLib.FileTest.EXISTS)) {
        const [success, contents] = GLib.file_get_contents(USAGE_FILE);
        if (success) {
          this.appUsage = JSON.parse(new TextDecoder().decode(contents));
        }
      }
    } catch (error) {
      console.warn("Failed to load app usage data:", error);
      this.appUsage = {};
    }
  }

  private saveUsageData() {
    try {
      const data = JSON.stringify(this.appUsage, null, 2);
      GLib.file_set_contents(USAGE_FILE, new TextEncoder().encode(data));
    } catch (error) {
      console.warn("Failed to save app usage data:", error);
    }
  }

  // Get the top 3 most frequently used apps
  getRecentApps(): Apps.Application[] {
    // If we have usage data, use it
    if (Object.keys(this.appUsage).length > 0) {
      const topUsage = Object.entries(this.appUsage)
        .sort((a, b) => b[1].count - a[1].count)
        .slice(0, 3)
        .map(([appId]) => appId);

      const allApps = this.apps.get_list();
      const topApps: Apps.Application[] = [];
      for (const appId of topUsage) {
        const app = allApps.find(
          (app) => app.executable === appId || app.name === appId
        );
        if (app) {
          topApps.push(app);
        }
      }

      return topApps;
    }

    return [];
  }
}
