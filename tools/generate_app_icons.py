"""Resize the approved generated mascot into Android and iOS launcher assets.

Requires Pillow. Run: python tools/generate_app_icons.py
The source PNG and generation prompt are retained in assets/branding/.
"""
import json
import math
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BACKGROUND = '#BD94EF'
BRANDING = ROOT / 'assets/branding'


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8')


def main():
    source = Image.open(BRANDING / 'app_icon_elephant_foreground.png').convert('RGBA')
    bounds = source.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    if bounds is None:
        raise ValueError('Mascot artwork is empty')
    art = source.crop(bounds)
    approved = Image.open(BRANDING / 'previews/elephant.png').convert('RGB')

    def compose(size, adaptive=False, monochrome=False):
        if not adaptive:
            return approved.resize((size, size), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0) if adaptive else BACKGROUND)
        # The bounding rectangle diagonal fits inside the adaptive safe circle.
        ratio = size * 0.60 / math.hypot(*art.size) if adaptive else size * 0.83 / max(art.size)
        resized = art.resize((round(art.width*ratio), round(art.height*ratio)), Image.Resampling.LANCZOS)
        if monochrome:
            mask = resized.getchannel('A')
            resized = Image.new('RGBA', resized.size, 'white')
            resized.putalpha(mask)
        canvas.alpha_composite(resized, ((size-resized.width)//2, (size-resized.height)//2))
        return canvas if adaptive else canvas.convert('RGB')

    compose(1024).save(BRANDING / 'app_icon.png')
    res = ROOT / 'android/app/src/main/res'
    for density, factor in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
        folder = res / f'mipmap-{density}'
        compose(round(48*factor)).save(folder / 'ic_launcher.png')
        compose(round(108*factor), adaptive=True).save(folder / 'ic_launcher_foreground.png')
        compose(round(108*factor), adaptive=True, monochrome=True).save(folder / 'ic_launcher_monochrome.png')
    for name in ['foreground', 'monochrome']:
        write(res / f'drawable/ic_launcher_{name}.xml',
              '<bitmap xmlns:android="http://schemas.android.com/apk/res/android" '
              f'android:src="@mipmap/ic_launcher_{name}" android:gravity="fill" />\n')
    write(res / 'values/ic_launcher_colors.xml',
          f'<resources><color name="ic_launcher_background">{BACKGROUND}</color></resources>\n')
    for version in (26, 33):
        mono = '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n' if version == 33 else ''
        write(res / f'mipmap-anydpi-v{version}/ic_launcher.xml',
              '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
              '    <background android:drawable="@color/ic_launcher_background" />\n'
              '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
              f'{mono}</adaptive-icon>\n')
    folder = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for item in json.loads((folder / 'Contents.json').read_text(encoding='utf-8'))['images']:
        size = round(float(item['size'].split('x')[0])*float(item['scale'][:-1]))
        compose(size).save(folder / item['filename'])
    print('Updated Android legacy/adaptive/themed icons and every iOS icon slot.')


if __name__ == '__main__':
    main()
