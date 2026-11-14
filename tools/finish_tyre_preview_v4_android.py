"""Resume native repair, waiting on observed UI state rather than fixed timing."""
import re
import subprocess
import sys
import time
from pathlib import Path
import xml.etree.ElementTree as ET
import verify_tyre_preview_v4_android as demo
d = demo.device
wrong_tried = False
jack_return_tried = False
recording = None
record_start = None

def swipe(a, b):
    d.adb('shell','input','swipe',str(a[0]),str(a[1]),str(b[0]),str(b[1]),'1100')
    time.sleep(.8)

for attempt in range(64):
    try:
        nodes = list(d.nodes())
    except AssertionError:
        print('Retrying Android accessibility inspection', flush=True)
        continue
    Path('docs/tyre_preview_v4/native-ui.xml').write_text(ET.tostring(nodes[0],encoding='unicode'))
    labels = '\n'.join(n.attrib.get('content-desc','') for n in nodes)
    phase = re.search(r'Repair step (\d) of 8',labels)
    step = int(phase[1]) if phase else None
    locate = lambda name: d.locate(name,nodes)
    print(f'Observed step {step}; attempt {attempt+1}',flush=True)
    if locate('Resume'):
        x,y=d.locate('Resume',list(reversed(nodes)))
        d.adb('shell','input','tap',str(x),str(y))
        print('Explicitly resumed paused repair after Android interruption',flush=True)
        continue
    if locate('Enter garage'):
        x,y=locate('Enter garage')
        d.adb('shell','input','tap',str(x),str(y))
        continue
    if step == 1 and locate('Inspect damaged tyre'):
        if '--record' in sys.argv and recording is None:
            recording = subprocess.Popen([d.ADB,'-s',d.SERIAL,'shell','screenrecord',
                '--bit-rate','3000000','--size','1024x768','--time-limit','180',
                '/sdcard/tyre-v4-clean.mp4'])
            record_start = time.monotonic()
            time.sleep(.5)
        d.capture('garage')
        x,y=locate('Inspect damaged tyre')
        d.adb('shell','input','tap',str(x),str(y))
        print('Inspected flat tyre directly',flush=True)
        continue
    if step == 2 and locate('Place jack under car'):
        jack=locate('Select jack')
        if not jack_return_tried:
            swipe(jack,(jack[0]+140,jack[1]-25))
            jack_return_tried=True
            print('Invalid jack placement returned to toolbox',flush=True)
        else:
            swipe(jack,locate('Place jack under car'))
            print('Jack placed; coordinated lift started',flush=True)
        continue
    if step in (3,6):
        ring = locate('Rotate attached wrench')
        if ring:
            x,y=ring
            swipe((x+60,y),(x,y+(-60 if step==3 else 60)))
            print('Actual turning gesture: '+('left' if step==3 else 'right'),flush=True)
            continue
        wrench = locate('Select wrench')
        target = next((locate(f'Place wrench on nut {i}') for i in range(1,4)
            if locate(f'Place wrench on nut {i}')),None)
        if wrench and target:
            swipe(wrench,target)
            d.capture('wrench-loosen' if step==3 else 'wrench-tighten')
            continue
    if step == 4 and locate('Select damaged'):
        d.capture('three-nuts-removed')
        swipe(locate('Select damaged'),locate('Old wheel tray'))
        print('Old tyre removed after automatic third-nut transition',flush=True)
        continue
    if step == 5 and locate('Place new tyre on hub'):
        d.capture('hub-exposed')
        if not wrong_tried:
            swipe(locate('Select small'),locate('Place new tyre on hub'))
            wrong_tried=True
            d.capture('wrong-wheel-feedback')
            continue
        swipe(locate('Select spare'),locate('Place new tyre on hub'))
        print('Matching tyre installed',flush=True)
        continue
    if step == 7 and locate('Release toy jack'):
        d.capture('tightened-wheel')
        x,y=locate('Release toy jack')
        d.adb('shell','input','tap',str(x),str(y))
        print('Released jack after all three tightened nuts',flush=True)
        continue
    if step == 8:
        assert locate('Play again') and locate('Drive out')
        d.capture('completion')
        x,y=locate('Drive out')
        d.adb('shell','input','tap',str(x),str(y))
        time.sleep(4)
        d.capture('victory-drive')
        if recording is not None:
            try:
                d.adb('shell','pkill','-INT','screenrecord')
            except subprocess.CalledProcessError:
                print('Android recording already reached its time limit',flush=True)
            recording.wait(timeout=15)
            d.adb('pull','/sdcard/tyre-v4-clean.mp4',str(d.OUT/'gameplay-android-final.mp4'))
            print(f'Active native recording: {time.monotonic()-record_start:.1f}s',flush=True)
        print('PASS: native installed v4 repair reached completion through actual drags and both wrench directions; automatic nut-three transition, wrong-size rejection, replacement, tightening, lowering and victory reward exercised.',flush=True)
        break
    if step is None:
        anr = next((n for n in nodes if "isn't responding" in n.attrib.get('text','')),None)
        if anr is not None:
            raise AssertionError('Android OS/app ANR dialog: '+anr.attrib.get('text',''))
        if not labels.strip():
            print('Waiting for first Flutter semantics frame',flush=True)
            time.sleep(1)
            continue
        print('Visible labels: '+labels[:1800],flush=True)
        raise AssertionError('No observed repair phase')
    time.sleep(1)
else:
    raise AssertionError('Native repair did not finish within observed-state attempts')
