"""Run or stop a disposable third AppKit window for PinTop regression checks."""
from pathlib import Path
import os
import plistlib
import signal
import subprocess
import sys
import json

root = Path('/tmp/pintop-no-sip-lab')
app = root / 'PinTop-Lab-C.app'
exe = app / 'Contents/MacOS/fixture'
state = root / 'C.json'
if '--stop' in sys.argv:
    if state.exists():
        pid = json.loads(state.read_text())['pid']
        try:
            os.kill(pid, signal.SIGKILL)
            print(f'Stopped C fixture pid={pid}')
        except ProcessLookupError:
            pass
    sys.exit(0)

if state.exists():
    pid = json.loads(state.read_text())['pid']
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        pass
    else:
        sys.exit(f'C fixture is already running, pid={pid}')

source = Path(__file__).resolve().parent / 'fixture/Fixture.m'
exe.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
                '-Wno-deprecated-declarations', '-framework', 'AppKit',
                str(source), '-o', str(exe)], check=True)
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'local.pintop.lab.c', 'CFBundleName': 'PinTop-Lab-C',
    'CFBundleExecutable': 'fixture', 'CFBundlePackageType': 'APPL',
    'NSPrincipalClass': 'NSApplication'}))
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
with (root / 'C.stderr').open('ab') as output:
    process = subprocess.Popen([str(exe), 'C'], stdout=output, stderr=output,
                               start_new_session=True)
print(f'Started C fixture pid={process.pid}')
