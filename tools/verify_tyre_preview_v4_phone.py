"""Real portrait Android checks after completing the tablet repair."""
import re
import time
import verify_tyre_preview_v4_android as preview
d = preview.device

def capture(name):
    d.adb('shell','screencap','-p','/sdcard/tyre-phone.png')
    d.adb('pull','/sdcard/tyre-phone.png',str(d.OUT/f'native-{name}.png'))

def ready(label):
    for _ in range(12):
        nodes = list(d.nodes())
        if d.locate(label,nodes): return nodes
        time.sleep(.5)
    raise AssertionError('Phone target missing: '+label)

def tap(label,nodes):
    x,y=d.locate(label,nodes)
    d.adb('shell','input','tap',str(x),str(y))
    time.sleep(.5)

nodes=ready('Enter garage')
tap('Enter garage',nodes)
nodes=ready('Play again')
if d.locate('Resume',nodes):
    tap('Resume',list(reversed(nodes)))
    nodes=ready('Pause')
capture('completion-portrait')
tap('Play again',nodes)
nodes=ready('Inspect damaged tyre')
capture('garage-portrait')
tap('Inspect damaged tyre',nodes)
nodes=ready('Place jack under car')
source=d.locate('Select jack',nodes);target=d.locate('Place jack under car',nodes)
d.adb('shell','input','swipe',str(source[0]),str(source[1]),str(target[0]),str(target[1]),'1100')
nodes=ready('Select wrench')
capture('repair-portrait')
source=d.locate('Select wrench',nodes);target=d.locate('Place wrench on nut 3',nodes)
d.adb('shell','input','swipe',str(source[0]),str(source[1]),str(target[0]),str(target[1]),'1100')
nodes=ready('Rotate attached wrench')
x,y=d.locate('Rotate attached wrench',nodes)
ring=next(n for n in nodes if n.attrib.get('content-desc','').split('\n')[0]=='Rotate attached wrench')
x1,y1,x2,y2=map(int,re.findall(r'\d+',ring.attrib['bounds']))
radius=int((x2-x1)*.33)
d.adb('shell','input','swipe',str(x+radius),str(y),str(x),str(y-radius),'1100')
nodes=ready('Place wrench on nut 1')
assert not d.locate('Place wrench on nut 3',nodes)
capture('nut-portrait')
print('PASS: native portrait scene, preserved completed session, replay, jack drag/lift and deliberate nut-three drag/turn at phone density.',flush=True)
