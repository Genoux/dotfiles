import { createBinding, For } from "ags";
import Tray from "gi://AstalTray";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import { execAsync } from "ags/process";
import { Button } from "../../../lib/components";

const tray = Tray.get_default();

function TrayButton({ item }: { item: Tray.TrayItem }) {
  // Register icon theme if needed
  if (item.iconThemePath) {
    const display = Gdk.Display.get_default();
    if (display) {
      const iconTheme = Gtk.IconTheme.get_for_display(display);
      iconTheme.add_search_path(item.iconThemePath);
    }
  }

  const focusWindow = async (item: Tray.TrayItem) => {

    const appName = item.id.replace(/[_-].*$/, "").toLowerCase();
    //TODO: FIX THIS
    try {
      // Simple approach: try to focus by class name
      console.log(item);
      await execAsync(['hyprctl', 'dispatch', 'focuswindow', `class:${appName || item.tooltip_markup}`]);
      return true;
    } catch {
      return false;
    }
  };

  const handlePrimaryClick = async () => {
    console.log(`Clicking ${item.id}`);
    console.log('Full item object:', item);
    console.log('Item properties:', {
      id: item.id,
      title: item.title,
      titleLength: item.title?.length || 0,
      gicon: item.gicon,
      menuModel: item.menu_model,
      actionGroup: item.action_group,
      iconThemePath: item.iconThemePath,
      iconName: item.icon_name,
      category: item.category,
      status: item.status,
      tooltip: item.tooltip,
      tooltipMarkup: item.tooltip_markup
    });

    // Simple: just activate the tray item
    try {
      item.activate(0, 0);

      // Try to focus window after a short delay
      //setTimeout(async () => {
      await focusWindow(item);
      //}, 300);

    } catch (error) {
      console.log(`Activation failed for ${item.id}:`, error);
    }
  };

  const handleSecondaryClick = (widget: Gtk.Widget) => {
    try {
      if (item.menu_model) {
        item.about_to_show();
        const popover = new Gtk.PopoverMenu();
        popover.set_menu_model(item.menu_model);
        popover.set_parent(widget);
        popover.popup();
      } else {
        item.secondary_activate(0, 0);
      }
    } catch (error) {
      console.log(`Secondary action failed for ${item.id}:`, error);
    }
  };

  return (
    <Button
      class="tray-button"
      tooltipText={item.title || item.tooltip_markup || item.id}
      onClicked={handlePrimaryClick}
      $={(self: any) => {
        if (item.actionGroup) {
          self.insert_action_group("dbusmenu", item.actionGroup);
        }

        const rightClick = new Gtk.GestureClick();
        rightClick.set_button(3);
        rightClick.connect("released", () => handleSecondaryClick(self));
        self.add_controller(rightClick);

        const middleClick = new Gtk.GestureClick();
        middleClick.set_button(2);
        middleClick.connect("released", () => item.secondary_activate(0, 0));
        self.add_controller(middleClick);
      }}
    >
      <image gicon={item.gicon} pixelSize={12} />
    </Button>
  );
}

export function SystemTray({ class: cls }: { class?: string }) {
  const items = createBinding(tray, "items");

  return (
    <box
      class={`system-tray ${cls ?? ""}`}
      spacing={2}
      visible={items((list) => list.length > 0)}
    >
      <For each={items}>
        {(item) => <TrayButton item={item} />}
      </For>
    </box>
  );
}