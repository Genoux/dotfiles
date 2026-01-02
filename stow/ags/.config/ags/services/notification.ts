import GLib from "gi://GLib";

export interface NotificationOptions {
  title: string;
  body?: string;
  timeout?: number; // milliseconds
  urgency?: "low" | "normal" | "critical";
  icon?: string;
}

/**
 * Send a system notification using notify-send
 */
export function notify(options: NotificationOptions): void {
  try {
    const { title, body, timeout = 3000, urgency = "normal", icon } = options;

    let command = "notify-send";

    // Add urgency
    command += ` --urgency=${urgency}`;

    // Add timeout (convert ms to seconds for notify-send)
    const timeoutSeconds = Math.round(timeout / 1000);
    command += ` -t ${timeoutSeconds}`;

    // Add icon if provided
    if (icon) {
      command += ` --icon=${icon}`;
    }

    // Add title and body
    command += ` "${title}"`;
    if (body) {
      command += ` "${body}"`;
    }

    GLib.spawn_command_line_async(command);
  } catch (error) {
    console.error("[Notification] Failed to send notification:", error);
  }
}

/**
 * Convenience function for simple notifications
 */
export function notifySimple(title: string, body?: string, timeout?: number): void {
  notify({ title, body, timeout });
}

/**
 * Convenience function for error notifications
 */
export function notifyError(title: string, body?: string): void {
  notify({ title, body, urgency: "critical", timeout: 5000 });
}

/**
 * Convenience function for success notifications
 */
export function notifySuccess(title: string, body?: string): void {
  notify({ title, body, urgency: "normal", timeout: 3000 });
}
