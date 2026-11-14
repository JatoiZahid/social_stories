"""Real Android gesture walkthrough of the isolated tyre slice, no state fixtures."""
from pathlib import Path
import time
import xml.etree.ElementTree as ET
import verify_car_preview_android as device

device.OUT = Path(__file__).resolve().parents[1] / 'docs/tyre_preview_v4'

def fresh_nodes():
    # Never reuse an older hierarchy when Android's idle inspection times out.
    for attempt in range(3):
        result = device.adb('shell', 'uiautomator', 'dump', '--compressed', '/sdcard/tyre-preview-ui.xml')
        if 'dumped to:' in result:
            return ET.fromstring(device.adb('shell', 'cat', '/sdcard/tyre-preview-ui.xml')).iter('node')
        time.sleep(.5)
    raise AssertionError('Android accessibility inspection timed out')

device.nodes = fresh_nodes

def drag(tool, target):
    snapshot = list(device.nodes())
    source = device.locate('Select ' + tool, snapshot)
    destination = device.locate(target, snapshot)
    assert source and destination, f'Missing drag target: {tool} -> {target}'
    device.adb('shell', 'input', 'swipe', str(source[0]), str(source[1]), str(destination[0]), str(destination[1]), '900')
    print(f'Drag {tool} -> {target}', flush=True)
    time.sleep(.3)

def turn(clockwise):
    x, y = device.center('Rotate attached wrench')
    device.adb('shell', 'input', 'swipe', str(x + 55), str(y), str(x), str(y + (55 if clockwise else -55)), '950')
    print('Rotate clockwise' if clockwise else 'Rotate anticlockwise', flush=True)
    time.sleep(.8)

if __name__ == '__main__':
    # The single-action cover card merges its text into one accessibility node.
    # At the verified 1366x1024 layout, its observed Enter button is (683,728).
    snapshot = list(device.nodes())
    if not device.locate('Inspect damaged tyre', snapshot):
        if device.locate('Enter garage', snapshot):
            device.tap('Enter garage')
        else:
            assert any('Enter garage' in n.attrib.get('content-desc', '') for n in snapshot)
            device.adb('shell', 'input', 'tap', '683', '728')
            time.sleep(1)
    device.center('Inspect damaged tyre')
    device.capture('garage')
    device.tap('Inspect damaged tyre')
    time.sleep(.8)
    device.capture('jack-target')
    drag('jack', 'Place jack under car')
    time.sleep(1.2)
    device.capture('car-raised')
    for nut in range(1,4):
        drag('wrench', f'Place wrench on nut {nut}')
        if nut == 1: device.capture('loosening-contact')
        turn(False)
        if device.locate('Rotate attached wrench', list(device.nodes())):
            turn(False)
    device.capture('damaged-wheel-ready')
    drag('damaged', 'Old wheel tray')
    device.capture('hub-exposed')
    drag('small', 'Place new tyre on hub')
    drag('spare', 'Place new tyre on hub')
    time.sleep(.7)
    device.capture('new-wheel')
    for nut in range(1,4):
        drag('wrench', f'Place wrench on nut {nut}')
        if nut == 1: device.capture('tightening-contact')
        turn(True)
        if device.locate('Rotate attached wrench', list(device.nodes())):
            turn(True)
    device.capture('ready-to-lower')
    device.tap('Release toy jack')
    time.sleep(1.3)
    device.capture('completion')
    assert device.locate('Play again', list(device.nodes()))
    device.tap('Drive out')
    time.sleep(2.9)
    device.capture('victory-drive')
    print('PASS: complete native tyre repair, both wrench directions, wrong tools, old-wheel removal, replacement and lowering.', flush=True)
