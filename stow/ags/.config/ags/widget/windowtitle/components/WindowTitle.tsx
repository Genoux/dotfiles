import { With } from "ags";
import { client } from "../service";

export function WindowTitle({ class: cls = "" }: { class?: string }) {
  return (
    <With value={client}>
      {(c: any) => {
        const title = c?.title || "";
        const clsname = c?.class || "";
        const className = c?.className || "";
        // Get icon name with fallback
        const getAppIcon = (className: string): string => {
          if (!className) return "applications-other";

          // Try lowercase first (most common)
          const lowerClass = className.toLowerCase();

          // Common application icon mappings


          // Try the class name as-is, then lowercase
          return lowerClass || "applications-other";
        };

        return (
          <box class={`${cls}`} spacing={6} visible={!!c && (title || clsname)}>
            <image iconName={getAppIcon(clsname)} pixelSize={18} />
            <label
              label={title || clsname || "Unknown" || className}
              xalign={0.0}
              maxWidthChars={40}
              ellipsize={3}
              marginEnd={3}
            />
          </box>
        );
      }}
    </With>
  );
}
