import { App, Astal, Gdk, Gtk } from "astal/gtk3"
import { bind } from "astal"
import Service from "./Service"
import { windowManager } from "../utils"

export default function ModularAppLauncher() {
    let entryRef: Gtk.Entry | null = null

    const handleKeyPress = (keyval: number): boolean => {
        switch (keyval) {
            case Gdk.KEY_Escape:
                Service.hide()
                return true
            case Gdk.KEY_Tab:
                // Accept the current autocomplete suggestion
                const preview = Service.previewContent.get()
                if (preview?.type === 'text') {
                    const currentText = Service.text.get()
                    Service.setText(currentText + preview.value)
                }
                return true
            case Gdk.KEY_Return:
            case Gdk.KEY_KP_Enter:
                Service.activateSelected()
                return true
        }
        return false
    }

    return <window
        name="launcher"
        className="AppLauncherWindow"
        anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.BOTTOM |
            Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT}
        exclusivity={Astal.Exclusivity.IGNORE}
        layer={Astal.Layer.OVERLAY}
        keymode={Astal.Keymode.ON_DEMAND}
        application={App}
        visible={false}
        onShow={() => {
            setTimeout(() => {
                if (entryRef) {
                    entryRef.grab_focus()
                }
            }, 50)
        }}
        onKeyPressEvent={(self, event: Gdk.Event) => {
            const keyval = event.get_keyval()[1]
            return handleKeyPress(keyval)
        }}>

        <box hexpand vexpand>
            <eventbox hexpand onDraw={() => {
                windowManager.hide("*")
            }} onClick={() => Service.hide()} />

            <box vertical hexpand={false} vexpand>
                <eventbox vexpand onClick={() => Service.hide()} />

                <box
                    vertical
                    halign={Gtk.Align.CENTER}
                    valign={Gtk.Align.CENTER}
                    widthRequest={420}
                >

                    <box
                        className="AppLauncher"
                        vertical
                        spacing={8}
                    >

                        <box
                            className="search-container"
                        >
                            <overlay>
                                <entry
                                    className="search-entry"
                                    text={Service.text()}
                                    onChanged={self => Service.setText(self.text)}
                                    onActivate={() => Service.activateSelected()}
                                    setup={(self) => {
                                        entryRef = self
                                    }}
                                />

                                {/* Custom placeholder */}
                                <label
                                    className="custom-placeholder"
                                    label="Search apps..."
                                    halign={Gtk.Align.START}
                                    valign={Gtk.Align.CENTER}
                                    visible={bind(Service.text).as(text => text.length === 0)}
                                    sensitive={false}
                                />

                                {/* Smart text completion overlay */}
                                <box
                                    className="preview-overlay"
                                    halign={Gtk.Align.FILL}
                                    valign={Gtk.Align.CENTER}
                                    visible={bind(Service.previewContent).as(content =>
                                        content?.type === 'text'
                                    )}>

                                    <box spacing={0} halign={Gtk.Align.START}>
                                        <label
                                            className="typed-text"
                                            label={Service.text()}
                                        />
                                        <label
                                            className="preview-completion"
                                            label={bind(Service.previewContent).as(content =>
                                                content?.type === 'text' ? content.value : ""
                                            )}
                                        />
                                    </box>

                                    <box halign={Gtk.Align.END} hexpand={true}>
                                        <icon
                                            className="preview-icon"
                                            icon={bind(Service.previewContent).as(content =>
                                                content?.icon || "application-x-executable"
                                            )}
                                        />
                                    </box>
                                </box>
                            </overlay>
                        </box>
                        <box
                            className="recent-apps-container"
                            hexpand
                            spacing={8}
                        // visible={bind(Service.text).as(text => text.length === 0)}
                        >

                            {bind(Service.recentApps).as(apps =>
                                apps.map(app => (
                                    <button
                                        className="recent-app-item"
                                        hexpand
                                        onClick={() => Service.launchRecentApp(app)}>
                                        <box spacing={8} halign={Gtk.Align.START}>
                                            <icon
                                                icon={app.icon}
                                            />
                                            <label
                                                className="recent-app-name"
                                                label={app.name}
                                                halign={Gtk.Align.START}
                                            />
                                        </box>
                                    </button>
                                ))
                            )}
                        </box>

                    </box>

                </box>

                <eventbox vexpand onClick={() => Service.hide()} />
            </box>

            <eventbox hexpand onClick={() => Service.hide()} />
        </box>

    </window>
} 