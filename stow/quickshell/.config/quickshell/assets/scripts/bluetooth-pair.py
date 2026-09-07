#!/usr/bin/env python3
import json
import os
import signal
import sys

from gi.repository import Gio, GLib


AGENT_PATH = "/org/quickshell/PairingAgent"
AGENT_XML = """
<node><interface name="org.bluez.Agent1">
<method name="Release"/>
<method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
<method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
<method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
<method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
<method name="RequestAuthorization"><arg type="o" direction="in"/></method>
<method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="Cancel"/>
</interface></node>
"""


def pairing_error(error):
    name = Gio.DBusError.get_remote_error(error) or ""
    return {
        "org.bluez.Error.AuthenticationFailed": "Pairing rejected by device",
        "org.bluez.Error.AuthenticationRejected": "Pairing confirmation rejected",
        "org.bluez.Error.AuthenticationCanceled": "Pairing canceled",
        "org.bluez.Error.AuthenticationTimeout": "Pairing timed out",
        "org.bluez.Error.ConnectionAttemptFailed": "Could not reach device",
    }.get(name, "Could not pair device")


class PairingAgent:
    def __init__(self, device_path):
        self.device_path = device_path
        self.loop = GLib.MainLoop()
        self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.pending = None
        self.prompt_id = 0
        self.buffer = b""
        self.finished = False
        self.registered = False
        self.exit_code = 1

    def emit(self, **message):
        try:
            print(json.dumps(message), flush=True)
        except BrokenPipeError:
            self.finish("Pairing canceled")

    def call(self, path, interface, method, parameters=None):
        return self.bus.call_sync("org.bluez", path, interface, method, parameters,
                                  None, Gio.DBusCallFlags.NONE, 5000, None)

    def reject_pending(self):
        if self.pending:
            invocation, _ = self.pending
            self.pending = None
            invocation.return_dbus_error("org.bluez.Error.Canceled", "Pairing canceled")

    def finish(self, error=None):
        if self.finished:
            return
        self.finished = True
        self.reject_pending()
        if error:
            try:
                self.call(self.device_path, "org.bluez.Device1", "CancelPairing")
            except GLib.Error:
                pass
        if self.registered:
            try:
                self.call("/org/bluez", "org.bluez.AgentManager1", "UnregisterAgent",
                          GLib.Variant("(o)", (AGENT_PATH,)))
            except GLib.Error:
                pass
        self.exit_code = 1 if error else 0
        self.emit(type="error" if error else "done", message=error or "Connected")
        self.loop.quit()

    def handle_method(self, connection, sender, path, interface, method, parameters, invocation):
        args = parameters.unpack()
        if method in ("Cancel", "Release"):
            self.reject_pending()
            invocation.return_value(None)
            self.emit(type="prompt", kind="", id=self.prompt_id)
            if method == "Release":
                self.registered = False
                GLib.idle_add(lambda: self.finish("Pairing agent released"))
            return
        if not args or args[0] != self.device_path:
            invocation.return_dbus_error("org.bluez.Error.Rejected", "Unexpected device")
            return
        self.reject_pending()
        self.prompt_id += 1
        kind = {"RequestPinCode": "pin", "RequestPasskey": "passkey",
                "RequestConfirmation": "confirm", "RequestAuthorization": "authorize",
                "AuthorizeService": "authorize", "DisplayPinCode": "display",
                "DisplayPasskey": "display"}.get(method)
        if not kind:
            invocation.return_dbus_error("org.bluez.Error.NotSupported", "Unsupported request")
            return
        code = ""
        if method in ("RequestConfirmation", "DisplayPasskey"):
            code = f"{args[1]:06d}"
        elif method == "DisplayPinCode":
            code = args[1]
        if kind == "display":
            invocation.return_value(None)
        else:
            self.pending = (invocation, kind)
        self.emit(type="prompt", kind=kind, code=code, id=self.prompt_id,
                  entered=args[2] if method == "DisplayPasskey" else 0)

    def respond(self, message):
        if message.get("cancel"):
            self.finish("Pairing canceled")
            return
        if not self.pending or message.get("id") != self.prompt_id:
            return
        invocation, kind = self.pending
        if not message.get("accept"):
            self.pending = None
            invocation.return_dbus_error("org.bluez.Error.Rejected", "Pairing rejected")
            return
        value = str(message.get("value", ""))
        if kind == "pin":
            if not 1 <= len(value) <= 16:
                return
            reply = GLib.Variant("(s)", (value,))
        elif kind == "passkey":
            if not value.isascii() or not value.isdigit() or len(value) > 6:
                return
            reply = GLib.Variant("(u)", (int(value),))
        else:
            reply = None
        self.pending = None
        invocation.return_value(reply)
        self.emit(type="prompt", kind="", id=self.prompt_id)

    def read_input(self, fd, condition):
        chunk = os.read(fd, 4096)
        if not chunk:
            self.finish("Pairing canceled")
            return False
        self.buffer += chunk
        while b"\n" in self.buffer:
            line, self.buffer = self.buffer.split(b"\n", 1)
            try:
                message = json.loads(line)
                if isinstance(message, dict):
                    self.respond(message)
            except (ValueError, UnicodeError):
                pass
        if len(self.buffer) > 4096:
            self.finish("Invalid pairing response")
        return not self.finished

    def connected(self, connection, result):
        if self.finished:
            return
        try:
            connection.call_finish(result)
            self.finish()
        except GLib.Error as error:
            self.finish("Paired, but could not connect")

    def paired(self, connection, result):
        if self.finished:
            return
        try:
            connection.call_finish(result)
            self.call(self.device_path, "org.freedesktop.DBus.Properties", "Set",
                      GLib.Variant("(ssv)", ("org.bluez.Device1", "Trusted", GLib.Variant("b", True))))
            self.emit(type="prompt", kind="", id=self.prompt_id)
            self.bus.call("org.bluez", self.device_path, "org.bluez.Device1", "Connect",
                          None, None, Gio.DBusCallFlags.NONE, 15000, None, self.connected)
        except GLib.Error as error:
            self.finish(pairing_error(error))

    def run(self):
        info = Gio.DBusNodeInfo.new_for_xml(AGENT_XML).interfaces[0]
        self.bus.register_object(AGENT_PATH, info, self.handle_method, None, None)
        self.call("/org/bluez", "org.bluez.AgentManager1", "RegisterAgent",
                  GLib.Variant("(os)", (AGENT_PATH, "KeyboardDisplay")))
        self.registered = True
        GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP, self.read_input)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, lambda: self.finish("Pairing canceled"))
        GLib.timeout_add_seconds(60, lambda: self.finish("Pairing timed out"))
        self.bus.call("org.bluez", self.device_path, "org.bluez.Device1", "Pair", None,
                      None, Gio.DBusCallFlags.NONE, 60000, None, self.paired)
        self.loop.run()
        return self.exit_code


if __name__ == "__main__":
    try:
        sys.exit(PairingAgent(sys.argv[1]).run())
    except (GLib.Error, IndexError) as error:
        print(error, file=sys.stderr)
        print(json.dumps({"type": "error", "message": "Bluetooth pairing is unavailable"}), flush=True)
        sys.exit(1)
