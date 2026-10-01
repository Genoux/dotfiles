# Dotfiles simplification: LLM implementation plan

## Objective and status

Turn the current desktop into one coherent system: Quickshell handles daily
interaction, `dotfiles` handles administration, and `install.sh` prepares an
installed Arch system. Keep the working desktop and reduce duplicate machinery.

Source: [system proposal](system-proposal.html), audited September 17, 2026 at
`695ad7f539883f3a3e6ee31beacd53fb8ad111eb`.

This is an execution plan, not a record of completed implementation. All tasks
below are pending. The user requested this plan; execute it only when asked to
implement. Once implementation is requested, proceed through ordinary repository
edits and checks without requesting approval after every task.

## Instructions for the implementing agent

1. Read root `AGENTS.md` and any applicable nested instructions. Inspect the
   working tree and relevant source before editing; source takes precedence over
   stale audit line numbers. Preserve unrelated changes, including the existing
   `stow/user/.config/mimeapps.list` edit if still present.
2. Work in the order below. Keep each task independently reviewable. Update its
   checkbox only after its automated acceptance checks pass; record outstanding
   desktop or VM checks separately. Do not claim an unperformed check passed.
3. Reuse existing shell helpers, Gum, Stow, package manifests, and tests. Do not
   introduce an application framework, generic task engine, dependency injection
   framework, package database, or broad repository reorganization.
4. Preserve modular Hyprland Lua, native Bluetooth, tray/media behavior, session
   restore, Quickshell launch ownership, and the Awww → Matugen wallpaper flow.
   Do not restart Quickshell for wallpaper/theme changes or replace the shell.
5. Use `config/ShellActions.qml` for Quickshell actions and Lua action modules for
   Hyprland behavior. Check installed behavior and current primary documentation
   before changing fast-moving APIs; do not copy legacy dispatcher strings.
6. Keep official, AUR, custom, and selected hardware package sources separate.
   Never infer that all hardware manifests should be installed. Keep private
   applications in their custom-build path.
7. Use isolated test homes, stubbed system commands, and temporary Stow targets.
   Repository implementation does not authorize running real package operations,
   suspending, logging out, or deleting arbitrary live configuration. Prepare and
   test those changes first; report any remaining live verification needed.
8. Remember that stowed QML edits can hot-reload on the live desktop. Order edits
   so references are removed before their implementation files disappear.
9. Do not commit unless explicitly instructed. Do not spawn agents unless the
   execution request or applicable instructions authorize delegation.

## Target behavior

| Surface | Contract |
| --- | --- |
| Quickshell bar | Everyday controls and one System entry opening the terminal menu |
| System menu | Health, Update, Packages, Cleanup, Advanced; thin CLI dispatch |
| `dotfiles status` | Read-only observations; distinguishes healthy, needs attention, unknown, skipped |
| `dotfiles update` | One visible, locked update workflow with truthful failure reporting |
| `dotfiles packages update` | Compatibility alias to the same update implementation |
| System apply | One canonical setup runner, also used by the installer |
| `install.sh` | Inspect → packages → configuration → verification; optional private apps remain retryable |
| Recovery | Explicit backups, phase retry, config relink, and session-aware repair |
| Components gallery | Available through the existing developer IPC entry, loaded on demand |

New behavior and command names in this table are targets, not claims about the
current implementation. Preserve existing public commands where practical.

## Task order

Execute `T00` through `T12` sequentially. The four delivery batches are reliability
(`T01–T03`), subtraction (`T04–T06`), convergence (`T07–T10`), and polish (`T11–T12`).
`T00` establishes the baseline. Final release checks follow all four batches.

### T00 — Establish a reproducible baseline

- [ ] Complete

Read `dotfiles`, `install.sh`, `bin/dotfiles-menu`, `lib/menu.sh`, the proposal,
and `tests/installer/conftest.py`. Inventory manager launchers, desktop entries,
layer rules, tests, prompt bridges, and consumers of `updates.state` with `rg
--hidden`; ordinary file searches omit much of the Stow tree.

Reproduce the existing test result before editing. The audit recorded 125 passing
tests and one SystemInfo fixture failure. Inspect
`tests/quickshell/test_regressions.py` and
`stow/quickshell/.config/quickshell/services/SystemInfo.qml`; fix the missing
`saveCache()` test double if that remains the actual cause. Preserve assertions
about parser results rather than suppressing the error.

Acceptance: record baseline revision, relevant dirty files, test command and
result. The known fixture failure is resolved or accurately explained. Capture
read-only Hyprland errors and failed user units when the session is available.

### T01 — Make updates fail safely

