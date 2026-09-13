def _run_bluetooth_script(sandbox, conf_path):
    return sandbox.run(
        f"""
export DOTFILES_HELPERS_LOADED=true
export BLUETOOTH_MAIN_CONF="{conf_path}"
export DOTFILES_DIR="{sandbox.dotfiles_dir}"
source "$DOTFILES_DIR/install/system/bluetooth.sh"
echo "exit=$?"
"""
    )


def test_flips_an_existing_commented_line(sandbox):
    conf = sandbox.root / "main.conf"
    conf.write_text("[General]\n\n[Policy]\n#AutoEnable=false\n")
    result = _run_bluetooth_script(sandbox, conf)
    assert "exit=0" in result.stdout, result.stderr
    assert "AutoEnable=true" in conf.read_text()


def test_appends_under_existing_policy_section_when_no_line_exists(sandbox):
    conf = sandbox.root / "main.conf"
    conf.write_text("[General]\n\n[Policy]\nAlwaysPairable=false\n")
    result = _run_bluetooth_script(sandbox, conf)
    assert "exit=0" in result.stdout, result.stderr
    text = conf.read_text()
    assert "AutoEnable=true" in text
    # Landed inside [Policy], not appended blindly at end of file.
    policy_section = text.split("[Policy]", 1)[1]
    assert "AutoEnable=true" in policy_section


def test_creates_policy_section_when_entirely_absent(sandbox):
    conf = sandbox.root / "main.conf"
    conf.write_text("[General]\nFastConnectable = true\n")
    result = _run_bluetooth_script(sandbox, conf)
    assert "exit=0" in result.stdout, result.stderr
    text = conf.read_text()
    assert "[Policy]" in text
    assert "AutoEnable=true" in text


def test_second_run_is_a_noop(sandbox):
    conf = sandbox.root / "main.conf"
    conf.write_text("[General]\nFastConnectable = true\n")
    _run_bluetooth_script(sandbox, conf)
    first_pass_content = conf.read_text()
    result = _run_bluetooth_script(sandbox, conf)
    assert "exit=0" in result.stdout, result.stderr
    assert conf.read_text() == first_pass_content


def test_missing_file_is_not_an_error(sandbox):
    conf = sandbox.root / "does-not-exist.conf"
    result = _run_bluetooth_script(sandbox, conf)
    assert "exit=0" in result.stdout, result.stderr
