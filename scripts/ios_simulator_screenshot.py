"""Capture a real iPhone simulator screen; never resize Android screenshots."""
import json
from pathlib import Path
import subprocess
import time


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def main():
    devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))['devices']
    candidates = [d for runtime, items in devices.items() if 'iOS' in runtime
                  for d in items if d.get('isAvailable') and d['name'].startswith('iPhone')]
    # Prefer known 6.1/6.3-inch Dynamic Island displays when installed.
    preferred = ['iPhone 16 Pro', 'iPhone 15 Pro', 'iPhone 15', 'iPhone 14 Pro']
    candidates.sort(key=lambda d: preferred.index(d['name']) if d['name'] in preferred else 100)
    if not candidates:
        raise RuntimeError('No available iPhone simulator runtime on this build machine.')
    device = candidates[0]
    udid = device['udid']
    if device['state'] != 'Booted':
        run('xcrun', 'simctl', 'boot', udid)
    run('xcrun', 'simctl', 'bootstatus', udid, '-b')
    run('xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41',
        '--batteryState', 'charged', '--batteryLevel', '100')
    run('xcrun', 'simctl', 'install', udid, 'build/ios/iphonesimulator/Runner.app')
    run('xcrun', 'simctl', 'launch', udid, 'com.vadesi.vadesi')
    time.sleep(12)
    output = Path('build/ios-screenshots')
    output.mkdir(parents=True, exist_ok=True)
    run('xcrun', 'simctl', 'io', udid, 'screenshot', str(output / '01-welcome.png'))
    (output / 'device.json').write_text(json.dumps(device, indent=2))
    print('Captured actual iOS screen. Review image and dimensions before uploading:', device['name'])


if __name__ == '__main__':
    main()
