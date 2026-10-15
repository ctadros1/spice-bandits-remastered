"""Launch a protected, earned-reward account for native mouse/keyboard testing.

Inputs must be delivered through the native UI. This tool observes process,
runtime and save evidence; it never plays a battle or grants progression.
"""
import argparse
import json
import re
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from run_packaged_qa import ROOT, BUILD, APP, EXE, PACK, app_processes, digest, native_libraries


def hashes(paths):
    return {str(p): digest(p) if p.exists() else None for p in paths}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--name', required=True)
    parser.add_argument('--mission', default='1')
    parser.add_argument('--seconds', type=int, default=1800)
    parser.add_argument('--loading', action='store_true', help='Include the original scene transitions and local loading hold.')
    parser.add_argument('--scope', choices=('tutorial','interface','upgrades','hud'), default='tutorial', help='Tutorial requires an earned win/return; interface requires pause/resume and bounded world zoom; upgrades requires selection/scrolling; HUD requires an actual poor-budget tower selection and flash expiry.')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z][a-z0-9-]{1,70}', args.name):
        parser.error('Use a short lowercase name with letters, numbers and hyphens.')
    if not args.mission.isdecimal() or not 60 <= args.seconds <= 3600:
        parser.error('Choose a numbered mission and a60..3600 second limit.')
    if app_processes():
        parser.error('A game/engine instance is already running. Nothing was launched.')
    destination = BUILD / args.name
    destination.mkdir(exist_ok=False)
    user = Path.home() / 'Library/Application Support/Godot/app_userdata/Spice Bandits Remastered'
    profiles = [user / n for n in ('profile.json', 'profile.json.bak',
                'qa-progress/profile.json', 'qa-progress/profile.json.bak',
                'verification/fresh-campaign-profile.json', 'verification/fresh-campaign-profile.json.bak')]
    resources = [PACK, EXE] + list((APP / 'Contents/Frameworks').glob('*.dylib'))
    protected = resources + profiles
    before = hashes(protected)
    for index, path in enumerate(profiles):
        if path.exists(): (destination / f'before-{index}-{path.name}').write_bytes(path.read_bytes())
    command = [str(EXE), '--', '--qa', '--qa-input-rewards', '--qa-fresh-profile',
               '--qa-live-runtime', '--qa-guidance', '--mission=' + args.mission,
               '--qa-state-file=' + str(destination / 'runtime.json'),
               '--capture=' + str(destination / 'opening.png')]
    if args.loading:command.append('--qa-loading')
    audit = {'started_utc': datetime.now(timezone.utc).isoformat(), 'arguments': command,
             'pck_sha256': digest(PACK), 'executable_sha256': digest(EXE),
             'native_libraries_sha256': native_libraries(), 'protected_before': before,
             'timeout_seconds': args.seconds, 'process_observations': [],
             'method': __doc__, 'input_scope':args.scope}
    observations = []; observed_processes = set(); last_identity = None; state = {}
    with (destination / 'packaged.log').open('w') as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        audit['pid'] = process.pid
        print(json.dumps({'pid': process.pid, 'directory': str(destination)}), flush=True)
        deadline = time.monotonic() + args.seconds
        while process.poll() is None:
            for row in app_processes():
                identity = (row['pid'], row['command'])
                if identity not in observed_processes:
                    observed_processes.add(identity); audit['process_observations'].append(row)
            runtime = destination / 'runtime.json'
            if runtime.exists():
                try: state = json.loads(runtime.read_text())
                except json.JSONDecodeError: pass  # The game can be mid-write.
                identity = json.dumps({k: state.get(k) for k in ('screen', 'paused', 'tutorial_step',
                         'tutorial_display_page', 'tutorial_transition_pending', 'wave_index',
                         'tower_forms', 'money', 'kills', 'ability_stock', 'mines', 'outcome', 'saved_xp', 'loading_kind', 'world_camera', 'world_zoom','selected_upgrade','upgrade_scroll_y','upgrade_detail_keys','hud_money_flash_active','hud_money_flash_age_ms')}, sort_keys=True)
                if identity != last_identity:
                    observations.append({'observed_utc': datetime.now(timezone.utc).isoformat(), 'state': state})
                    (destination / 'observations.json').write_text(json.dumps(observations, indent=2) + '\n')
                    last_identity = identity
            if time.monotonic() >= deadline:
                audit['timeout'] = True; process.kill(); process.wait(); break
            time.sleep(0.5)
        audit['exit_code'] = process.returncode
    audit['protected_after'] = hashes(protected)
    audit['protected_unchanged'] = before == audit['protected_after']
    audit['other_processes'] = [p for p in audit['process_observations'] if p['pid'] != process.pid]
    audit['signature_verified'] = subprocess.run(['codesign', '--verify', '--deep', '--strict', str(APP)], capture_output=True).returncode == 0
    audit['errors'] = re.findall(r'^.*(?:SCRIPT ERROR|^ERROR:|ObjectDB instances were leaked|Leaked instance).*$', (destination / 'packaged.log').read_text(), re.M)
    audit['runtime_isolated'] = bool(observations) and all(o['state'].get('qa_persist_progress') and
                                    o['state'].get('profile_path', '').startswith('user://verification/native-input/') for o in observations)
    audit['environment_passed'] = audit['exit_code'] == 0 and audit['protected_unchanged'] and audit['runtime_isolated'] and not audit['other_processes'] and audit['signature_verified'] and not audit['errors']
    audit['gameplay_reached_victory'] = any(o['state'].get('outcome') == 'victory' for o in observations)
    audit['returned_to_world'] = any(o['state'].get('screen') == 'world' and o['state'].get('outcome') == 'victory' for o in observations)
    audit['input_complete'] = audit['gameplay_reached_victory'] and audit['returned_to_world']
    if args.scope=='interface':
        pause=next((i for i,o in enumerate(observations) if o['state'].get('screen')=='game' and o['state'].get('paused')),None)
        resumed=pause is not None and any(o['state'].get('screen')=='game' and not o['state'].get('paused') for o in observations[pause+1:])
        bounded=any(o['state'].get('screen')=='world' and o['state'].get('world_zoom')==0.25 and o['state'].get('world_camera')==[2048,1536] for o in observations)
        audit['interface_paused_then_resumed']=resumed
        audit['interface_minimum_zoom_bounded']=bounded
        audit['input_complete']=resumed and bounded
    elif args.scope=='upgrades':
        menu=[o['state'] for o in observations if o['state'].get('screen')=='upgrades']
        selections={s.get('selected_upgrade') for s in menu}
        bottom=next((i for i,s in enumerate(menu) if s.get('selected_upgrade')=='up_top' and s.get('upgrade_scroll_y')==40),None)
        restored=bottom is not None and any(s.get('selected_upgrade')=='up_range' and s.get('upgrade_scroll_y')==0 for s in menu[bottom+1:])
        dismissed=any(s.get('selected_upgrade')=='' and not s.get('upgrade_detail_keys') for s in menu)
        audit['upgrade_native_selections']=sorted(selections)
        audit['upgrade_bottom_then_top_scrolled']=restored
        audit['upgrade_detail_dismissed']=dismissed
        audit['input_complete']={'up_range','up_wizard','up_top'}.issubset(selections) and restored and dismissed
    elif args.scope=='hud':
        flash=next((i for i,o in enumerate(observations) if o['state'].get('screen')=='game' and o['state'].get('hud_money_flash_active') and 0<=o['state'].get('money',1000)<20 and o['state'].get('towers',0)>0),None)
        expired=flash is not None and any(o['state'].get('screen')=='game' and not o['state'].get('hud_money_flash_active') and o['state'].get('hud_money_flash_age_ms')==0 for o in observations[flash+1:])
        audit['hud_native_poor_budget_flash']=flash is not None
        audit['hud_native_flash_expired']=expired
        audit['input_complete']=expired
    audit['passed'] = audit['environment_passed'] and audit['input_complete']
    profile = user / str(state.get('profile_path', '')).removeprefix('user://')
    if profile.is_file() and state.get('profile_path', '').startswith('user://verification/native-input/'):
        (destination / 'earned-profile.json').write_bytes(profile.read_bytes())
        audit['earned_profile_sha256'] = digest(profile)
    audit['ended_utc'] = datetime.now(timezone.utc).isoformat()
    (destination / 'audit.json').write_text(json.dumps(audit, indent=2) + '\n')
    print(json.dumps({k: audit[k] for k in ('exit_code', 'protected_unchanged', 'environment_passed', 'input_complete', 'passed')}), flush=True)
    raise SystemExit(0 if audit['passed'] else 1)


if __name__ == '__main__':
    main()