- [ ] Complete

Read `lib/package/update.sh`, its logging helpers, and callers in `dotfiles` and
the menu. Remove automatic conflict-package removal with `pacman -Rdd` and its
retry branch. Let dependency conflicts remain visible and return failure.

Keep the user's `.npmrc` in place. Scope the npm environment override to build
commands instead of moving the file. Retain only justified retry behavior; a
retry must not hide the original failure or start after cancellation. Ensure
logging pipelines preserve the package command's exit status.

Acceptance: stubbed conflict, generic failure, success, SIGINT, and SIGTERM cases
verify exit behavior and cleanup. `.npmrc` contents and location remain unchanged;
no forced dependency removal occurs. Cancellation starts no later package step.

### T02 — Make system apply and status truthful

- [ ] Complete

Read `lib/system.sh`, `install/system/setup.sh`, individual setup scripts, and
`run_logged` before altering their contracts. For this task, repair failure
propagation without yet consolidating the two script lists.

System apply must stop on a required failure and avoid its success menu. A status
command must not source executable setup scripts that apply changes. Use small,
side-effect-free checks for known settings and report unknown for unchecked
settings. Do not count unknown or skipped as healthy.

Acceptance: stubbed failed setup returns nonzero; later required work does not
run. Status triggers no sudo, writes, package operations, or service mutations.
Healthy, failed, unchecked, and inapplicable cases produce distinct states.

### T03 — Repair resume and disable unsupported rollback

- [ ] Complete

Read `stow/scripts/.local/bin/system-lock-after-sleep`, the installed Hypridle
example, `lib/recovery.sh`, `lib/install-state.sh`, and rollback menu/CLI callers.
Correct the DPMS Lua argument shape using the installed API and retain the
healthy-lock guard. Surface actionable dispatch failures through existing logging.

Disable destructive phase rollback entry points with a clear explanation of what
is unsupported. Keep phase retry and existing backup data. Do not advertise
restoration of package versions or previous file contents from inventory files.

Acceptance: extend `tests/installer/test_sleep_resume.py` as appropriate; a healthy
lock is never killed. Rollback cannot remove packages or links through any public
entry. Mark actual suspend/resume as pending until performed in an authorized
session. Full replacement of obsolete recovery paths happens in T10.

### T04 — Retire the experimental graphical manager

- [ ] Complete

Use `stow/quickshell/.config/quickshell/` as the base for these removal candidates:
`manager.qml`, `manager/`, `assets/scripts/workspace-manager.py`, and
`assets/scripts/manager/`. Locate and remove `launch-workspace-manager`,
`workspace-manager.desktop`, manager-specific Hyprland layer rules, and obsolete
allowlist entries. Inspect temporary-package exclusion data before deleting it.

Review `tests/workspace-manager/` first. Move useful CLI failure and cancellation
coverage into the surviving command tests; delete tests that exercise only the
retired GUI/backend. Preserve shared shell components and the terminal menu.

Acceptance: executable configuration has no retired-manager references; historical
reports and this plan are excluded from that search. A temporary Stow target has
no broken manager links after cleanup. Shell and lock QML still lint/load. No
shared component is removed merely because the manager imported it.

### T05 — Make the bar and launch paths smaller

- [ ] Complete

Read `bar/Bar.qml`, `bar/widgets/Dotfiles.qml`, `services/Dotfiles.qml`,
`config/ShellActions.qml`, `shell.qml`, and `debug/ComponentGalleryWindow.qml` under
the Quickshell tree. Also read Hyprland `actions/launchers.lua`,
`launch-dotfiles-menu`, desktop entries, and `bin/dotfiles-menu`.

Remove the Components button and the stale update badge/unused state reader.
Preserve `DESIGN.md`, tokens, shared components, and the `components` IPC entry.
Load the gallery on explicit request; its icon scan must not run during normal
startup. Preserve multi-monitor open/close behavior.

Consolidate the bar, Super+D, and one desktop entry onto the same terminal launch
path. Keep the menu thin and organize it into the five target groups. Wire only
implemented actions; T09 adds the final update alias. Preserve access to existing
configuration/setup functions through Advanced.

Acceptance: each launch surface opens or focuses the same TUI; default startup
does not construct/scan the gallery; developer IPC still opens it. Existing daily
controls and the lock continue working. No new background update checker is added.

### T06 — Add precise cleanup for retired files

- [ ] Complete

Inventory the retired Walker autostart, Elephant remnants, obsolete swaync/Waybar
declarations, compatibility links, and removed manager links. Determine ownership
and active consumers before selecting anything for deletion.

