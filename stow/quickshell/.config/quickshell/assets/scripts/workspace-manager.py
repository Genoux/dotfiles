#!/usr/bin/env python3
import argparse
import concurrent.futures
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid
import platform

HOME = Path.home()
REPO = HOME / 'dotfiles'
STATE = Path(os.environ.get('XDG_STATE_HOME', HOME / '.local/state')) / 'quickshell/workspace-manager'
MANAGER = Path(__file__).resolve().parent / 'manager'
CATALOG = json.loads((MANAGER / 'catalog.json').read_text())
OPERATIONS = {action['id']: action for page in CATALOG for action in page['actions']}
PACKAGE_NAME = re.compile(r'[a-zA-Z0-9@_+][a-zA-Z0-9@._+\-]*\Z')
CLEANUP = {
    'trash': ('Empty trash', 'Permanently delete files in your home trash.'),
    'packages': ('Package cache', 'Keep two installed versions for rollback; discard uninstalled packages.'),
    'aur': ('AUR build cache', 'Remove cached builds and downloaded sources.'),
    'downloads': ('Interrupted downloads', 'Remove leftover pacman download directories.'),
    'npm': ('npm cache', 'Clear downloaded npm packages.'),
    'apps': ('Application caches', 'Clear your user cache. Running apps may need to recreate files.'),
    'journal': ('System journal', 'Keep the last two weeks of system logs.'),
    'orphans': ('Orphaned packages', 'Remove unused dependencies after reviewing their names.'),
}


def read_json(name, default):
    path = STATE / name
    if not path.exists():
        return default
    return json.loads(path.read_text())


def write_json(name, data):
    STATE.mkdir(parents=True, exist_ok=True)
    path = STATE / name
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex + '.new')
    temporary.write_text(json.dumps(data))
    temporary.replace(path)


def capture(args, accepted=(0,), timeout=60):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout,
                            env={**os.environ, 'LC_ALL': 'C'}, stdin=subprocess.DEVNULL)
    if result.returncode not in accepted or (result.returncode != 0 and result.stderr.strip()):
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f'{args[0]} exits with {result.returncode}')
    return result.stdout.strip()


def installed():
    return set(capture(['pacman', '-Qq']).splitlines())


def manifest_packages():
    paths = list((REPO / 'packages').glob('*.package')) + list((REPO / 'packages/hardware').glob('*.package'))
    return {line.split('#', 1)[0].strip() for path in paths for line in path.read_text().splitlines()}


def exclude(package, add):
    path = REPO / 'packages/sync-exclude'
    lines = path.read_text().splitlines() if path.exists() else []
    if add and package not in lines:
        lines.append(package)
    elif not add:
        lines = [line for line in lines if line != package]
    path.write_text('\n'.join(lines) + '\n')


def job_running():
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / 'operation.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
    return False


def status():
    job = read_json('job.json', {})
    busy = job_running()
    if job.get('status') == 'running' and not busy:
        job = {**job, 'status': 'interrupted', 'error': 'The operation stopped unexpectedly. Review the log before retrying.'}
    disk = shutil.disk_usage('/')
    log = STATE / 'activity.log'
    output = ''
    if log.exists():
        with log.open('rb') as stream:
            stream.seek(max(0, log.stat().st_size - 24000))
            output = stream.read().decode(errors='replace')
    temporary = read_json('temporary.json', [])
    if temporary and not busy:
        present = installed()
        temporary = [{**entry, 'status': 'installed' if entry['name'] in present else 'not installed'} for entry in temporary]
    return {'busy': busy, 'job': job, 'log': re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]', '', output),
            'diskFree': disk.free, 'diskTotal': disk.total, 'logSize': log.stat().st_size if log.exists() else 0,
            'temporary': temporary,
            'updates': read_json('updates.json', {}),
            'cleanup': read_json('cleanup.json', {}), 'catalog': CATALOG,
            'overview': read_json('overview.json', {}),
            'details': read_json('details.json', {}),
            'prompt': read_json('prompt.json', {}) if busy else {},
            'rebootRequired': (HOME / '.local/state/dotfiles/.reboot_needed').exists()}


