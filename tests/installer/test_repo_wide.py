import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

EXCLUDED_DIR_NAMES = {".git", "node_modules", "target", "__pycache__", ".pytest_cache"}

FORBIDDEN_SYNC_REFERENCES = ("dotfiles-package-sync", "dotfiles-sync-install", "dotfiles-sync-remove")

# workspace-manager.py's `exclude()` uses packages/sync-exclude for a
# different, still-needed feature: marking a temporarily-installed package so
# the Overview widget shows it as "temporary / excluded". That is unrelated
# to the deleted pacman-hook auto-sync mechanism that used to write installed
# packages back into arch.package/aur.package, and was deliberately kept —
# see the task report.
# pacman-hooks.sh's whole job here is removing these exact paths from
# machines that ran the old installer — it has to name them to clean them up.
ALLOWED_STALE_SYNC_CLEANUP_FILES = {
    "install/system/pacman-hooks.sh",
}

ALLOWED_SYNC_EXCLUDE_FILES = {
    "stow/quickshell/.config/quickshell/assets/scripts/workspace-manager.py",
    "tests/workspace-manager/test_backend.py",
}

# bluetooth.sh, plymouth.sh and root-space.sh edit single fields inside large,
# multi-purpose vendor/system files (bluez's main.conf, mkinitcpio.conf,
# pacman.conf, fstab) that have no drop-in mechanism and cannot be replaced
# wholesale without destroying unrelated content (fstab in particular
# necessarily holds entries from other subsystems). Every edit is guarded on
# the desired end state, so re-running is a no-op. See the comments at each
# site and the task report for the full justification.
ALLOWED_SED_ETC_FILES = {
    "install/system/bluetooth.sh",
    "install/system/plymouth.sh",
    "install/system/root-space.sh",
}


def _tracked_files():
    # This directory's own tests necessarily quote the forbidden strings
    # they assert against — they're the check, not the content being checked.
    self_dir = Path(__file__).resolve().parent
    for path in REPO.rglob("*"):
        if not path.is_file():
            continue
        if path.resolve().is_relative_to(self_dir):
            continue
        if EXCLUDED_DIR_NAMES & set(path.relative_to(REPO).parts):
            continue
        yield path


def test_no_references_to_deleted_sync_mechanism():
    offenders = []
    for path in _tracked_files():
        if str(path.relative_to(REPO)) in ALLOWED_STALE_SYNC_CLEANUP_FILES:
            continue
        if not path.is_file():
            continue
        try:
            text = path.read_text()
        except (UnicodeDecodeError, OSError):
            continue
        for needle in FORBIDDEN_SYNC_REFERENCES:
            if needle in text:
                offenders.append((str(path.relative_to(REPO)), needle))
    assert offenders == []


def test_no_references_to_sync_exclude_outside_the_allowed_feature():
    offenders = []
    for path in _tracked_files():
        rel = str(path.relative_to(REPO))
        if rel in ALLOWED_SYNC_EXCLUDE_FILES:
            continue
        if not path.is_file():
            continue
        try:
            text = path.read_text()
        except (UnicodeDecodeError, OSError):
            continue
        if "sync-exclude" in text:
            offenders.append(rel)
    assert offenders == []


def test_no_sed_i_or_append_against_etc_paths_in_install_system():
    system_dir = REPO / "install/system"
    offenders = []
    for path in sorted(system_dir.glob("*.sh")):
        rel = str(path.relative_to(REPO))
        if rel in ALLOWED_SED_ETC_FILES:
            continue
        text = path.read_text()
        for line in text.splitlines():
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            if re.search(r"sed\s+-i.*[\"']?/etc/", stripped):
                offenders.append((rel, stripped))
            if re.search(r">>\s*[\"']?/etc/", stripped):
                offenders.append((rel, stripped))
    assert offenders == []


def test_dependency_json_and_related_dead_code_are_gone():
    for path in (
        "packages/dependencies.json",
        "lib/package/dependency.sh",
        "lib/package/manage.sh",
        "lib/package/sync.sh",
        "lib/package/install-audit.sh",
        "lib/package/common.sh",
        "system/pacman/hooks/dotfiles-sync-install.hook",
        "system/pacman/hooks/dotfiles-sync-remove.hook",
        "stow/scripts/.local/bin/dotfiles-package-sync",
    ):
        assert not (REPO / path).exists(), f"{path} should have been deleted"
