"""Run or stop a disposable two-window single-process regression fixture."""
from pathlib import Path
import json
import os
import plistlib
import signal
import subprocess
import sys

root = Path('/tmp/pintop-no-sip-lab')
state = root / 'same.json'
command = root / 'same-command'
app = root / 'PinTop-Lab-Same.app'
exe = app / 'Contents/MacOS/same'
if '--stop' in sys.argv:
    if state.exists():
        try:
            os.kill(json.loads(state.read_text())['pid'], signal.SIGKILL)
        except ProcessLookupError:
            pass
    command.unlink(missing_ok=True)
    sys.exit(0)
if state.exists():
    pid = json.loads(state.read_text())['pid']
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        pass
    else:
        sys.exit(f'Same-app fixture already running, pid={pid}')
command.unlink(missing_ok=True)
exe.parent.mkdir(parents=True, exist_ok=True)
source = Path(__file__).with_name('SameAppFixture.m')
subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
                '-framework', 'AppKit', str(source), '-o', str(exe)], check=True)
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'local.pintop.lab.same', 'CFBundleName': 'PinTop-Lab-Same',
    'CFBundleExecutable': 'same', 'CFBundlePackageType': 'APPL'}))
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
with (root / 'same.stderr').open('ab') as output:
    process = subprocess.Popen([str(exe)], stdout=output, stderr=output,
                               start_new_session=True)
print(f'Started same-app fixture pid={process.pid}')