def log_page(request):
    offset = request.get('offset', 0)
    if not isinstance(offset, int) or offset < 0:
        raise ValueError('Invalid log position')
    path = STATE / 'activity.log'
    if not path.exists():
        return {'text': '', 'offset': 0}
    with path.open('rb') as stream:
        stream.seek(offset)
        value = stream.read(24000).decode(errors='replace')
    return {'text': re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]', '', value), 'offset': offset}


def run(args):
    print('+ ' + ' '.join(args), flush=True)
    result = subprocess.run(args, stdin=subprocess.DEVNULL,
                            env={**os.environ, 'LC_ALL': 'C', 'NPM_CONFIG_USERCONFIG': '/dev/null'})
    if result.returncode:
        raise RuntimeError(f'{args[0]} exits with {result.returncode}. See the output above.')


def privileged(*args):
    run(['pkexec', *args])


def yay(*args):
    # https://jguer.github.io/yay/man.html: --sudo keeps AUR builds unprivileged.
    run(['yay', '--sudo', 'pkexec', '--sudoflags', '', '--sudoloop=false',
         '--noconfirm', '--useask=false', '--answerclean', 'N', '--answerdiff', 'N', *args])


def check_updates():
    sources = [('official', ['checkupdates']), ('aur', ['yay', '-Qua'])]
    data = {'checked': int(time.time()), 'packages': [], 'errors': []}
    with concurrent.futures.ThreadPoolExecutor() as pool:
        pending = [(name, pool.submit(capture, command, (0, 2), 180)) for name, command in sources]
        for source, future in pending:
            try:
                for line in future.result().splitlines():
                    parts = line.split()
                    if len(parts) >= 4 and parts[2] == '->':
                        data['packages'].append({'name': parts[0], 'current': parts[1], 'next': parts[3], 'source': source})
            except Exception as error:
                data['errors'].append(f'{source}: {error}')
    write_json('updates.json', data)
    if data['errors']:
        raise RuntimeError('\n'.join(data['errors']))
    print(f"{len(data['packages'])} updates available.", flush=True)


def scan_cleanup():
    paths = {'trash': HOME / '.local/share/Trash', 'packages': Path('/var/cache/pacman/pkg'),
             'aur': HOME / '.cache/yay', 'npm': HOME / '.npm/_cacache', 'apps': HOME / '.cache'}
    data = {'checked': int(time.time()), 'sizes': {}, 'errors': []}
    for key, path in paths.items():
        if not path.exists():
            data['sizes'][key] = 0
            continue
        try:
            data['sizes'][key] = int(capture(['du', '-sb', str(path)]).split()[0])
        except Exception as error:
            print(f'{key}: {error}', flush=True)
            data['errors'].append(f'Unable to measure {CLEANUP[key][0].lower()}. See Activity for details.')
    data['orphans'] = capture(['pacman', '-Qtdq'], (0, 1)).splitlines()
    write_json('cleanup.json', data)
    print('Cleanup scan complete.', flush=True)


def clear_directory(path):
    if path.is_symlink():
        raise RuntimeError(f'Refusing to clear a redirected directory: {path}')
    if path.exists():
        for entry in path.iterdir():
            if entry.is_symlink() or not entry.is_dir():
                entry.unlink()
            else:
                shutil.rmtree(entry)


def clean(key, reviewed_orphans):
    if key == 'trash':
        clear_directory(HOME / '.local/share/Trash/files')
        clear_directory(HOME / '.local/share/Trash/info')
    elif key == 'packages':
        privileged('paccache', '-rk2')
        privileged('paccache', '-ruk0')
    elif key == 'aur':
        clear_directory(HOME / '.cache/yay')
    elif key == 'downloads':
        privileged('find', '/var/cache/pacman/pkg', '-maxdepth', '1', '-type', 'd', '-name', 'download-*', '-exec', 'rm', '-rf', '--', '{}', '+')
    elif key == 'npm':
        run(['npm', 'cache', 'clean', '--force'])
    elif key == 'apps':
        clear_directory(HOME / '.cache')
    elif key == 'journal':
        privileged('journalctl', '--vacuum-time=2weeks')
    elif key == 'orphans':
        current = set(capture(['pacman', '-Qtdq'], (0, 1)).splitlines())
        names = sorted(current.intersection(reviewed_orphans))
        if names:
            privileged('pacman', '-Rn', '--noconfirm', '--', *names)
    else:
        raise ValueError('Unknown cleanup category')