Implement the smallest versioned migration mechanism needed for these known
changes, using existing helpers where possible. Support an inspect/dry-run path.
Back up files that are changed; leave modified or unrecognized files alone and
report them. For dangling links, verify the exact old target before removal.
Record a migration as applied only after it succeeds; repeated runs are harmless.

Acceptance: temporary-home tests cover recognized, absent, modified, and failed
migration cases plus reruns. No broad directory purge or package uninstall occurs.
Repository manifest cleanup does not uninstall packages from the live machine.
T09 wires successful updates to this mechanism.

### T07 — Use one setup runner and one normal package transaction

- [ ] Complete

Read `install.sh`, `install/system/setup.sh`, `lib/system.sh`,
`lib/package/preflight.sh`, `lib/package/install-official.sh`,
`lib/package/install.sh`, and the installation helpers.

Make installer and system apply use one explicit, ordered setup list. Resolve
membership differences deliberately: hardware applicability and system/user
privilege boundaries must be explicit, not a blind union of scripts. Keep leaf
scripts responsible for their existing configuration.

Separate inspection from mutation in preflight. Consolidate the ordinary official
upgrade/install path into one full transaction, followed by AUR. Keep necessary
bootstrap exceptions explicit and avoid a standalone database refresh followed
by a partial upgrade. Mark phases complete only after their work succeeds.

Acceptance: stubs prove both entry points use the canonical runner and propagate
failure; selected hardware is correct. Normal-path tests observe one official
full transaction, with separate bootstrap cases. Existing interrupt and
partial-upgrade regression tests pass.

### T08 — Report package coverage and optional completion accurately

- [ ] Complete

Read `lib/package/custom.sh`, `lib/package/status.sh`, `lib/package/verify.sh`,
`lib/hardware-packages.sh`, manifests, and installer completion/resume handling.

Verify official/AUR selections and only the detected hardware alternatives. Add
the smallest explicit mapping needed between custom repository names and built
package names; preserve the existing custom-manifest contract or migrate all its
consumers together. Do not guess package names from repository names.

Missing GitHub authentication leaves private applications pending, with an explicit
retry path, while a ready desktop remains usable. Distinguish genuine build
failure from an optional skipped step. Report manually installed packages outside
the selected manifests as untracked, separately from pacman's orphan classification.

Acceptance: cover missing auth, build failure, successful retry, untracked explicit
packages, actual orphans, and alternate hardware selections. Resume does not skip
pending private applications or reinstall completed core phases unnecessarily.

### T09 — Provide one public update workflow

- [ ] Complete

Depends on T01, T05, T06, and T08. Add `dotfiles update`; retain
`dotfiles packages update` as an alias to the same function. Update CLI help and
the terminal menu together.

Use one operation lock across update preflight, package work, migrations, and final
reporting. Reuse existing locking if suitable; avoid recursively acquiring the
same lock through aliases. Show package-manager prompts in the terminal. Run
pending migrations only after package success; migration failure makes the overall
result unsuccessful without pretending the package transaction was rolled back.

Report failed steps, custom builds pending, configuration merges, and any detected
restart needs. Report unknown when a restart need cannot be determined reliably.
Do not automatically pull the repository or silently rebuild private apps.

Acceptance: both aliases reach one implementation; concurrent invocation is
rejected clearly. Failure/cancellation releases the lock and prevents later work.
Success runs each pending migration once. Menu cancellation is harmless.

### T10 — Replace inventory rollback with backups and retry

- [ ] Complete

Read `lib/atomic.sh`, `lib/install-state.sh`, `lib/recovery.sh`,
`install/config/stow.sh`, conflict/backup helpers, and every caller before removal.

Remove unused atomic staging and obsolete rollback machinery after preserving
useful phase tracking. Back up conflicting configuration content before overwrite;
retain file/link type and enough metadata to identify its source and destination.
Provide a clear restore route for these backups, without claiming whole-system
rollback. Retry failed phases safely and handle existing state files explicitly.

Replace recovery's legacy `conf/autostart.conf` edits with targeted diagnostics,
config relink, and a session-aware Quickshell restart. Preserve the running lock;
never use broad process termination against all Quickshell processes.

Acceptance: temporary-home tests demonstrate backup and restoration of files and
symlinks, interruption/retry, and old-state compatibility or a clear migration
message. No active recovery path edits legacy autostart config. Documentation and
CLI output describe the actual recovery limits.

### T11 — Give theme and session state clear owners

- [ ] Complete

Read `lib/gtk.sh`, `lib/theme.sh`, Hyprland `env.lua`, `cursor.lua`,
`autostart.lua`, relevant systemd user units, and the UWSM session entry.

