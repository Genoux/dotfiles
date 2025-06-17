import { Gtk } from "astal/gtk3";
import { Variable } from "astal";

// =============================================================================
// Inline Confirmation Overlay for Control Panel
// =============================================================================

interface ConfirmationData {
  title: string;
  message: string;
  onConfirm: () => void;
  onCancel?: () => void;
}

const confirmationVisible = Variable(false);
const confirmationData = Variable<ConfirmationData | null>(null);

// Public functions
export function showConfirmation(data: ConfirmationData) {
  confirmationData.set(data);
  confirmationVisible.set(true);
}

export function hideConfirmation() {
  confirmationVisible.set(false);
  // Small delay before clearing data to allow for smooth transitions
  setTimeout(() => {
    if (!confirmationVisible.get()) {
      confirmationData.set(null);
    }
  }, 200);
}

export function ConfirmationOverlay() {
  return (
    <box
      className="inline-confirmation-overlay"
      visible={confirmationVisible()}
      valign={Gtk.Align.FILL}
      halign={Gtk.Align.FILL}
      hexpand
      vexpand
    >
      <box vertical vexpand hexpand spacing={4} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
        <box
          className="confirmation-header"
          vertical
          halign={Gtk.Align.CENTER}
        >
          <label
            className="confirmation-title"
            label={confirmationData().as(
              (data: ConfirmationData | null) => data?.title || ""
            )}
            halign={Gtk.Align.CENTER}
          />
        </box>

        <box
          className="confirmation-buttons"
          hexpand
          halign={Gtk.Align.CENTER}
          spacing={8}
        >
          <button
            className="confirmation-btn cancel-btn"
            onClicked={() => {
              const data = confirmationData.get();
              hideConfirmation();
              if (data?.onCancel) data.onCancel();
            }}
          >
            <label label="No" />
          </button>

          <button
            className="confirmation-btn confirm-btn"
            onClicked={() => {
              const data = confirmationData.get();
              hideConfirmation();
              if (data) data.onConfirm();
            }}
          >
            <label label="Yes" />
          </button>
        </box>
      </box>
    </box>
  );
}

// Export the state for external components to check
export { confirmationVisible };
