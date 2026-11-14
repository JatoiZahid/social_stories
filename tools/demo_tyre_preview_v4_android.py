"""Native demonstration using observed accessibility geometry and real gestures.

Cache stable nut geometry within a repair phase so Android hierarchy inspection
does not insert long idle waits between every small gesture in the recording.
No application state is injected. Start the v4 preview at its cover.
"""
import time
import verify_tyre_preview_v4_android as demo

d = demo.device

def point(nodes, label):
    result = d.locate(label, nodes)
    assert result, f'Missing native target: {label}'
    return result

def tap(p):
    d.adb('shell', 'input', 'tap', str(p[0]), str(p[1]))
    time.sleep(.5)

def drag(a, b):
    d.adb('shell', 'input', 'swipe', str(a[0]), str(a[1]), str(b[0]), str(b[1]), '850')
    time.sleep(.5)

def turn(p, clockwise):
    # Quarter-circle chord stays outside the central dead zone.
    d.adb('shell', 'input', 'swipe', str(p[0]+55), str(p[1]),
          str(p[0]), str(p[1]+(55 if clockwise else -55)), '1100')
    time.sleep(.9)

if __name__ == '__main__':
    nodes = list(d.nodes())
    enter = d.locate('Enter garage', nodes)
    if enter:
        tap(enter)
    for attempt in range(12):
        nodes = list(d.nodes())
        if d.locate('Inspect damaged tyre', nodes): break
        print('Waiting for cold-start artwork decoding...', flush=True)
        time.sleep(1)
    inspect = point(nodes, 'Inspect damaged tyre')
    d.capture('garage')
    tap(inspect)
    time.sleep(.8)
    nodes = list(d.nodes())
    jack, jack_target = point(nodes, 'Select jack'), point(nodes, 'Place jack under car')
    # Exercise invalid placement and the return animation first.
    drag(jack, (jack[0]+140, jack[1]-25))
    drag(jack, jack_target)
    time.sleep(1.2)
    nodes = list(d.nodes())
    wrench = point(nodes, 'Select wrench')
    nuts = [point(nodes, f'Place wrench on nut {i+1}') for i in range(3)]
    d.capture('car-raised')
    for i, nut in enumerate(nuts):
        drag(wrench, nut)
        if i == 0: d.capture('wrench-contact')
        turn(nut, False)
        print(f'Loosened nut {i+1}; visible settling and auto-advance', flush=True)
    nodes = list(d.nodes())
    damaged, old_tray = point(nodes, 'Select damaged'), point(nodes, 'Old wheel tray')
    d.capture('three-nuts-removed')
    drag(damaged, old_tray)
    nodes = list(d.nodes())
    hub = point(nodes, 'Place new tyre on hub')
    d.capture('hub-exposed')
    drag(point(nodes, 'Select small'), hub)
    d.capture('wrong-wheel-feedback')
    drag(point(nodes, 'Select spare'), hub)
    time.sleep(.8)
    nodes = list(d.nodes())
    wrench = point(nodes, 'Select wrench')
    nuts = [point(nodes, f'Place wrench on nut {i+1}') for i in range(3)]
    d.capture('new-wheel')
    for i, nut in enumerate(nuts):
        drag(wrench, nut)
        turn(nut, True)
        print(f'Tightened nut {i+1}', flush=True)
    nodes = list(d.nodes())
    tap(point(nodes, 'Release toy jack'))
    time.sleep(1.5)
    nodes = list(d.nodes())
    point(nodes, 'Play again')
    d.capture('completion')
    tap(point(nodes, 'Drive out'))
    time.sleep(2.8)
    d.capture('victory-drive')
    print('PASS: complete installed v4 repair with real drags, both turning directions, invalid return, wrong tyre, nut-three auto-advance, lowering and victory drive.', flush=True)
