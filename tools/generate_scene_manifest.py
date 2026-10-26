"""Export reviewed imagegen strips as runtime PNG atlases and scene posters.

This is local sprite export only: no API calls, generation, resize or redraw.
Input manifest entries need source_path, scene_id, story_id, page, prompt and
qa_status. Only explicitly reviewed entries may be exported.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs/generated_scene_assets.json"

# Two articulated key poses at ONE fixed location. These deliberately avoid
# asking the generator for a comic with camera/setting changes between frames.
# Full narration and broader requirements remain in scene_asset_inventory.json.
POSES = {
    "going_to_school": [
        ("home entryway", "Boy is fully dressed, finishing button at his shirt collar while grasping blue backpack strap at his side", "Boy slips the blue backpack over his shoulder, arm raised through strap; mother holds door open at same position", False),
        ("same sidewalk toward school", "Boy and mother walk side by side, boy left foot forward and right arm forward", "Same boy right foot forward and left arm forward; mother opposite stride, identical full-body positions and scale", True),
        ("school entrance", "Boy and mother face each other at respectful gap, both lift right palms to say goodbye", "Same two standing in same places with palms tilted the other way in a small wrist wave", True),
        ("classroom doorway", "Distinct teacher wearing teacher lanyard waves with raised right palm; boy raises own palm back", "Teacher and boy tilt raised palms gently the opposite direction, remaining same positions", True),
        ("classroom child-sized desk", "Boy bends knees above chair with hand resting on desk, bottom just above seat", "Same boy settles onto chair, knees bent, both feet at floor, open book on desk while looking at teacher", False),
        ("school gate after school", "Boy with backpack greets mother and takes her hand after pickup", "Both take first walking step toward home beyond gate, boy free hand gestures as he tells mother about day", False),
    ],
    "going_to_the_toilet": [
        ("bathroom doorway with trusted adult nearby", "Boy gestures toward bathroom to tell adult he needs toilet, hand near closed door handle", "Boy turns handle and opens bathroom door slightly as adult nods; no toothbrush", False),
        ("bathroom stall with waist-height privacy partition", "Boy bends knees toward toilet seat behind partition, fully clothed upper body visible and private area completely concealed", "Boy calmly sits on toilet with lower body and lap completely hidden by partition; hands rest safely atop partition; no nudity", False),
        ("bathroom stall with privacy partition", "Boy seated behind partition with lap fully concealed reaches for toilet-paper roll", "Boy tears a small clean length of toilet paper and moves hand behind partition; all private anatomy and wiping contact concealed", False),
        ("bathroom beside toilet", "Fully clothed boy reaches finger toward toilet flush button", "Boy presses flush button with finger as water swirls gently inside toilet bowl", False),
        ("bathroom behind waist-high privacy partition", "Boy stands behind partition, hands gripping waistband visible just above partition, all private anatomy concealed", "Boy pulls waistband into final secure position, shirt tucked neatly; fully clothed throughout", False),
        ("bathroom sink", "Boy rubs soapy palms together directly over sink, faucet stream into bowl", "Boy turns hands and rubs backs of fingers with soap over sink; hands in same location near water", True),
        ("bathroom towel rail beside sink", "Boy presses both wet hands inside yellow towel hanging at his waist", "Boy rubs fingers and backs of hands inside same towel, elbows bend differently", True),
        ("bathroom doorway after finishing", "Fully clothed boy holds clean open hands up to check them, calm face", "Boy lowers clean hands and smiles proudly, faucet off and towel neatly hung behind him", False),
    ],
    "going_to_the_doctor": [
        ("clinic exam-room entry", "Boy with trusted adult steps through clinic doorway toward original doctor", "Boy takes next step and doctor gestures toward exam bench, same camera and room", False),
        ("clinic exam room", "Original woman doctor raises palm hello while boy on exam bench raises own palm", "Doctor and boy tilt their raised palms the other direction to wave, same positions", True),
        ("clinic exam room", "Doctor holds stethoscope chestpiece against boy's blue shirt over chest, boy breathes in gently", "Same chestpiece remains contacting shirt as boy breathes out, doctor listens attentively", True),
        ("clinic exam room", "Doctor uses otoscope at boy's outer ear, boy calm with mouth closed", "Doctor lowers otoscope and looks with small exam light as same boy opens mouth to say ahh; same seated position", False),
        ("clinic exam room", "Boy points to tummy while looking toward doctor with thoughtful expression", "Boy gestures to simple feelings picture card while doctor nods and listens at his level", False),
        ("clinic exam-room doorway", "Boy turns toward doctor and raises palm in grateful goodbye", "Boy lowers hand and takes step toward trusted adult at door, doctor smiles goodbye", False),
    ],
    "brushing_teeth": [
        ("blue bathroom sink", "Boy's hand reaches for yellow toothbrush resting in holder while other hand holds capped toothpaste", "Boy grips yellow toothbrush and raises bristles toward mouth, small pea-sized toothpaste on bristles", False),
        ("blue bathroom sink", "Boy holds yellow toothbrush horizontally, other hand positions toothpaste tube nozzle over bristles", "Boy squeezes tube gently, single tiny pea-sized paste bead rests on bristles with nozzle directly above", False),
        ("blue bathroom sink", "Boy holds toothbrush contacting front teeth, hand and wrist on one side", "Boy angles brush slightly toward back teeth with wrist shifted while bristles remain inside mouth", True),
        ("blue bathroom sink", "Boy brushes teeth with yellow brush, bristles touching left-side teeth and elbow slightly raised", "Boy makes small brushing circle with wrist, bristles touching adjacent teeth and elbow slightly lowered", True),
        ("blue bathroom sink", "Boy leans forward over sink with mouth directed into bowl to discreetly spit paste, brush safely in hand", "Boy remains leaning over same sink and holds brush bristles directly under running faucet to rinse", False),
        ("blue bathroom sink and mirror", "Boy places clean yellow toothbrush into holder, smiling gently at mirror", "Boy hand releases brush into holder, both hands lower and boy shows clean teeth with proud smile", False),
    ],
    "restaurant": [
        ("restaurant table", "Boy bends knees to sit in chair beside original mother, picture menu on table", "Boy seated securely points to food image on menu toward waiter standing beside table", False),
        ("restaurant table", "Boy holds open picture menu with hands, eyes look at food illustrations", "Same boy points index finger directly at one food picture on same menu, mother beside him", False),
        ("restaurant table before food arrives", "Boy holds crayon tip on paper drawing a small circle while mother sits beside him", "Boy bends wrist and moves crayon across same paper adding line, placemat has no served meal yet", True),
        ("restaurant table during meal", "Boy holds fork with small bite just above food plate, mother eating beside him", "Boy bends elbow bringing same fork and bite to mouth, plate and table stay fixed", True),
        ("restaurant table", "Boy gestures please toward waiter holding water glass just above table", "Waiter safely places glass on table and boy nods thank you with hand on chest", False),
        ("restaurant exit near same dining table", "Boy pushes chair back and begins standing beside mother, cleared plate on table", "Boy stands fully and takes mother's hand toward visible exit, same room camera", False),
    ],
    "airport": [
        ("airport check-in area", "Boy in original lime shirt and blue backpack walks beside grown-up toward check-in desk", "Boy takes opposite stride near same desk as staff welcomes them, suitcase held by adult", True),
        ("airport check-in counter", "Boy presents boarding pass to staff while adult lifts large suitcase onto luggage belt", "Staff receives boarding pass and suitcase rests supported on belt, boy hand opens after giving pass", False),
        ("airport security tray counter", "Boy holds small belongings directly over open security tray, friendly staff beside lane", "Boy lowers belongings inside tray with hands contacting objects, staff calmly points toward scanner", False),
        ("airport departure-gate seating", "Boy seated beside adult looks through large window toward parked plane", "Same boy raises hand to point at plane through window and turns slightly toward adult", False),
        ("airplane cabin seat", "Boy sits in plane seat holding two seatbelt ends over lap, blue backpack stowed", "Boy clicks belt ends together across lap, buckle clearly closed and hands around it", False),
        ("airplane cabin during takeoff", "Boy sits securely buckled, mouth slightly open and clouds visible through cabin window", "Same buckled boy yawns with mouth wider and one hand politely near mouth; ground now lower outside window", False),
        ("destination pickup vehicle with arrivals building visible through window", "Boy seated in age-appropriate booster seat, grown-up helps guide vehicle belt across his shoulder and lap", "Grown-up clips buckle securely, boy smiles relieved with bag safely stowed; vehicle still parked", False),
    ],
    "playground": [
        ("playground safe waiting place near slide", "Boy waits behind safe marker with hands calmly down while girl finishes using slide", "Girl stands clear of landing area and boy gestures to ask whether his turn, still waiting safely", False),
        ("playground slide with clear landing area", "Boy sits at top of slide with feet forward and hands safely at sides, girl waits well away", "Same boy slides to lower part seated feet first, arms and bent knees articulated; girl remains waiting", False),
        ("playground open area", "Boy turns to original girl and raises open hand inviting her to play", "Girl nods and raises hand in reply, boy gestures toward play equipment without grabbing", False),
        ("playground swing bay", "Boy securely seated on swing gripping both chains, knees bent and swing gently forward; girl waits far outside swing arc", "Boy grips same chains as swing gently backward, legs extend differently; girl remains in safe waiting place", True),
        ("playground bench", "Original girl sits with sad concerned face and small scraped knee, boy nearby with concerned expression", "Boy raises hand toward trusted adult who kneels beside girl to help gently, same bench and sad-to-reassured emotions", False),
        ("playground gate", "Boy and girl face each other and lift palms goodbye, trusted adult waits beside boy", "Boy tilts wrist in goodbye wave while taking adult's hand, girl waves back", False),
    ],
    "sharing": [
        ("indoor playroom table", "Boy holds original colorful toy near table edge while friend extends hands to receive", "Boy extends toy and friend's hands support it securely, both smile", False),
        ("indoor playroom table", "Friend holds toy close, boy extends open palm without touching toy while asking for turn", "Boy lowers open hand and waits calmly, friend looks up and nods acknowledgment", False),
        ("indoor playroom table", "Boy extends toy while supporting its base, friend's hands reach and touch toy sides", "Friend grips toy securely with both hands and boy releases hands slightly away", False),
        ("indoor playroom table", "Boy places blue block on shared construction, friend holds yellow block ready", "Friend places yellow block beside blue block while boy supports construction and both smile", True),
        ("indoor playroom table", "Friend uses original toy at right, boy calmly picks up separate toy car at left", "Boy moves toy car with fingers on his side of table while friend continues own toy, no grabbing", True),
        ("indoor playroom table", "Both children support shared toy onto middle of table, relaxed happy faces", "Both release toy safely on table and exchange proud gentle smiles", False),
    ],
    "asking_for_help": [
        ("home doorway", "Boy struggles gently with difficult door handle, concerned thoughtful face, trusted adult nearby", "Boy turns toward trusted adult and raises open hand asking for help, adult bends to listen", False),
        ("home table with trusted adult", "Trusted adult points to family picture on simple communication card and boy looks at it", "Adult points to teacher picture on same card, boy nods and points to trusted helper image", False),
        ("home doorway", "Boy stands with right hand at shoulder height, looking toward original trusted adult", "Boy extends same right arm up with open palm asking help calmly, adult turns toward him", False),
        ("home doorway", "Boy points to difficult door handle with one hand, adult follows point", "Boy points to matching help picture on communication card with other hand and adult nods understanding", False),
        ("home doorway", "Adult listens at boy's level with one hand on difficult door handle while child stands clear", "Adult opens door safely and boy places hand on chest nodding thank you", False),
        ("home doorway", "Boy stands beside trusted adult with head slightly lowered after asking help", "Boy lifts head with confident gentle smile and adult nods encouragement with open hand", False),
    ],
    "personal_space": [
        ("indoor hallway", "Boy and girl stand near each other with modest gap, relaxed hands down", "Boy takes small backward step creating clear comfortable arm-length gap, girl remains relaxed", False),
        ("indoor hallway", "Boy starts lifting right arm into empty gap toward girl without touching her", "Boy extends right arm horizontally to check arm-length distance with fingertips still well short of girl", False),
        ("indoor hallway", "Boy asks for hug with open palms at own chest while remaining arm-length apart from girl", "Boy waits with hands lowered as girl considers response, no hug or touching occurs", False),
        ("indoor hallway", "Girl gently indicates no with small head turn, boy listens while staying apart", "Boy accepts with gentle smile and raises palm in friendly wave instead; girl smiles and waves back", False),
        ("indoor hallway", "Boy raises open palm calmly asking for space while girl stands nearby", "Girl takes small backward step, boy lowers palm as comfortable gap opens", False),
        ("indoor hallway", "Boy and girl stand full-body with comfortable gap and relaxed neutral faces", "Both exchange gentle smile and small open-hand wave while maintaining exact same gap", False),
    ],
    "saying_no": [
        ("home indoor room", "Original girl in pink raises open palm toward lollipop offered at respectful distance by adult", "Adult hand withdraws lollipop slightly, girl keeps calm confident stop palm and gentle face", False),
        ("home indoor room", "Original girl in pink gently turns head a little left while raised palm says no kindly", "Same girl turns head a little right, same calm mouth and raised palm; adult keeps offered item at distance", True),
        ("home indoor room", "Original girl in pink offers toy to friend with open hand; friend raises palm to decline", "Girl nods okay and brings toy back toward herself, friend relaxes hand", False),
        ("public indoor space beside trusted adult", "Original girl has serious assertive face and raised firm stop palm toward uncomfortable offscreen interaction", "Girl turns toward nearby trusted adult and gestures to explain, adult bends to listen; no threatening touch", False),
        ("home indoor room", "Original girl raises clear stop palm before another person's approaching hand reaches her, comfortable visible gap", "Other person withdraws hand and steps back, girl relaxes slightly while maintaining personal gap", False),
        ("home indoor room", "Original girl finishes kind no with raised palm toward adult's offer", "Adult nods acceptance and removes offered object, girl lowers palm and gives gentle confident smile", False),
    ],
    "staying_safe": [
        ("sidewalk behind curb at zebra crossing", "Boy holds mother's hand and turns head LEFT checking road; both feet stay on sidewalk behind curb", "Same boy turns head RIGHT checking road while mother stays holding hand; both remain behind curb, cars stopped", True),
        ("wide sidewalk beside busy road", "Boy reaches hand toward mother's hand while both stand fully on sidewalk", "Their hands clasp securely and boy takes small walking step along sidewalk, cars remain entirely in road", False),
        ("sidewalk behind curb at pedestrian crossing", "Boy and mother hold hands waiting with both feet well behind curb; pedestrian signal shows RED standing person", "Same positions, both still behind curb checking road; pedestrian signal changes to GREEN walking person and cars stopped", False),
        ("public shop entrance safe waiting spot", "Boy stands still beside clear shop landmark with worried face, no mother present; uniformed shop worker nearby", "Boy raises open hand asking worker for help, worker comes to boy while boy stays at exact landmark, reassured face", False),
        ("safe shop entrance waiting spot", "Boy shows small family picture card to uniformed shop helper, thoughtful face", "Boy points to mother in picture and gestures name while helper writes note and listens; child remains in same place", False),
        ("safe sidewalk beside shop after reunion", "Mother kneels to boy's level and reaches open hand, boy relieved; uniformed helper nearby", "Boy holds mother's hand securely and waves thanks to helper, both remain on sidewalk, happy and relieved", False),
    ],
}


def queue() -> list[dict]:
    inventory = json.loads((ROOT / "docs/scene_asset_inventory.json").read_text(encoding="utf-8"))
    entries = []
    for scene in inventory["scenes"]:
        sid, page = scene["story_id"], scene["page"]
        location, first, second, loop = POSES[sid][page - 1]
        # Keep each prompt independent and tied to an original reference.
        columns = 2 if loop else 3
        beat_specs = (
            f"LEFT FRAME: {first}. RIGHT FRAME: {second}."
            if loop else " ".join(f"FRAME {i + 1}: {beat}." for i, beat in enumerate(scene["animation_beats"]))
        )
        prompt = (
            "Use case: identity-preserve / illustration-story. Create ONE PRODUCTION ANIMATION SPRITE STRIP, "
            f"EXACTLY {columns * 1024}x768 pixels: {columns} equal 1024x768 4:3 animation cels side by side, "
            "ONE row, no gutters/borders. Preserve equal cel dimensions and clear vertical cel boundaries. "
            "Consecutive articulated character poses: do NOT fake action by sliding/zooming a whole static illustration. "
            "Same-location actions MUST use identical background, camera distance, character size and placement; "
            "only limbs, hands, expressions and contacted props change. Travel/entry across locations may change "
            "environment deliberately to show the narrated progression. "
            f"Original reference image is {scene['original_image']}. IDENTITY LOCK: {scene['original_character_identity']} "
            f"Narration for context, never print words: {scene['narration']} "
            f"Required location(s): {scene['required_environment']}. Emotion: {scene['required_emotion']}. "
            f"Props/contact: {', '.join(scene['required_props'])}. {beat_specs} "
            "Show ALL narrated beats in this ordered strip, each cel a distinct meaningful action pose. "
            "Use exact reference faces, hair, eye shape, skin, clothes, proportions and "
            "warm premium 2D children's cartoon rendering. Full uncropped heads with visible space ABOVE hair and around "
            "all active hands/props in EVERY frame; 10% safe margin around heads. Full body and feet visible for walking/sitting/standing "
            "actions. Keep hands anatomically coherent and props held or supported correctly. No text, speech bubbles, "
            "labels, numbers, watermark or logos. For toilet scenes conceal all private anatomy behind privacy partition "
            "or non-explicit clothing, never draw nudity. For roads child remains behind curb until adult checks safe crossing; "
            "never step into road on red pedestrian light. For personal space never hug or touch without consent. "
            f"Asset id: {scene['scene_id']}."
        )
        entries.append({
            "scene_id": scene["scene_id"], "story_id": sid, "page": page,
            "reference": str(ROOT / scene["original_image"]), "prompt": prompt,
            "columns": columns, "rows": 1, "frameCount": columns,
            "loop": loop, "cue": scene["lead"].split(".")[0],
            "description": f"{location}: {first}; then {second}",
            "qa_status": "awaiting_generation",
        })
    return entries


def export(entries: list[dict]) -> list[dict]:
    atlas_dir = ROOT / "assets/animations/spritesheets"
    poster_dir = ROOT / "assets/images/story_scenes"
    atlas_dir.mkdir(parents=True, exist_ok=True)
    poster_dir.mkdir(parents=True, exist_ok=True)
    results = []
    for entry in entries:
        if entry.get("qa_status") != "reviewed_ready":
            results.append(entry)
            continue
        source = Path(entry["source_path"])
        source_hash = hashlib.sha256(source.read_bytes()).hexdigest() if source.is_file() else None
        # A checkout already contains the final PNGs. The optional original
        # generation path need not exist on another developer's computer.
        if ((source_hash is None or entry.get("source_sha256") == source_hash) and entry.get("atlas") and entry.get("poster")
                and entry["atlas"].endswith(".png")
                and (ROOT / entry["atlas"]).is_file() and (ROOT / entry["poster"]).is_file()
                and hashlib.sha256((ROOT / entry["atlas"]).read_bytes()).hexdigest() == entry.get("atlas_sha256")
                and hashlib.sha256((ROOT / entry["poster"]).read_bytes()).hexdigest() == entry.get("poster_sha256")):
            results.append(entry)
            continue
        if source_hash is None:
            raise FileNotFoundError(f"{entry['scene_id']}: outputs changed and original generation source is unavailable: {source}")
        with Image.open(source) as image:
            image.load()
            width, height = image.size
            columns = entry.get("columns", 2)
            if columns not in (2, 3) or width % columns != 0:
                raise ValueError(f"{source}: image {image.size} does not divide into {columns} equal cells")
            frame_width = width // columns
            name = f"{entry['story_id']}_scene_{entry['page']:02}.png"
            atlas = atlas_dir / name
            poster = poster_dir / name
            if image.format == "PNG":
                shutil.copyfile(source, atlas)
            else:
                image.save(atlas, "PNG", compress_level=1)
            poster_index = entry.get("posterFrame", 0)
            if not 0 <= poster_index < columns:
                raise ValueError(f"Invalid posterFrame for {entry['scene_id']}")
            image.crop((poster_index * frame_width, 0, (poster_index + 1) * frame_width, height)).save(
                poster, "PNG", compress_level=1
            )
        results.append({
            **entry,
            "source_sha256": source_hash,
            "atlas": atlas.relative_to(ROOT).as_posix(),
            "poster": poster.relative_to(ROOT).as_posix(),
            "width": width,
            "height": height,
            "frameWidth": frame_width,
            "frameHeight": height,
            "columns": columns,
            "rows": 1,
            "row": 0,
            "frameCount": columns,
            "fps": entry.get("fps", 1.5),
            "posterFrame": poster_index,
            "atlas_sha256": hashlib.sha256(atlas.read_bytes()).hexdigest(),
            "poster_sha256": hashlib.sha256(poster.read_bytes()).hexdigest(),
            "export_method": "original_png_copy_without_resizing; poster_is_lossless_exact_frame_crop",
            "generation_method": "built_in_image_gen",
            "tablet_quality_note": f"Each native frame is {frame_width}x{height}; no 4K quality claim. Review on target tablets.",
        })
    return results


def merge_manifests(paths: list[Path], destination: Path) -> dict:
    """Merge reviewed groups in original story/page order with strict evidence checks."""
    baseline = json.loads((ROOT / "docs/story_assets_baseline.json").read_text(encoding="utf-8"))
    expected = [f"{story['id']}-p{i + 1}" for story in baseline["stories"] for i in range(len(story["pages"]))]
    ordered = {scene_id: index for index, scene_id in enumerate(expected)}
    entries = {}
    for path in paths:
        for entry in json.loads(path.read_text(encoding="utf-8"))["scenes"]:
            scene_id = entry["scene_id"]
            if scene_id in entries:
                raise ValueError(f"Duplicate scene across group manifests: {scene_id}")
            if scene_id not in ordered:
                raise ValueError(f"Unexpected scene: {scene_id}")
            if entry.get("qa_status") != "reviewed_ready":
                raise ValueError(f"Scene has not passed visual review: {scene_id}")
            for key in ("atlas", "poster"):
                asset = ROOT / entry[key]
                if not asset.is_file() or not asset.stat().st_size:
                    raise ValueError(f"Missing/empty {key} for {scene_id}: {asset}")
                if hashlib.sha256(asset.read_bytes()).hexdigest() != entry[f"{key}_sha256"]:
                    raise ValueError(f"Changed {key} pixels/file for {scene_id}")
            with Image.open(ROOT / entry["atlas"]) as atlas:
                if atlas.size != (entry["width"], entry["height"]):
                    raise ValueError(f"Atlas dimensions differ from metadata: {scene_id}")
                if entry["width"] % entry["columns"] or entry["frameWidth"] != entry["width"] // entry["columns"]:
                    raise ValueError(f"Invalid equal-cell grid: {scene_id}")
                if entry["frameWidth"] < 640 or entry["frameHeight"] < 480:
                    raise ValueError(f"Native frame below integration floor (no resizing permitted): {scene_id}")
            with Image.open(ROOT / entry["poster"]) as poster:
                if poster.size != (entry["frameWidth"], entry["frameHeight"]):
                    raise ValueError(f"Poster has wrong dimensions: {scene_id}")
            entries[scene_id] = entry
    missing = [scene_id for scene_id in expected if scene_id not in entries]
    if missing:
        raise ValueError(f"Refusing incomplete merge; missing {len(missing)} scenes: {', '.join(missing)}")
    for asset in baseline["assets"]:
        if hashlib.sha256((ROOT / asset["path"]).read_bytes()).hexdigest() != asset["sha256"]:
            raise ValueError(f"Original artwork changed: {asset['path']}")
    result = {
        "generation_method": "built_in_image_gen",
        "generated_count": len(entries),
        "story_count": len(baseline["stories"]),
        "group_manifests": [str(path.relative_to(ROOT) if path.is_absolute() else path).replace("\\", "/") for path in paths],
        "verification": {
            "all_original_artwork_hashes_unchanged": True,
            "all_atlas_and_poster_files_and_hashes_verified": True,
            "all_scene_strips_visually_reviewed_by_generation_agent": True,
            "all_native_frames_at_least_640x480": True,
            "native_4k_artwork": False,
            "device_tts_timing_verified": False,
            "large_tablet_sharpness_verified": False,
            "animation_type": "limited_articulated_two_or_three_key_pose_animation; not_skeletal",
        },
        "scenes": [entries[scene_id] for scene_id in expected],
    }
    destination.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--queue", action="store_true", help="Write local prompt specs only; performs no generation")
    parser.add_argument("--merge", nargs="+", type=Path, help="Merge complete reviewed group manifests; checks all 75 scenes and files")
    args = parser.parse_args()
    if args.merge:
        merged = merge_manifests(args.merge, args.manifest)
        print(f"Merged and verified {merged['generated_count']} scenes / {merged['story_count']} stories; all original artwork unchanged.")
        return
    if args.queue:
        path = ROOT / "docs/generated_scene_queue.json"
        path.write_text(json.dumps({"scenes": queue()}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print("Prepared 75 original-character-referenced two/three-pose specifications. No images generated by this script.")
        return
    document = json.loads(args.manifest.read_text(encoding="utf-8"))
    document["scenes"] = export(document["scenes"])
    document["generated_count"] = sum(s.get("qa_status") == "reviewed_ready" for s in document["scenes"])
    args.manifest.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Exported {document['generated_count']} reviewed scene strips and posters without resizing.")


if __name__ == "__main__":
    main()
