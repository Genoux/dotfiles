import Apps from "gi://AstalApps";

const apps = new Apps.Apps();

export function getAppIcon(className: string): string {
  if (!className) return "applications-other";

  // Try to find the app by class name
  const lowerClass = className.toLowerCase();
  const query = apps.fuzzy_query(lowerClass);

  if (query.length > 0) {
    const app = query[0];
    const iconName = app.iconName;
    if (iconName) return iconName;
  }

  // Fallback to lowercase class name (may still work for simple cases)
  return lowerClass || "applications-other";
}
