import { App, Astal, Gdk, Gtk } from "astal/gtk3"
import { bind } from "astal"
import modularService from "./ModularService"

export default function ModularAppLauncher() {
    let entryRef: Gtk.Entry | null = null

    const handleKeyPress = (keyval: number): boolean => {
        switch (keyval) {
            case Gdk.KEY_Escape:
                modularService.hide()
                return true
            case Gdk.KEY_Tab:
                // Accept the current autocomplete suggestion
                const preview = modularService.previewContent.get()
                if (preview?.type === 'text') {
                    const currentText = modularService.text.get()
                    modularService.setText(currentText + preview.value)
                }
                return true
            case Gdk.KEY_Return:
            case Gdk.KEY_KP_Enter:
                modularService.activateSelected()
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
            <eventbox hexpand onClick={() => modularService.hide()} />

            <box vertical hexpand={false} vexpand>
                <eventbox vexpand onClick={() => modularService.hide()} />

                <box
                    className="AppLauncher"
                    halign={Gtk.Align.CENTER}
                    valign={Gtk.Align.CENTER}>

                    <box
                        className="search-container"
                        widthRequest={420}>
                        <overlay>
                            <entry
                                widthRequest={420}
                                className="search-entry"
                                text={modularService.text()}
                                onChanged={self => modularService.setText(self.text)}
                                onActivate={() => modularService.activateSelected()}
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
                                visible={bind(modularService.text).as(text => text.length === 0)}
                                sensitive={false}
                            />

                            {/* Smart text completion overlay */}
                            <box
                                className="preview-overlay"
                                halign={Gtk.Align.FILL}
                                valign={Gtk.Align.CENTER}
                                visible={bind(modularService.previewContent).as(content => 
                                    content?.type === 'text'
                                )}>
                                
                                <box spacing={0} halign={Gtk.Align.START}>
                                    <label
                                        className="typed-text"
                                        label={modularService.text()}
                                    />
                                    <label
                                        className="preview-completion"
                                        label={bind(modularService.previewContent).as(content => 
                                            content?.type === 'text' ? content.value : ""
                                        )}
                                    />
                                </box>
                                
                                <box halign={Gtk.Align.END} hexpand={true}>
                                    <icon
                                        className="preview-icon"
                                        icon={bind(modularService.previewContent).as(content => 
                                            content?.icon || "application-x-executable"
                                        )}
                                    />
                                </box>
                            </box>
                        </overlay>
                    </box>
                </box>

                <eventbox vexpand onClick={() => modularService.hide()} />
            </box>

            <eventbox hexpand onClick={() => modularService.hide()} />
        </box>
    </window>
} 