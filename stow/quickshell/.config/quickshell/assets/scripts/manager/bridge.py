#!/usr/bin/env python3
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import uuid


def parse_options(args):
    values, options = [], {}
    takes_value = {'header', 'selected', 'height', 'limit', 'placeholder', 'value', 'prompt',
                   'width', 'title', 'spinner', 'timeout', 'default', 'affirmative', 'negative',
                   'cursor-prefix', 'selected-prefix', 'unselected-prefix'}
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == '--':
            values.extend(args[index + 1:])
            break
        if arg.startswith('--'):
            key, separator, value = arg[2:].partition('=')
            if not separator and key in takes_value and index + 1 < len(args):
                index += 1
                value = args[index]
            options.setdefault(key, []).append(value if separator or key in takes_value else True)
        else:
            values.append(arg)
        index += 1
    return values, options


def ask(kind, values, options):
    directory = Path(os.environ['WORKSPACE_MANAGER_STATE'])
    prompt_id = uuid.uuid4().hex
    data = {'id': prompt_id, 'jobId': os.environ['WORKSPACE_MANAGER_JOB'], 'kind': kind,
            'title': options.get('header', options.get('placeholder', options.get('prompt', [''])))[-1] or ('Choose an option' if kind in ('choose', 'filter') else 'Continue?'),
            'options': values, 'selected': options.get('selected', []),
            'multiple': 'no-limit' in options or int(options.get('limit', ['1'])[-1]) > 1,
            'limit': 0 if 'no-limit' in options else int(options.get('limit', ['1'])[-1]),
            'value': options.get('value', [''])[-1]}
    log = Path(os.environ['WORKSPACE_MANAGER_LOG'])
    if log.exists():
        with log.open('rb') as stream:
            stream.seek(max(0, log.stat().st_size - 16000))
            data['context'] = stream.read().decode(errors='replace')
    if kind == 'confirm':
        data['title'] = '\n'.join(values) or data['title']
        data['options'] = [options.get('affirmative', ['Continue'])[-1], options.get('negative', ['Skip'])[-1]]
    temporary = directory / 'prompt.new'
    temporary.write_text(json.dumps(data))
    temporary.chmod(0o600)
    temporary.replace(directory / 'prompt.json')
    response = directory / (prompt_id + '.response')
    while not response.exists():
        time.sleep(0.15)
    answer = json.loads(response.read_text())
    response.unlink()
    (directory / 'prompt.json').unlink(missing_ok=True)
    if answer.get('cancel'):
        (directory / 'cancelled').touch()
        # Hardware setup catches TERM without exiting; cancellation must not resume later steps.
        os.killpg(int(os.environ['WORKSPACE_MANAGER_PGID']), signal.SIGKILL)
        sys.exit(130)
    if kind == 'confirm':
        return 0 if answer.get('accepted') else 1
    print('\n'.join(answer.get('values', [])))
    return 0


def gum(args):
    kind, args = args[0], args[1:]
    if kind == 'spin':
        return subprocess.call(args[args.index('--') + 1:])
    if kind in ('choose', 'filter', 'confirm', 'input', 'write'):
        values, options = parse_options(args)
        if not values and kind in ('choose', 'filter'):
            values = sys.stdin.read().splitlines()
        return ask(kind, values, options)
    if kind in ('pager', 'table'):
        values, _ = parse_options(args)
        print(Path(values[0]).read_text() if values and Path(values[0]).is_file() else sys.stdin.read())
        return 0
    return subprocess.call(['/usr/bin/gum', kind, *args], env={**os.environ, 'NO_COLOR': '1', 'TERM': 'dumb'})


def sudo(args):
    if args in (['-v'], ['-n', 'true'], ['-n', '-v'], ['-k']):
        return 0
    args = [arg for arg in args if arg not in ('-E', '--preserve-env')]
    if args and args[0].startswith('-'):
        raise ValueError('Unsupported privilege option: ' + args[0])
    if os.environ.get('WORKSPACE_MANAGER_READ_ONLY') == '1':
        raise ValueError('A read-only operation attempted to request elevated access.')
    return subprocess.call(['pkexec', *args])


if __name__ == '__main__':
    try:
        sys.exit(gum(sys.argv[2:]) if sys.argv[1] == 'gum' else sudo(sys.argv[2:]))
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
