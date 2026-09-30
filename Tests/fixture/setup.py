"""Build/start or stop only the two disposable PinTop laboratory applications."""
import json
import os
from pathlib import Path
import plistlib
import signal
import subprocess
import sys

root = Path("/tmp/pintop-no-sip-lab")
root.mkdir(exist_ok=True)
source = Path(__file__).with_name("Fixture.m")

def executable(label):
    return root / f"PinTop-Lab-{label}.app/Contents/MacOS/fixture"

def running_pid(label):
    state_file = root / f"{label}.json"
    if not state_file.exists():
        return None
    pid = json.loads(state_file.read_text())["pid"]
    result = subprocess.run(["ps", "-p", str(pid), "-o", "comm="], capture_output=True, text=True)
    return pid if result.stdout.strip() == str(executable(label)) else None

if "--stop" in sys.argv:
    for label in ("A", "B"):
        pid = running_pid(label)
        if pid:
            os.kill(pid, signal.SIGKILL)
            print(f"Stopped disposable fixture {label}, pid={pid}")
    sys.exit(0)

if any(running_pid(label) for label in ("A", "B")):
    sys.exit("Fixtures are already running. Finish probe cleanup, then use --stop before rebuilding.")

binary = root / "fixture-built"
subprocess.run(["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
                "-Wno-deprecated-declarations", "-framework", "AppKit", str(source), "-o", str(binary)], check=True)
for label in ("A", "B"):
    target = executable(label)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(binary.read_bytes())
    target.chmod(0o755)
    info = {"CFBundleIdentifier": f"local.pintop.lab.{label.lower()}", "CFBundleName": f"PinTop-Lab-{label}",
            "CFBundleExecutable": "fixture", "CFBundlePackageType": "APPL", "NSPrincipalClass": "NSApplication"}
    target.parent.parent.joinpath("Info.plist").write_bytes(plistlib.dumps(info))
    subprocess.run(["codesign", "--force", "--sign", "-", str(target.parent.parent.parent)], check=True)
    with root.joinpath(f"{label}.stderr").open("ab") as output:
        process = subprocess.Popen([str(target), label], stdout=output, stderr=output, start_new_session=True)
    print(f"Started disposable fixture {label}, pid={process.pid}")
