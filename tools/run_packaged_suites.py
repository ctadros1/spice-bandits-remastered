#!/usr/bin/env python3
"""Run the ten frozen-package suites sequentially, retaining failure/protection state.

Does not build, seed a campaign, grant a reward, or alter normal profiles.
The underlying suites use isolated QA state. Source and package must remain
frozen for the entire invocation. A successful batch is not visual acceptance.
"""
import argparse
from datetime import datetime, timezone
import json
import re
import subprocess
import sys
from pathlib import Path
from run_packaged_qa import ROOT, BUILD, APP, EXE, PACK, digest, native_libraries, app_processes

SUITES = ['presentation', 'performance', 'menus', 'tutorial', 'audio',
          'projectiles', 'turns', 'towers', 'desert', 'campaign']

def identity():
    return {'pck_sha256': digest(PACK), 'executable_sha256': digest(EXE),
            'native_libraries_sha256': native_libraries()}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True, help='Unique evidence label, e.g. bolt-order-r80')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9-]+', args.label): parser.error('Use lowercase letters, digits and hyphens.')
    output = BUILD / (args.label + '-native-suites.json')
    if output.exists(): parser.error('Evidence label already exists; choose a fresh label.')
    if app_processes(): parser.error('A game/engine process is already running; do not overlap suites.')
    base = Path.home() / 'Library/Application Support/Godot/app_userdata/Spice Bandits Remastered'
    protected = [base / name for name in ['profile.json', 'profile.json.bak',
                 'verification/fresh-campaign-profile.json', 'verification/fresh-campaign-profile.json.bak']]
    hashes = lambda: {str(path): digest(path) if path.exists() else None for path in protected}
    initial_identity = identity()
    state = {**initial_identity, 'started_utc': datetime.now(timezone.utc).isoformat(),
             'protected_before': hashes(), 'suites': [], 'passed': False}
    def save(): output.write_text(json.dumps(state, indent=2) + '\n')
    save()
    try:
        for suite in SUITES:
            started = datetime.now(timezone.utc)
            log_path = BUILD / ('package-' + suite + '-' + args.label + '.log')
            with log_path.open('x') as log:
                result = subprocess.run([sys.executable, str(ROOT / 'tools/run_packaged_qa.py'), '--' + suite],
                                        cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
            audit = json.loads((BUILD / (suite + '-package-audit.json')).read_text())
            fresh_audit = datetime.fromisoformat(audit['started_utc']) >= started
            row = {'suite': suite, 'passed': result.returncode == 0 and audit['passed'] and fresh_audit
                   and all(audit.get(key) == value for key, value in initial_identity.items()),
                   'captures': audit.get('captures', 1),
                   'checks': audit.get('verification', {}).get('checks'),
                   'audit': str(Path('builds') / (suite + '-package-audit.json')),
                   'log': str(log_path.relative_to(ROOT))}
            state['suites'].append(row); save(); print(json.dumps(row), flush=True)
            if not row['passed']: break
    except Exception as error:
        state['error'] = type(error).__name__ + ': ' + str(error)
    finally:
        state['protected_after'] = hashes()
        state['protected_unchanged'] = state['protected_before'] == state['protected_after']
        state['package_unchanged'] = identity() == initial_identity
        state['remaining_game_processes'] = app_processes()
        state['no_remaining_game_processes'] = not state['remaining_game_processes']
        state['passed'] = (len(state['suites']) == len(SUITES) and all(row['passed'] for row in state['suites'])
                           and state['protected_unchanged'] and state['package_unchanged']
                           and state['no_remaining_game_processes'] and 'error' not in state)
        state['finished_utc'] = datetime.now(timezone.utc).isoformat(); save()
    print(json.dumps({'passed': state['passed'], 'evidence': str(output.relative_to(ROOT)),
                      'protected_unchanged': state['protected_unchanged'],
                      'package_unchanged': state['package_unchanged']}), flush=True)
    return 0 if state['passed'] else 1

if __name__ == '__main__': sys.exit(main())