Remove the fixed GTK theme override so installed theme selection owns the state.
Before theme uninstall, select available fallback assets and update cursor/theme
settings consistently. Preserve cursor size ownership and generated cursor theme.
Move one-shot browser/window-button defaults into idempotent setup rather than
resetting user choices every login.

Inspect each duplicated service start/stop path. Consolidate lifecycle ownership
under the existing graphical session units only after checking their environment,
ordering, and stop behavior. Preserve service names and Quickshell's Hyprland
launch. Keep one-shot login tasks separate from frequent daemons.

Acceptance: isolated theme install/switch/uninstall tests leave no selected missing
asset. Unit validation passes. Record relogin, portals/screen sharing, shutdown,
lock, and session restore checks separately; do not claim runtime lifecycle
correctness from source inspection alone.

### T12 — Finish documentation and regression checks

- [ ] Complete

Update `INSTALLATION.md`, CLI help, and affected existing agent instructions to
match the final implementation. Keep the proposal as a historical audit; do not
rewrite its baseline observations as new test results.

Add or extend the smallest existing automation entry for shell syntax, focused
behavior tests, QML lint, and retired runtime references. Detect shell scripts by
their interpreter as well as extension so extensionless helpers are included.
Exclude intentional historical documentation from obsolete-reference checks.

Acceptance: all retained tests pass; removed GUI-only tests are accounted for.
Meaningful regression coverage protects update failure, read-only status, setup
consistency, optional apps, migrations, recovery, and gallery lazy loading. Do not
add snapshot/string tests that merely duplicate the implementation.

## Validation procedure

For each task, run `bash -n` on changed Bash files and the smallest relevant test
subset. Inspect the sandbox fixture first: its sudo stub forwards commands and
its PATH can fall back to the real system. Stub every mutating command and redirect
all filesystem targets before executing new tests.

The audit's full-suite command was:

```sh
uv run --no-project --python /usr/bin/python --with pytest python -c 'import sys; sys.path.append("/usr/lib/python3.14/site-packages"); import pytest; raise SystemExit(pytest.main(["-q", "tests"]))'
```

The Python GI path is machine/version specific. Recheck the interpreter and GI
availability rather than copying that path blindly. Do not install system packages
to make the tests run without authorization. Inspect and reuse local QML lint
configuration/import paths; unresolved tooling imports are not automatically QML
runtime defects.

After all tasks, run the retained full suite and `git diff --check`. Inspect the
diff for unrelated edits, stale launch paths, misleading success messages, and
new work performed during normal login.

## Final acceptance matrix

| Environment | Required evidence |
| --- | --- |
| Isolated tests | Failure/cancellation propagation; one setup/update implementation; truthful status; optional-app retry; idempotent migrations and backup restoration |
| Temporary Stow home | Link, unlink, relink, and removal cleanup without broken links or loss of unrelated files |
| Desktop session | Bar/key/desktop launcher consistency; developer gallery IPC; lock and controlled resume; Bluetooth/media/tray preserved |
| Relogin | No retired Walker failure; correct theme/cursor; portals, session restore, daemon start/stop, and Quickshell launch intact |
| Disposable Arch VM | Fresh install, rerun, interruption/resume, missing private-app auth, and selected hardware verification |

The desktop and VM rows require actual execution in an appropriate environment.
When unavailable, finish repository work, list the precise pending checks, and
label the result implementation-complete but runtime-validation-pending. Do not
mark the entire plan verified until these rows are satisfied.

## Deferred work

Keep Info, weather, and other functioning widgets unless a later request changes
their scope. Profile closed-panel polling, crowded-tray/title overlap, Matugen
Terax output verification, and the absent optional wallpaper transition config
separately. One RSS observation is not evidence of a leak. Do not turn these
follow-ups into an unbounded performance rewrite.

## Continuation record

Update this section during implementation so another LLM can resume from files
without reconstructing a conversation.

- Last completed task: none; plan only.
- Current task: not started.
- Files changed for implementation: none.
- Tests run for implementation: none.
- Pending runtime/VM checks: all rows requiring those environments.
- Decisions/deviations: none.
- Next action: T00 after an implementation request.

Suggested execution prompt:

> Implement `docs/system-implementation-plan.md`. Read AGENTS.md first, recheck
> the working tree, and continue from its continuation record. Complete the
> ordered repository tasks and their isolated checks, updating progress as you
> go. Preserve unrelated edits and the working desktop. Do not commit or perform
> real package operations. Report outstanding desktop/VM verification honestly.
