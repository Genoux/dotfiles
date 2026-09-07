import importlib.util
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
QS = ROOT / "stow/quickshell/.config/quickshell"


def qml_function(path, name):
    source = (QS / path).read_text()
    return re.search(r"    function " + name + r"\([^\n]*\) \{.*?^    }", source, re.M | re.S)[0]


class JavaScriptRegressions(unittest.TestCase):
    def run_js(self, source):
        result = subprocess.run(["node", "-e", source], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_notification_timeouts_and_actions(self):
        self.run_js('''
const assert = require('node:assert/strict');
const StyleNotification = {timeout: 5000};
const NotificationUrgency = {Critical: 2};
const DesktopEntries = {applications: {values: []}};
let notification;
''' + qml_function('notifications/NotificationCard.qml', 'expiryMs')
            + qml_function('notifications/NotificationCard.qml', 'activate') + '''
for (const [requested, expected] of [[0,0],[-1,5000],[50,50],[1500,1500]]) {
    notification = {expireTimeout: requested};
    assert.equal(expiryMs(), expected);
}
notification = {expireTimeout: 1000, urgency: 2};
assert.equal(expiryMs(), 0);
let invoked = '';
notification = {actions: [{identifier:'delete', invoke:()=>invoked='delete'}]};
activate(); assert.equal(invoked, '');
notification.actions.push({identifier:'default', invoke:()=>invoked='default'});
activate(); assert.equal(invoked, 'default');
''')

    def test_system_info_preserves_reported_units(self):
        source = (QS / 'services/SystemInfo.qml').read_text()
        parser = re.search(r"            onStreamFinished: \{(.*?)^            }", source, re.M | re.S)[1]
        self.run_js("""
const assert = require('node:assert/strict');
const root = {separator: '=|='};
function parse(text) {
""" + parser.replace('this.text', 'text') + """
}
for (const usage of ['512 GiB / 1.82 TiB', '512 MiB / 8 GiB', '9.5 GiB / 31.1 GiB']) {
    parse(`user@host\\nMemory=|=${usage}\\nStorage=|=${usage}`);
    assert.equal(root.hardware.find(row => row.label === 'Memory').value, usage);
    assert.equal(root.hardware.find(row => row.label === 'Storage').value, usage);
}
""")

    def test_launcher_reopen_keeps_query(self):
        self.run_js('''
const assert = require('node:assert/strict');
let visible = true, query = 'firefox';
''' + qml_function('services/Launcher.qml', 'finalizeClose') + '''
finalizeClose(); assert.equal(query, 'firefox');
visible = false; finalizeClose(); assert.equal(query, '');
''')

    def test_media_requires_title_and_artist(self):
        self.run_js('''
const assert = require('node:assert/strict');
''' + qml_function('services/MediaPlayers.qml', 'hasTrackMetadata') + '''
for (const candidate of [null, {}, {trackTitle:'Song'}, {trackTitle:'Unknown',trackArtist:'Artist'},
    {trackTitle:'Song',trackArtist:'Unknown Artist'}, {trackTitle:'Song',trackArtist:'  '}])
    assert.equal(hasTrackMetadata(candidate), false);
assert.equal(hasTrackMetadata({trackTitle:'Song',trackArtist:'Artist'}), true);
''')


class PrivacyRegressions(unittest.TestCase):
    def microphone_names(self, outputs, sources):
        source = (QS / 'assets/scripts/privacy-monitor.sh').read_text().split('if [ "$1" = "--self-check" ]')[0]
        result = subprocess.run(['bash', '-c', source + '\nmic_sources_from_outputs "$1" "$2"',
                                 'test', json.dumps(outputs), json.dumps(sources)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def test_bluetooth_and_default_microphones(self):
        for name in ['bluez_input.AA_BB.0', 'alsa_input.default']:
            self.assertEqual(self.microphone_names(
                [{'source': 5, 'corked': False, 'properties': {'application.name': 'Call'}}],
                [{'index': 5, 'name': name, 'monitor_source': ''}]), 'Call')

    def test_corked_and_monitor_streams_are_excluded(self):
        self.assertEqual(self.microphone_names(
            [{'source': 5, 'corked': True}, {'source': 6, 'corked': False}],
            [{'index': 5, 'name': 'bluez_input.headset'},
             {'index': 6, 'name': 'output.monitor', 'monitor_source': 'output'}]), '')

    def test_unnamed_microphone_still_counts(self):
        self.assertEqual(self.microphone_names([{'source': 5}], [{'index': 5}]), 'Microphone')


class RecordingRegressions(unittest.TestCase):
    def test_stop_never_starts_a_new_recording(self):
        source = (ROOT / 'stow/scripts/.local/bin/system-screenrecord').read_text()
        dispatch = source[source.rindex('if screenrecording_active; then'):]
        for active in [0, 1]:
            result = subprocess.run(['bash', '-c', """
SCOPE=stop
STATE_FILE=/nonexistent/quickshell-test-state
screenrecording_active() { return "$1"; }
stop_screenrecording() { echo stopped; }
slurp() { echo 'unexpected selector' >&2; exit 91; }
start_screenrecording() { echo 'unexpected recorder' >&2; exit 92; }
""".replace('return "$1"', f'return {active}') + dispatch], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), 'stopped' if active == 0 else '')

    def test_idle_obs_does_not_count_as_local_recording(self):
        source = (QS / 'assets/scripts/privacy-monitor.sh').read_text().split('if [ "$1" = "--self-check" ]')[0]
        result = subprocess.run(['bash', '-c', source + """
pgrep() { printf '100 obs\\n101 kooha\\n102 gpu-screen-recorder\\n' | awk -v pattern="$3" '$2 ~ ("^(" pattern ")$")'; }
running_recorders
"""], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), '')


class Invocation:
    def __init__(self):
        self.reply = None
        self.error = None

    def return_value(self, value):
        self.reply = value.unpack() if value else ()

    def return_dbus_error(self, name, message):
        self.error = name


class PairingRegressions(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('pairing', QS / 'assets/scripts/bluetooth-pair.py')
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def setUp(self):
        self.agent = self.module.PairingAgent.__new__(self.module.PairingAgent)
        self.agent.device_path = '/org/bluez/hci0/dev_AA'
        self.agent.pending = None
        self.agent.prompt_id = 0
        self.messages = []
        self.agent.emit = lambda **message: self.messages.append(message)

    def request(self, method, signature, args):
        invocation = Invocation()
        self.agent.handle_method(None, None, None, None, method,
                                 self.module.GLib.Variant(signature, args), invocation)
        return invocation

    def test_confirmation_and_stale_response(self):
        invocation = self.request('RequestConfirmation', '(ou)', (self.agent.device_path, 42))
        self.assertEqual(self.messages[-1]['code'], '000042')
        self.agent.respond({'id': 0, 'accept': True})
        self.assertIsNone(invocation.reply)
        self.agent.respond({'id': 1, 'accept': True})
        self.assertEqual(invocation.reply, ())

    def test_pin_and_passkey(self):
        for method, value, expected in [('RequestPinCode', '0012', ('0012',)),
                                        ('RequestPasskey', '000042', (42,))]:
            invocation = self.request(method, '(o)', (self.agent.device_path,))
            self.agent.respond({'id': self.agent.prompt_id, 'accept': True, 'value': value})
            self.assertEqual(invocation.reply, expected)

    def test_invalid_passkey_is_not_sent(self):
        invocation = self.request('RequestPasskey', '(o)', (self.agent.device_path,))
        for value in ['abc', '1234567', '-1', '１２']:
            self.agent.respond({'id': 1, 'accept': True, 'value': value})
            self.assertIsNone(invocation.reply)

    def test_display_passkey_and_reject_other_device(self):
        invocation = self.request('DisplayPasskey', '(ouq)', (self.agent.device_path, 42, 2))
        self.assertEqual(invocation.reply, ())
        self.assertEqual(self.messages[-1]['entered'], 2)
        invocation = self.request('RequestPinCode', '(o)', ('/other/device',))
        self.assertEqual(invocation.error, 'org.bluez.Error.Rejected')

    def test_cancel_releases_pending_request(self):
        invocation = self.request('RequestPinCode', '(o)', (self.agent.device_path,))
        self.request('Cancel', '()', ())
        self.assertEqual(invocation.error, 'org.bluez.Error.Canceled')
        self.assertIsNone(self.agent.pending)


if __name__ == '__main__':
    unittest.main()
