import { Gtk } from "ags/gtk4";
import { Accessor } from "ags";

/**
 * A button component that automatically centers itself
 * Accepts both static values and Accessors for reactive props
 */
export function Button({
  children,
  class: cls = "",
  ...props
}: {
  children?: any;
  class?: string | Accessor<string>;
  [key: string]: any;
}) {
  return (
    <button 
      halign={Gtk.Align.CENTER} 
      valign={Gtk.Align.CENTER} 
      vexpand={false} 
      class={cls}
      {...props}
    >
      {children}
    </button>
  );
}
