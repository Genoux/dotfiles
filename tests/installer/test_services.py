def test_retires_notification_service_before_configuring_units(sandbox):
    sandbox.stub('systemctl', '''
if [[ "$*" == "--user show -p LoadState --value swaync.service" ]]; then
    echo loaded
elif [[ "$*" == *"LoadState"* ]]; then
    echo not-found
fi
''')
    result = sandbox.run('bash "$DOTFILES_DIR/install/config/services.sh"')
    assert result.returncode == 0, result.stderr
    calls = sandbox.calls()
    assert 'systemctl --user disable --now swaync.service' in calls
    assert 'systemctl --user disable --now mako.service' not in calls
    assert 'systemctl --user disable --now dunst.service' not in calls


def test_failure_to_stop_notification_service_is_reported(sandbox):
    sandbox.stub('systemctl', '''
if [[ "$*" == *"LoadState"* ]]; then
    echo loaded
elif [[ "$*" == *"disable --now"* ]]; then
    exit 1
fi
''')
    result = sandbox.run('bash "$DOTFILES_DIR/install/config/services.sh"')
    assert result.returncode != 0
