"""Run the real local plugin workflow in an isolated, guarded Herdr lab."""
import json, os, subprocess, time, sys
from pathlib import Path
root = Path.cwd()
evidence = Path(__file__).parent
custom = "--custom" in sys.argv
if custom:
    evidence = evidence / "custom"
    evidence.mkdir(exist_ok=True)
env = dict(os.environ, XDG_CONFIG_HOME='.hc', XDG_STATE_HOME=str(root/'.hc/state'), HERDR_CONFIG_PATH=str(root/'.hc/config.toml'), FM_HERDR_LAB_STATE_DIR=str(root/'.hc/lab'), TMPDIR=str(root/'.hc/tmp'), HISTFILE='/dev/null')
for key in ('HERDR_ENV','HERDR_PANE_ID','HERDR_TAB_ID','HERDR_WORKSPACE_ID','HERDR_SOCKET_PATH','HERDR_SESSION'):
    env.pop(key, None)
if custom:
    env.update(HERDR_CHECKLIST_FILE=str(root/'.hc/custom folder/CHECKLIST.md'), HERDR_CHECKLIST_OWNER='Test Operator')
lab = ['bash', 'bin/fm-herdr-lab.sh']
name = 'fm-lab-checklist'
log = (evidence/'herdr-workflow.txt').open('w')
def run(args, raw=False):
    p = subprocess.run(lab+['run',name]+args, env=env, capture_output=True, text=True, timeout=15)
    log.write('$ herdr '+ ' '.join(args)+'\n'+p.stdout+p.stderr+'\n'); log.flush()
    print('herdr '+' '.join(args[:3])+': '+str(p.returncode), flush=True)
    assert p.returncode == 0, p.stderr
    return p.stdout if raw else json.loads(p.stdout)['result']
def visible(pane, label):
    text=run(['pane','read',pane,'--source','visible','--raw'],raw=True)
    (evidence/(label+'.txt')).write_text(text)
    return text
checklist=Path(env.get('HERDR_CHECKLIST_FILE',str(root/'.hc/state/herdr/plugins/herdr-checklist/CHECKLIST.md')))
checklist.unlink(missing_ok=True)
subprocess.run(lab+['provision',name],env=env,check=True,timeout=70)
try:
    run(['plugin','link',str(root/'herdr-checklist')])
    workspace=run(['workspace','create','--label','Checklist-test','--cwd',str(root),'--no-focus'])
    run(['plugin','action','invoke','herdr-checklist.new'])
    for _ in range(30):
        logs=run(['plugin','log','list','--plugin','herdr-checklist'])
        if 'Created checklist:' in json.dumps(logs): break
        time.sleep(.1)
    assert 'Created checklist:' in json.dumps(logs), logs
    assert checklist.exists(), list((root/'.hc/state').rglob('CHECKLIST.md'))
    starter=checklist.read_bytes()
    (evidence/'created-checklist.md').write_bytes(starter)
    assert (b'CHECKLIST \xe2\x80\x94 Test Operator' if custom else b'CHECKLIST \xe2\x80\x94 you') in starter
    opened=run(['plugin','pane','open','--plugin','herdr-checklist','--entrypoint','checklist','--target-pane',workspace['root_pane']['pane_id'],'--direction','right','--no-focus'])
    (evidence/'pane-open.json').write_text(json.dumps(opened,indent=2)+'\n')
    print(json.dumps(opened),flush=True)
    pane=opened['plugin_pane']['pane']['pane_id']
    assert pane, opened
    time.sleep(1.3)
    initial=visible(pane,'pane-starter')
    assert 'ACT NOW' in initial and 'RECENTLY DONE' in initial
    populated=starter.decode().replace('## 🔴 ACT NOW — only you can do these\n', '## 🔴 ACT NOW — only you can do these\n1. Approve the release plan; unblocks staging.\n   reply-word: "ship"\n').replace('## 🔵 IN FLIGHT — agents working right now\n','## 🔵 IN FLIGHT — agents working right now\n- Update login flow (pane '+workspace['root_pane']['pane_id']+'). Done = passing checks.\n').replace('## 🟡 WAITING — parked on a word or an external event\n','## 🟡 WAITING — parked on a word or an external event\n- Design review: waiting on Morgan.\n').replace('## 🟢 RECENTLY DONE\n','## 🟢 RECENTLY DONE\n- Published the setup guide.\n')
    checklist.write_text(populated)
    time.sleep(1.3)
    filled=visible(pane,'pane-populated')
    assert 'Approve the release plan' in filled and 'reply-word: "ship"' in filled and 'Morgan' in filled
    run(['plugin','action','invoke','herdr-checklist.new'])
    time.sleep(.2)
    assert checklist.read_text()==populated, 'new overwrote existing checklist'
    run(['plugin','log','list','--plugin','herdr-checklist'])
    original_stat=checklist.stat()
    edited=populated.replace('Morgan','Jordan')
    assert len(edited.encode())==len(populated.encode())
    checklist.write_text(edited)
    os.utime(checklist,ns=(original_stat.st_atime_ns,original_stat.st_mtime_ns))
    time.sleep(1.3)
    changed=visible(pane,'pane-refreshed')
    assert 'Jordan' in changed and 'Morgan' not in changed
    checklist.rename(checklist.with_suffix('.away'))
    time.sleep(1.3)
    absent=visible(pane,'pane-during-save')
    assert absent==changed, 'frame changed during failed read'
    checklist.with_suffix('.away').rename(checklist)
    time.sleep(1.3)
    assert visible(pane,'pane-restored')==changed
    checklist.write_text(edited.replace('Jordan','Taylor'))
    time.sleep(1.3)
    final=visible(pane,'pane-final')
    assert 'Taylor' in final and 'Jordan' not in final
    (evidence/'populated-checklist.md').write_bytes(checklist.read_bytes())
    log.write('Observed: local plugin linked; asynchronous action log reports its path; all four sections render in a split pane; new preserves edits; same-length/same-mtime edit refreshes; missing source preserves the current frame; restoration and subsequent edits refresh.\n')
    if custom:
        capture_env=dict(env, PATH=str(root/'.hc/bin')+':'+env['PATH'], CHECKLIST_TUI_CAPTURE=str(root/'.hc/tui.ansi'))
        subprocess.run(lab+['viewer','start',name],env=capture_env,check=True,timeout=20)
        time.sleep(1)
        (evidence/'herdr-terminal.ansi').write_bytes((root/'.hc/tui.ansi').read_bytes())
    print('LIVE WORKFLOW PASSED',flush=True)
finally:
    cleanup=subprocess.run(lab+['teardown',name],env=env,capture_output=True,text=True,timeout=25)
    log.write('$ guarded lab teardown\n'+cleanup.stdout+cleanup.stderr)
    log.close()
    assert cleanup.returncode==0, cleanup.stderr
