"""Check that the distributable APK contains the final kernel and approved art."""
import hashlib
import json
import zipfile
from pathlib import Path

def digest(stream):
    h = hashlib.sha256()
    while chunk := stream.read(1048576):
        h.update(chunk)
    return h.hexdigest()

apk = Path('dist/fix-my-broken-car-tyre-preview-v4.apk')
with zipfile.ZipFile(apk) as archive:
    artwork = {}
    for path in Path('assets/images/story_scenes').glob('tyre_v3_*'):
        if path.suffix not in ('.png', '.json'): continue
        with path.open('rb') as local, archive.open('assets/flutter_assets/'+path.as_posix()) as packed:
            artwork[path.name] = digest(local) == digest(packed)
    with archive.open('assets/flutter_assets/kernel_blob.bin') as stream:
        kernel = digest(stream)
    with Path('build/app/intermediates/flutter/debug/flutter_assets/kernel_blob.bin').open('rb') as stream:
        same_kernel = kernel == digest(stream)
with apk.open('rb') as stream:
    apk_hash = digest(stream)
assert all(artwork.values()) and same_kernel
metadata = json.loads(Path('build/app/outputs/apk/debug/output-metadata.json').read_text())
assert metadata['applicationId'] == 'com.socialstories.social_stories.carpreview'
result = dict(apk=str(apk), bytes=apk.stat().st_size, sha256=apk_hash,
    applicationId=metadata['applicationId'], versionName=metadata['elements'][0]['versionName'],
    versionCode=metadata['elements'][0]['versionCode'], packagedArtworkMatchesWorkspace=artwork,
    kernelMatchesBuildOutput=same_kernel, kernelSha256=kernel)
Path('docs/tyre_preview_v4/package-verification.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
