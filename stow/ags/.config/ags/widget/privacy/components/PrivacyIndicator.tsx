import { Gtk } from "ags/gtk4";
import Icon from "../../../components/Icon";
import { privacy, isAnyActive, getMicApps, getWebcamApps, getScreenRecordApps, showPrivacyDetails } from "../service";

export function PrivacyIndicator() {
  return (
    <revealer
      revealChild={isAnyActive}
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      transitionDuration={200}
      valign={Gtk.Align.CENTER}
    >
      <box class="privacy-indicator" vexpand={true} valign={Gtk.Align.CENTER} halign={Gtk.Align.CENTER} spacing={2}>
        <revealer
          revealChild={privacy((s) => s.webcam)}
          transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
          transitionDuration={150}
        >
          <button
            class="privacy-btn privacy-btn--webcam"
            $={(self: any) => {
              const gesture = new Gtk.GestureClick();
              gesture.set_button(3);
              gesture.connect("released", () => showPrivacyDetails(self, getWebcamApps));
              self.add_controller(gesture);
            }}
          >
            <Icon icon="camera-video-symbolic" size={12} />
          </button>
        </revealer>

        <revealer
          revealChild={privacy((s) => s.mic)}
          transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
          transitionDuration={150}
        >
          <button
            class="privacy-btn privacy-btn--mic"
            $={(self: any) => {
              const gesture = new Gtk.GestureClick();
              gesture.set_button(3);
              gesture.connect("released", () => showPrivacyDetails(self, getMicApps));
              self.add_controller(gesture);
            }}
          >
            <Icon icon="mic-on" size={12} />
          </button>
        </revealer>

        <revealer
          revealChild={privacy((s) => s.screenrecord)}
          transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
          transitionDuration={150}
        >
          <button
            class="privacy-btn privacy-btn--screenrecord"
            $={(self: any) => {
              const gesture = new Gtk.GestureClick();
              gesture.set_button(3);
              gesture.connect("released", () => showPrivacyDetails(self, getScreenRecordApps));
              self.add_controller(gesture);
            }}
          >
            <Icon icon="video-display-symbolic" size={12} />
          </button>
        </revealer>
      </box>
    </revealer>
  );
}
