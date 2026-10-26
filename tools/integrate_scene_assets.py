"""Integrate only visually reviewed original-character action strips.

Run after tools/generate_scene_manifest.py. By default all audited scenes must
be ready. --check verifies mappings without writing story data. --allow-partial
is for development and never marks missing scenes complete.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
ANIMATION_KEYS = ('columns', 'rows', 'row', 'frameCount', 'fps', 'posterFrame', 'cue', 'description', 'loop', 'frameCues')


def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--allow-partial', action='store_true')
    args = parser.parse_args()
    baseline = read('docs/story_assets_baseline.json')
    inventory = read('docs/scene_asset_inventory.json')
    manifest = read('docs/generated_scene_assets.json')
    phase_cues = read('docs/scene_frame_cues.json')['scenes']
    data = read('assets/data/stories.json')
    scenes = {s['scene_id']: s for s in inventory['scenes']}
    reviewed = {s['scene_id']: s for s in manifest['scenes'] if s.get('qa_status') == 'reviewed_ready'}
    unknown = reviewed.keys() - scenes.keys()
    if unknown:
        raise ValueError(f'Unknown scene IDs: {unknown}')
    missing = scenes.keys() - reviewed.keys()
    if missing and not args.allow_partial:
        raise ValueError(f'{len(missing)} scenes still need reviewed action artwork: {sorted(missing)}')
    for asset in baseline['assets']:
        assert hashlib.sha256((ROOT / asset['path']).read_bytes()).hexdigest() == asset['sha256'], asset['path']
    report = []
    for story in data['stories']:
        original = next(s for s in baseline['stories'] if s['id'] == story['id'])
        assert story.get('questions', []) == original.get('questions', []), 'Questions must be preserved'
        assert len(story['pages']) == len(original['pages']), story['id']
        for index, page in enumerate(story['pages']):
            scene_id = f"{story['id']}-p{index + 1}"
            source = reviewed.get(scene_id)
            assert page['lead'] == original['pages'][index]['lead'] and page['body'] == original['pages'][index]['body'], scene_id
            if source is None:
                continue
            atlas_path = ROOT / source['atlas']
            poster_path = ROOT / source['poster']
            for path in (atlas_path, poster_path):
                assert path.resolve().is_relative_to(ROOT.resolve()) and path.is_file(), path
            for key, path in (('atlas_sha256', atlas_path), ('poster_sha256', poster_path)):
                assert source[key] == hashlib.sha256(path.read_bytes()).hexdigest(), path
            with Image.open(atlas_path) as atlas, Image.open(poster_path) as poster:
                assert atlas.width % source['columns'] == 0 and atlas.height % source['rows'] == 0, scene_id
                width, height = atlas.width // source['columns'], atlas.height // source['rows']
                assert width >= 640 and height >= 480, f'{scene_id}: frame below review resolution floor'
                assert source['frameCount'] >= 2, f'{scene_id}: a static image is not action animation'
                frame0 = atlas.crop((0, 0, width, height)).convert('RGB')
                frame1 = atlas.crop((width, 0, 2 * width, height)).convert('RGB')
                assert ImageChops.difference(frame0, frame1).getbbox(), f'{scene_id}: duplicate frames'
                left = source['posterFrame'] * width
                top = source['row'] * height
                expected = atlas.crop((left, top, left + width, top + height)).convert('RGB')
                assert poster.size == (width, height) and ImageChops.difference(expected, poster.convert('RGB')).getbbox() is None, scene_id
            animation = {'asset': source['atlas'], **{k: source[k] for k in ANIMATION_KEYS if k in source}}
            if scene_id in phase_cues:
                animation['frameCues'] = phase_cues[scene_id]
                assert not animation['loop'] and len(animation['frameCues']) == animation['frameCount'], scene_id
                offsets = [scenes[scene_id]['narration'].find(phrase) for phrase in animation['frameCues']]
                assert offsets[0] >= 0 and offsets == sorted(set(offsets)), scene_id
            assert not animation.get('cue') or animation['cue'] in scenes[scene_id]['narration'], scene_id
            if args.check:
                assert page['image'] == source['poster'] and page.get('animation') == animation and 'focus' not in page, scene_id
            else:
                page['id'] = page.get('id', scene_id)
                page['image'] = source['poster']
                page['animation'] = animation
                page.pop('focus', None)
            report.append({'scene_id': scene_id, 'frame_width': width, 'frame_height': height,
                           'frame_count': source['frameCount'], 'review': source['qa_status'], 'qa_notes': source.get('qa_notes', ''),
                           'device_tts_verified': False, 'physical_tablet_verified': False})
    if not args.check:
        (ROOT / 'assets/data/stories.json').write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    verification = {'originals_unchanged': True, 'story_text_and_questions_preserved': True,
                    'reviewed_integrated_scenes': len(report), 'total_scenes': len(scenes),
                    'missing_scene_ids': sorted(missing), 'scenes': report,
                    'limits': 'Limited illustrated key-pose animation. Native exports are recorded per scene; no 4K, full skeletal animation or physical-device QA claim.'}
    (ROOT / 'docs/scene_asset_verification.json').write_text(json.dumps(verification, indent=2) + '\n', encoding='utf-8')
    print(f"{'Verified' if args.check else 'Integrated'} {len(report)}/{len(scenes)} scenes; original art/text/questions preserved.")


if __name__ == '__main__':
    main()
