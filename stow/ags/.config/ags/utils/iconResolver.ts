// Smart icon resolution utility
// Shared between WindowTitle, Notifications, and other components

// Cache for resolved icons to avoid repeated lookups
const iconCache = new Map<string, string>();

/**
 * Smart icon name resolution that handles various app naming patterns
 * @param appClass The application class name, app name, or identifier
 * @returns Best guess icon name that should exist in most icon themes
 */
export function resolveAppIcon(appClass: string): string {
  if (!appClass || appClass.trim() === '') {
    return "application-x-executable";
  }

  // Check cache first
  if (iconCache.has(appClass)) {
    return iconCache.get(appClass)!;
  }
  
  const fallback = "application-x-executable";
  
  // Smart icon name candidates generation
  const candidates: string[] = [];
  const lower = appClass.toLowerCase().trim();
  
  // 1. Try original class
  candidates.push(appClass);
  
  // 2. Try lowercase
  candidates.push(lower);
  
  // 3. Remove common suffixes
  const cleaned = lower.replace(/(-bin|-app|-desktop|-electron)$/, '');
  if (cleaned !== lower) {
    candidates.push(cleaned);
  }
  
  // 4. Handle electron apps by extracting app name
  if (lower.includes('electron') || lower.includes('app')) {
    const parts = appClass.split(/[-_\s]/);
    for (const part of parts) {
      const partLower = part.toLowerCase();
      if (part.length > 2 && !['electron', 'app', 'bin', 'desktop'].includes(partLower)) {
        candidates.push(partLower);
      }
    }
  }
  
  // 5. Handle reverse DNS notation (org.app.Name -> app)
  if (appClass.includes('.')) {
    const parts = appClass.split('.');
    if (parts.length >= 2) {
      candidates.push(parts[parts.length - 1].toLowerCase());
      if (parts.length >= 3) {
        candidates.push(parts[1].toLowerCase());
      }
    }
  }
  
  // 6. Common transformations
  candidates.push(
    lower.replace(/\s+/g, '-'),
    lower.replace(/\s+/g, '_'),
    lower.replace(/_/g, '-'),
    lower.replace(/-/g, '_')
  );
  
  // 7. Clean up names - remove invalid characters
  const cleanedName = lower
    .replace(/[^a-z0-9\-_.]/g, '-')  // replace invalid chars with dashes
    .replace(/^-+|-+$/g, '')         // remove leading/trailing dashes
    .replace(/-+/g, '-');            // collapse multiple dashes
  
  if (cleanedName && cleanedName !== lower) {
    candidates.push(cleanedName);
  }
  
  // Return first valid candidate
  for (const candidate of candidates) {
    if (candidate && candidate.length > 0) {
      iconCache.set(appClass, candidate);
      return candidate;
    }
  }
  
  // Final fallback
  iconCache.set(appClass, fallback);
  return fallback;
}

/**
 * Clear the icon resolution cache (useful for testing or theme changes)
 */
export function clearIconCache(): void {
  iconCache.clear();
}