def temporary_install(package, source):
    if package in installed() or package in manifest_packages():
        raise RuntimeError('This package is already installed or managed by dotfiles.')
    query = ['pacman', '-Si', '--', package] if source == 'official' else ['yay', '-Si', '--aur', '--', package]
    information = capture(query)
    if not re.search(r'^Name\s*:\s*' + re.escape(package) + r'\s*$', information, re.MULTILINE):
        raise RuntimeError('No exact package matches this name in the selected source.')
    if shutil.disk_usage('/').free < 3 * 1024 ** 3:
        raise RuntimeError('At least 3 GiB of free root space is required. Review Cleanup first.')
    records = read_json('temporary.json', [])
    if any(record['name'] == package for record in records):
        raise RuntimeError('This package is already tracked. Remove the existing entry before retrying.')
    existing_exclusions = (REPO / 'packages/sync-exclude').read_text().splitlines() if (REPO / 'packages/sync-exclude').exists() else []
    record = {'name': package, 'source': source, 'created': int(time.time()),
              'ownsExclusion': package not in existing_exclusions, 'status': 'installing'}
    records.append(record)
    write_json('temporary.json', records)
    exclude(package, True)
    try:
        if source == 'official':
            privileged('pacman', '-Syu', '--needed', '--noconfirm', '--', package)
        else:
            yay('-Syu', '--needed', '--', package)
    finally:
        record['status'] = 'installed' if package in installed() else 'not installed'
        write_json('temporary.json', records)
    if record['status'] != 'installed':
        raise RuntimeError('The requested package is not installed. Review the output and remove its tracking entry before retrying.')


def finish_temporary(package, keep):
    records = read_json('temporary.json', [])
    record = next((entry for entry in records if entry['name'] == package), None)
    if record is None:
        raise RuntimeError('This package is not tracked as temporary.')
    present = package in installed()
    if keep:
        if not present:
            raise RuntimeError('This package is not installed. Remove the tracking entry instead.')
        path = REPO / 'packages' / ('arch.package' if record['source'] == 'official' else 'aur.package')
        lines = path.read_text().splitlines()
        if package not in lines:
            with path.open('a') as stream:
                stream.write(('\n' if lines and not path.read_text().endswith('\n') else '') + package + '\n')
    elif present:
        if package in manifest_packages():
            raise RuntimeError('This package is now managed by dotfiles. Keep it to finish tracking.')
        privileged('pacman', '-R', '--noconfirm', '--', package)
    if record['ownsExclusion']:
        exclude(package, False)
    write_json('temporary.json', [entry for entry in records if entry['name'] != package])


