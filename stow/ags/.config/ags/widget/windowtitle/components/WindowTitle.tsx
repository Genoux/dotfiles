import { bind } from "astal";
import { hypr, updateTrigger } from "../Service";

function getAppIcon(appClass: string): string {
  if (!appClass || appClass.trim() === '') {
    return "application-x-executable";
  }
  
  // Simple but effective transformations
  const lower = appClass.toLowerCase().trim();
  
  // Try common patterns for Slack and similar apps
  if (lower === 'slack') return 'slack';
  if (lower === 'discord') return 'discord';
  if (lower === 'firefox') return 'firefox';
  if (lower === 'code') return 'visual-studio-code';
  if (lower === 'spotify') return 'spotify';
  
  // Remove common suffixes and try lowercase
  const cleaned = lower.replace(/(-bin|-app|-desktop|-electron)$/, '');
  
  // Handle reverse DNS (org.app.Name -> app)
  if (appClass.includes('.')) {
    const parts = appClass.split('.');
    if (parts.length >= 2) {
      return parts[parts.length - 1].toLowerCase();
    }
  }
  
  return cleaned || lower || "application-x-executable";
}

export default function WindowTitle() {
  return (
    <box className="window-title">
      {bind(updateTrigger).as(() => {
        if (!hypr) {
          return (
            <box spacing={8}>
              <icon icon="desktop-symbolic" />
              <label label="Desktop" />
            </box>
          );
        }
        
        const focusedClient = hypr.focusedClient;
        
        if (!focusedClient) {
          return (
            <box spacing={8}>
              <icon icon="desktop-symbolic" />
              <label label="Desktop" />
            </box>
          );
        }
        
        const title = focusedClient.title || "Unknown";
        const appClass = focusedClient.class || "unknown";
        const displayText = title.length > 50 ? title.substring(0, 47) + "..." : title;
        const iconName = getAppIcon(appClass);
        
        return (
          <box spacing={4}>
            <icon icon={iconName} />
            <label
              label={displayText}
              ellipsize={3}
            />
          </box>
        );
      })}
    </box>
  );
}