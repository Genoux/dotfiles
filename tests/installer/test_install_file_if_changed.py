from conftest import source


def test_first_install_reports_changed_and_copies_content(sandbox):
    src = sandbox.root / "source.conf"
    src.write_text("hello\n")
    dest = sandbox.root / "dest.conf"

    result = sandbox.run(
        f"""
{source("lib/common.sh")}
install_file_if_changed "{src}" "{dest}"
echo "exit=$?"
"""
    )
    assert result.returncode == 0, result.stderr
    assert "exit=0" in result.stdout
    assert dest.read_text() == "hello\n"


def test_second_run_with_identical_content_is_a_noop(sandbox):
    src = sandbox.root / "source.conf"
    src.write_text("hello\n")
    dest = sandbox.root / "dest.conf"

    result = sandbox.run(
        f"""
{source("lib/common.sh")}
install_file_if_changed "{src}" "{dest}"
install_file_if_changed "{src}" "{dest}"
echo "exit=$?"
"""
    )
    assert result.returncode == 0, result.stderr
    assert "exit=1" in result.stdout
    assert dest.read_text() == "hello\n"


def test_changed_content_is_installed_and_reported(sandbox):
    src = sandbox.root / "source.conf"
    dest = sandbox.root / "dest.conf"
    src.write_text("v1\n")

    result = sandbox.run(
        f"""
{source("lib/common.sh")}
install_file_if_changed "{src}" "{dest}"
echo "hi" > "{src}.tmp"
"""
    )
    assert result.returncode == 0, result.stderr

    src.write_text("v2\n")
    result = sandbox.run(
        f"""
{source("lib/common.sh")}
install_file_if_changed "{src}" "{dest}"
echo "exit=$?"
"""
    )
    assert "exit=0" in result.stdout
    assert dest.read_text() == "v2\n"


def test_missing_source_is_an_error(sandbox):
    dest = sandbox.root / "dest.conf"
    result = sandbox.run(
        f"""
{source("lib/common.sh")}
install_file_if_changed "{sandbox.root}/does-not-exist" "{dest}"
echo "exit=$?"
"""
    )
    assert "exit=2" in result.stdout
    assert not dest.exists()
