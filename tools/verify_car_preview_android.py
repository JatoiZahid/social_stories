"""Manual-invocation smoke test for the installed preview on a test emulator.

Uses Android accessibility labels and real touch/drag input. No fixture routes,
state injection, or production app data are used. Start the preview at its intro
with a 1366x1024 / 160dpi emulator display before invoking this script.
"""
import os
from pathlib import Path
import subprocess
import time
import xml.etree.ElementTree as ET

ADB = str(Path(os.environ['LOCALAPPDATA']) / 'Android/sdk/platform-tools/adb.exe')
SERIAL = os.environ.get('CAR_PREVIEW_DEVICE', 'emulator-5554')
OUT = Path(__file__).resolve().parents[1] / 'docs/car_preview/v2'

def adb(*args):
    return subprocess.check_output([ADB, '-s', SERIAL, *args], text=True, encoding='utf-8', errors='replace', stderr=subprocess.STDOUT)

def nodes():
    adb('shell', 'uiautomator', 'dump', '/sdcard/car-preview-ui.xml')
    return ET.fromstring(adb('shell', 'cat', '/sdcard/car-preview-ui.xml')).iter('node')

def locate(label, snapshot):
    for node in snapshot:
        if node.attrib.get('content-desc', '').split('\n')[0] == label or node.attrib.get('text') == label:
            values = node.attrib['bounds'].replace('][', ',').strip('[]').split(',')
            x1, y1, x2, y2 = map(int, values)
            return (x1 + x2) // 2, (y1 + y2) // 2
    return None

def center(label):
    for attempt in range(4):
        result = locate(label, list(nodes()))
        if result is not None:
            return result
        adb('shell', 'input', 'swipe', '115', '900', '115', '510', '500')
    raise AssertionError(f'Visible accessibility target missing: {label}')

def tap(label):
    x, y = center(label)
    adb('shell', 'input', 'tap', str(x), str(y))
    time.sleep(.25)
    print(f'Tap: {label}', flush=True)

def drag(part, target):
    snapshot = list(nodes())
    source = locate('Select ' + part, snapshot)
    destination = locate('Place ' + target + ' here', snapshot)
    if source is None or destination is None:
        raise AssertionError(f'Drag targets missing: {part} -> {target}')
    x1, y1 = source
    x2, y2 = destination
    adb('shell', 'input', 'swipe', str(x1), str(y1), str(x2), str(y2), '800')
    time.sleep(.3)
    print(f'Drag: {part} -> {target}', flush=True)

def capture(name):
    adb('shell', 'screencap', '-p', '/sdcard/car-preview-capture.png')
    adb('pull', '/sdcard/car-preview-capture.png', str(OUT / ('native-' + name + '-landscape.png')))

if __name__ == '__main__':
    tap('Let’s play')
    capture('mud-before')
    x, y = center('Wipe muddy paintwork')
    adb('shell', 'input', 'swipe', str(x - 190), str(y), str(x + 190), str(y), '900')
    adb('shell', 'input', 'swipe', str(x - 190), str(y + 30), str(x + 190), str(y + 30), '900')
    capture('mud-after')
    tap('Close garage')
    capture('door-closed')
    tap('Open garage')
    tap('Spin wheel')
    tap('Open toolbox')
    tap('Lights on')
    capture('exploration')
    tap('Next')
    tap('Look at wheel')
    tap('Open toolbox')
    capture('wheel')
    drag('Small wheel', 'wheel')
    drag('Large wheel', 'wheel')
    capture('pump-before')
    x, y = center('Pump tyre')
    for i in range(3):
        adb('shell', 'input', 'swipe', str(x - 10), str(y - 65), str(x - 10), str(y + 55), '800')
        print(f'Pump handle stroke {i + 1}', flush=True)
    capture('pump-after')
    tap('Next')
    tap('Open bonnet')
    capture('engine')
    drag('Triangle', 'gear')
    drag('Yellow gear', 'gear')
    tap('Next')
    drag('Wrench', 'wrench')
    capture('wrench')
    for i in range(4):
        result = locate('Rotate wrench clockwise', list(nodes()))
        if result is None:
            break
        x, y = result
        adb('shell', 'input', 'swipe', str(x + 55), str(y), str(x), str(y + 55), '900')
        print('Clockwise wrench gesture', flush=True)
    capture('wrench-turned')
    tap('Next')
    capture('power')
    drag('Moon square', 'sun')
    drag('Sun triangle', 'sun')
    drag('Moon square', 'moon')
    tap('Power')
    tap('Next')
    tap('Start')
    capture('drive')
    # Keep the drive demonstration separate from the longer repair walkthrough.
    try:
        adb('shell', 'pkill', '-INT', 'screenrecord')
    except subprocess.CalledProcessError:
        pass  # The repair recording may already have reached its time limit.
    drive_recording = subprocess.Popen([ADB, '-s', SERIAL, 'shell', 'screenrecord', '--bit-rate', '2000000', '--size', '1024x768', '--time-limit', '40', '/sdcard/car-preview-drive-v2.mp4'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # Locate before Go, so accessibility queries do not consume the drive.
    snapshot = list(nodes())
    up = locate('Steer up', snapshot)
    down = locate('Steer down', snapshot)
    middle = locate('Middle', snapshot)
    assert up and down and middle
    adb('shell', 'input', 'tap', str(up[0]), str(up[1]))
    tap('Go')
    time.sleep(1.9)
    adb('shell', 'input', 'tap', str(down[0]), str(down[1]))
    time.sleep(1.7)
    adb('shell', 'input', 'tap', str(middle[0]), str(middle[1]))
    time.sleep(3)
    tap('Stop')
    capture('drive-finished')
    tap('Next')
    capture('celebration')
    assert any('8 of 8' in node.attrib.get('content-desc', '') for node in nodes())
    print('PASS: all five missions completed through native input.', flush=True)
    adb('shell', 'pkill', '-INT', 'screenrecord')
    drive_recording.wait(timeout=15)