def overview():
    def query(args):
        try:
            return capture(args)
        except Exception:
            return ''
    cpu = next((line.split(':', 1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines() if line.startswith('model name')), platform.machine())
    memory = next(int(line.split()[1]) * 1024 for line in Path('/proc/meminfo').read_text().splitlines() if line.startswith('MemTotal:'))
    package_lines = query(['pacman', '-Q']).splitlines()
    explicitly_installed = set(query(['pacman', '-Qqe']).splitlines())
    foreign = set(query(['pacman', '-Qmq']).splitlines())
    tracked = {}
    for source, path in [('official', REPO / 'packages/arch.package'), ('aur', REPO / 'packages/aur.package')]:
        for line in path.read_text().splitlines():
            name = line.split('#', 1)[0].strip()
            if name:
                tracked[name] = source
    excluded_path = REPO / 'packages/sync-exclude'
    excluded = set(excluded_path.read_text().splitlines()) if excluded_path.exists() else set()
    hardware = {line.split('#', 1)[0].strip() for path in (REPO / 'packages/hardware').glob('*.package') for line in path.read_text().splitlines()}
    packages = []
    present = set()
    for line in package_lines:
        name, version = line.split(' ', 1)
        present.add(name)
        packages.append({'name': name, 'version': version, 'source': 'foreign' if name in foreign else 'official',
                         'state': 'temporary / excluded' if name in excluded else 'hardware' if name in hardware else 'tracked' if name in tracked else 'unlisted' if name in explicitly_installed else 'dependency'})
    packages.extend({'name': name, 'version': '', 'source': source, 'state': 'missing'} for name, source in tracked.items() if name not in present)
    data = {'checked': int(time.time()), 'host': platform.node(), 'kernel': platform.release(), 'cpu': cpu,
            'memory': memory, 'uptime': int(float(Path('/proc/uptime').read_text().split()[0])),
            'version': (REPO / 'VERSION').read_text().strip() if (REPO / 'VERSION').exists() else 'local',
            'packages': sorted(packages, key=lambda item: item['name']),
            'installedCount': len(package_lines), 'trackedCount': len(tracked),
            'configCount': len([path for path in (REPO / 'stow').iterdir() if path.is_dir()]),
            'theme': query(['gsettings', 'get', 'org.gnome.desktop.interface', 'gtk-theme']).strip("'"),
            'cursor': query(['gsettings', 'get', 'org.gnome.desktop.interface', 'cursor-theme']).strip("'")}
    write_json('overview.json', data)
    return data


def respond(request):
    prompt = read_json('prompt.json', {})
    if not job_running() or request.get('id') != prompt.get('id') or request.get('jobId') != prompt.get('jobId'):
        raise ValueError('This question is no longer active.')
    if not request.get('cancel') and prompt['kind'] in ('choose', 'filter'):
        values = request.get('values', [])
        if any(value not in prompt['options'] for value in values):
            raise ValueError('Choose only listed values.')
        limit = prompt.get('limit', 1)
        if limit and len(values) != 1 and (not prompt['multiple'] or len(values) > limit):
            raise ValueError('Invalid number of selected values.')
    if prompt['kind'] == 'confirm' and not request.get('cancel') and not isinstance(request.get('accepted'), bool):
        raise ValueError('Choose Continue or Skip.')
    path = STATE / (prompt['id'] + '.response')
    with path.open('x') as response:
        os.chmod(path, 0o600)
        json.dump(request, response)
    return {'answered': True}


def run_operation(request):
    operation = request['operation']
    runtime = STATE / 'runtime'
    if runtime.exists():
        shutil.rmtree(runtime)
    shutil.copytree(MANAGER, runtime)
    env = {**os.environ, 'WORKSPACE_MANAGER_REPO': str(REPO), 'WORKSPACE_MANAGER_STATE': str(STATE),
           'WORKSPACE_MANAGER_LOG': str(STATE / 'activity.log'), 'WORKSPACE_MANAGER_BRIDGE': str(runtime / 'bridge.py'),
           'WORKSPACE_MANAGER_JOB': request['id'], 'WORKSPACE_MANAGER_FAILURE': str(STATE / 'operation-error'),
           'WORKSPACE_MANAGER_READ_ONLY': '1' if OPERATIONS[operation].get('readOnly') else '0',
           'BASH_ENV': str(runtime / 'bridge.sh'), 'PATH': str(runtime / 'bin') + ':' + os.environ['PATH'],
           'LC_ALL': 'C', 'TERM': 'dumb', 'NO_COLOR': '1'}
    options = [flag for key, flag in [('skipPackages', '--skip-packages'), ('skipConfigs', '--skip-configs'), ('fresh', '--fresh')] if request.get(key)] if operation in ('full_install', 'resume_install') else []
    result = subprocess.run(['bash', str(runtime / 'run.sh'), operation, *options], env=env,
                            stdin=subprocess.DEVNULL, start_new_session=True)
    if OPERATIONS[operation].get('readOnly'):
        details = read_json('details.json', {})
        details[operation] = {'checked': int(time.time()), 'text': (STATE / 'activity.log').read_text(errors='replace')[-100000:], 'success': result.returncode == 0}
        write_json('details.json', details)
    if (STATE / 'cancelled').exists():
        raise InterruptedError('Operation cancelled. Already completed steps remain applied.')
    if result.returncode or (STATE / 'operation-error').exists():
        raise RuntimeError('The operation reports an error. Review Activity for details.')
    overview()


def validate(request):
    action = request.get('action')
    if action not in ('check', 'update', 'scan', 'cleanup', 'install', 'remove', 'keep', 'operation'):
        raise ValueError('Unknown action')
    if action == 'operation' and request.get('operation') not in OPERATIONS:
        raise ValueError('Unknown operation')
    if action == 'operation' and request.get('operation') == 'resume_install' and request.get('fresh'):
        raise ValueError('Resume and fresh installation cannot be combined.')
    if action in ('install', 'remove', 'keep') and not PACKAGE_NAME.fullmatch(request.get('package', '')):
        raise ValueError('Enter one exact package name; options and shell commands are not accepted.')
    if action == 'install' and request.get('source') not in ('official', 'aur'):
        raise ValueError('Unknown package source')
    if action == 'cleanup':
        if not request.get('categories') or any(key not in CLEANUP for key in request['categories']):
            raise ValueError('Select a cleanup category')
        if any(not PACKAGE_NAME.fullmatch(name) for name in request.get('orphans', [])):
            raise ValueError('Invalid orphan package list')


def execute(request):
    action = request['action']
    if action == 'operation':
        run_operation(request)
    elif action == 'check':
        check_updates()
    elif action == 'scan':
        scan_cleanup()
    elif action == 'update':
        if shutil.disk_usage('/').free < 3 * 1024 ** 3:
            raise RuntimeError('At least 3 GiB of free root space is required. Review Cleanup first.')
        yay('-Syu')
        write_json('updates.json', {})
    elif action == 'cleanup':
        for key in request['categories']:
            print(CLEANUP[key][0], flush=True)
            clean(key, request.get('orphans', []))
        scan_cleanup()
    elif action == 'install':
        temporary_install(request['package'], request['source'])
    else:
        finish_temporary(request['package'], action == 'keep')


def worker(request, lock_fd=None):
    STATE.mkdir(parents=True, exist_ok=True)
    with (os.fdopen(lock_fd, 'a') if lock_fd is not None else (STATE / 'operation.lock').open('a')) as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        job = {'id': request['id'], 'action': request.get('operation', request['action']), 'title': OPERATIONS.get(request.get('operation'), {}).get('title', request['action']), 'status': 'running', 'started': int(time.time())}
        write_json('job.json', job)
        for name in ('prompt.json', 'operation-error', 'cancelled'):
            (STATE / name).unlink(missing_ok=True)
        with (STATE / 'activity.log').open('w', buffering=1) as log:
            os.dup2(log.fileno(), 1)
            os.dup2(log.fileno(), 2)
            try:
                validate(request)
                if request['action'] not in ('check', 'scan', 'keep') and Path('/var/lib/pacman/db.lck').exists():
                    raise RuntimeError('Another package manager is active. Wait for it to finish.')
                execute(request)
                job['status'] = 'completed'
            except InterruptedError as error:
                job.update(status='cancelled', error=str(error))
            except Exception as error:
                job.update(status='failed', error=str(error))
                print(str(error), flush=True)
            job['finished'] = int(time.time())
            write_json('job.json', job)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--lock-fd', type=int)
    parser.add_argument('command', choices=['status', 'start', 'worker', 'overview', 'respond', 'log'])
    parser.add_argument('request', nargs='?', default='{}')
    args = parser.parse_args()
    try:
        if args.command == 'status':
            result = status()
        elif args.command == 'overview':
            result = overview()
        elif args.command == 'log':
            result = log_page(json.loads(args.request))
        elif args.command == 'respond':
            result = respond(json.loads(args.request))
        else:
            request = json.loads(args.request)
            validate(request)
            if args.command == 'worker':
                worker(request, args.lock_fd)
                return
            STATE.mkdir(parents=True, exist_ok=True)
            with (STATE / 'operation.lock').open('a') as lock:
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    raise RuntimeError('Another operation is already running.')
                request['id'] = uuid.uuid4().hex
                subprocess.Popen([sys.executable, str(Path(__file__).resolve()),
                                  '--lock-fd', str(lock.fileno()), 'worker', json.dumps(request)],
                                 stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                 start_new_session=True, pass_fds=(lock.fileno(),))
            result = {'started': True, 'id': request['id']}
        print(json.dumps(result))
    except Exception as error:
        print(json.dumps({'error': str(error)}))
        sys.exit(1)


if __name__ == '__main__':
    main()
