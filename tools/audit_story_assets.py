"""Rebuild the scene inventory without modifying story data or original artwork.

Run from the repository root: python tools/audit_story_assets.py
No third-party dependencies. The first run records the original story snapshot;
subsequent runs retain it and refresh only current implementation evidence.
"""
from __future__ import annotations

import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"

# These identities were recorded by visually inspecting every original PNG.
IDENTITIES = {
    "going_to_school": "Boy: short tousled dark brown hair, large dark oval eyes, warm peach skin, round rosy cheeks, blue collared shirt and blue backpack. Mother: long dark brown hair, warm peach skin, lilac-pink blazer over pale pink top and blue trousers. Match these exact faces. Teacher is a supporting adult, distinct from mother.",
    "going_to_the_toilet": "Boy: short layered dark brown hair with small crown tufts, large dark oval eyes, warm peach skin and rosy cheeks, blue collared shirt and dark shorts. Original holds an unrelated toothbrush at the bathroom door; retain the boy, remove the toothbrush from toilet scenes.",
    "going_to_the_doctor": "Boy: short tousled brown hair, large dark oval eyes, round warm peach face, rosy cheeks, blue polo and dark shorts. Doctor: woman with side-swept dark brown hair in low ponytail, white coat over blue blouse, blue stethoscope, warm peach skin. Preserve both faces.",
    "brushing_teeth": "Boy: layered tousled dark brown hair, large dark brown eyes, warm peach skin, rounded rosy cheeks, blue collared shirt. Preserve original yellow toothbrush shape and blue bathroom/yellow towel visual palette; omit the unrelated second implement.",
    "restaurant": "Boy: short tousled dark brown hair, large dark oval eyes, warm peach skin, rosy cheeks, blue collared shirt. Mother: long straight dark brown hair, large dark eyes, mustard-yellow short sleeve top. Preserve both original faces and warm restaurant lighting.",
    "airport": "Boy: short tousled dark brown hair, large dark oval eyes, warm peach skin, rosy cheeks, lime-green/yellow polo, dark blue trousers, large blue backpack with yellow details. Preserve the airport-specific clothes; do not substitute the blue polo from other stories.",
    "playground": "Boy: dark brown tousled hair, warm peach skin, blue hooded sweatshirt, charcoal shorts. Friend: long dark brown hair with bangs, pink headband, warm peach skin, pink hoodie and light gray shorts. Preserve both original faces and playground colors.",
    "sharing": "Boy: short tousled brown hair, large dark oval eyes, warm peach skin, blue polo. Friend: long dark brown hair swept to one side, large dark eyes, warm peach skin, purple hooded top. Preserve their faces and the colorful tabletop toy.",
    "asking_for_help": "Boy: short tousled dark brown hair, large dark eyes, warm peach skin, blue collared shirt. Trusted adult: shoulder-length dark brown hair with side-swept fringe, pink short-sleeve top, blue jeans. Preserve both faces, with adult calmly bending to child's level.",
    "personal_space": "Boy: short tousled dark brown hair, large dark oval eyes, warm peach skin, blue polo, olive shorts, white socks and black shoes. Friend: long dark brown hair with side fringe, pink open cardigan over pale pink top, purple skirt and pink shoes. Preserve both exact faces and full-body proportions.",
    "saying_no": "Protagonist is the GIRL, not the boy from the other stories: long dark brown hair with bangs, large brown eyes, warm peach skin, rosy round cheeks, pink collared short-sleeve shirt. Supporting adult is partly visible in blue. Preserve the girl's face and hairstyle; do not replace her with a boy.",
    "staying_safe": "Boy: tousled dark brown hair, warm peach skin, blue hoodie, charcoal shorts, white socks and dark shoes. Mother: long dark brown hair, pink blazer over pale pink top, blue trousers, brown shoulder bag. Preserve their exact faces; helper is an additional distinct adult.",
}

# Each entry: location | emotion | props | successive meaningful pose beats |
# scene-specific defect in the original flattened picture. Beats change limbs,
# expression, or object contact; they never request camera zoom as animation.
PLAN = {
    "going_to_school": [
        "home entryway then school approach|calm, ready|shirt, blue backpack, doorway|finish fastening shirt; lift backpack by strap; put both straps on shoulders and leave with mother|Original already shows backpack on; no dressing or pickup sequence.",
        "sidewalk leading toward school|calm, attentive|blue backpack, school entrance, pavement|boy and mother take first walking step; alternate opposite legs and arms; arrive at school curb|Original indoors at doorway; no sidewalk, walking legs or school route.",
        "school entrance|reassured, slight separation concern settling|school door, backpack|boy turns toward mother; waves goodbye while mother waves back; teacher receives child as mother remains at entrance|Original smiles at home; no goodbye or school arrival.",
        "classroom doorway|welcoming, happy|classroom door, backpack|teacher raises hand in greeting; boy waves back; both hands settle as child enters|Original adult is mother, not a teacher; no classroom.",
        "classroom|attentive, interested|child-sized chair, desk, book, board|boy pulls chair; bends knees and sits; looks toward teacher with book on desk|Original standing at home; no seat or learning objects.",
        "school pickup then home entrance|happy, connected|school gate, backpack, home door|mother meets boy at gate; they walk away together; boy gestures while telling mother about day|Original is morning departure, not pickup or returning home.",
    ],
    "going_to_the_toilet": [
        "bathroom entrance|aware, calm|bathroom door, toilet pictogram|boy signals need to trusted adult; reaches door handle; enters bathroom|Original has closed door and unrelated toothbrush; adult communication and entry missing.",
        "private bathroom stall|relaxed, unhurried|toilet, waistband, privacy partition|child lowers waistband only behind privacy screen; bends knees to sit; sits calmly with lap concealed|Original stands outside closed door; toilet, sitting and privacy absent.",
        "private bathroom stall|focused, calm|toilet-paper roll, toilet, privacy partition|hand reaches toilet paper; tears small length; wiping shown as non-explicit directional instruction with body concealed|Original contains no toilet paper or wiping; toothbrush is unrelated.",
        "bathroom beside toilet|calm, prepared for sound|toilet, flush handle|boy reaches flush control; presses it; hand settles while water swirls gently|Original hand is near door and holds toothbrush; no flush mechanism.",
        "private bathroom stall|focused, comfortable|waistband, clothing, privacy partition|child stands behind partition; raises waistband; checks shirt and trousers with clothes fully on|Original cannot show pulling clothes up and is not inside stall.",
        "bathroom sink|focused, content|sink, soap pump, water stream|wet hands; press soap and rub palms/fingers together; rinse hands under faucet|Original sink at edge only, child faces door holding toothbrush; no handwashing contact.",
        "bathroom towel rail|content|yellow towel, dry hands, nearby sink|reach for towel; rub both hands inside towel; hang towel with hands dry|Original no visible towel or drying action.",
        "bathroom doorway|quiet pride, relieved|closed faucet, neatly hung towel, doorway|boy checks clean hands; smiles and nods; leaves bathroom with clothing secure|Original carries unrelated toothbrush and has not completed bathroom sequence.",
    ],
    "going_to_the_doctor": [
        "doctor clinic entrance then exam room|slightly uncertain then reassured|clinic doorway, exam bench, doctor's coat|boy enters with trusted adult; doctor gestures toward bench; boy sits for checkup|Original already seated with doctor; arrival absent.",
        "clinic exam room|friendly, reassured|exam bench, doctor coat|doctor waves hello; boy waves back; both settle hands|Original seated smiling without greeting poses.",
        "clinic exam room|calm, mild surprise at cold touch|stethoscope, exam bench|doctor lifts stethoscope; places chestpiece over clothed chest; listens while boy breathes gently|Original stethoscope hangs on neck, not touching child's chest.",
        "clinic exam room|cooperative, calm|otoscope, exam light, disposable tongue depressor|doctor checks outside ear with otoscope; boy opens mouth; doctor looks with light without force|Original no ear/mouth examination or open-mouth pose.",
        "clinic exam room|thoughtful, listened to|simple body-feelings picture card, exam bench|boy points to body/feeling card; speaks or gestures; doctor leans in and listens|Original generic smile does not convey communicating symptoms.",
        "clinic exit|relieved, grateful|doctor coat, clinic door|boy nods thanks; waves goodbye; leaves with trusted adult|Original still seated during checkup, no thanks or exit.",
    ],
    "brushing_teeth": [
        "bathroom sink|ready, focused|yellow toothbrush, toothpaste tube, sink|reach for toothbrush; hold brush while placing paste; bring brush to teeth|Original holds brush away from mouth and a second blue object; no pickup or brushing.",
        "bathroom sink|focused|yellow toothbrush, toothpaste tube, pea-size paste|hold bristles steady; squeeze small paste bead onto bristles; stop squeezing and cap tube|Original lacks tube, paste deposition and controlled bead size.",
        "bathroom sink and mirror|focused, comfortable|toothbrush, sink, small foam|bristles contact front teeth; wrist makes small circles; angle brush toward back teeth with mouth open|Original brush below mouth; no contact or repeated arm/hand poses.",
        "bathroom sink|calm, patient|toothbrush, optional passive timer without forced limit|brush gently on one side; move wrist to other side; continue small controlled circles|Original does not brush; do not force child to wait two real minutes to advance.",
        "bathroom sink|focused then relieved|sink bowl, toothbrush, faucet|lean over sink and spit discreetly; place bristles under water; move brush through stream to rinse|Original duck-focused crop unrelated; child upright holding implements away from sink.",
        "bathroom mirror|quiet pride, happy|clean toothbrush in holder, sink|put clean brush in holder; look in mirror and smile showing clean teeth; relax hands|Original still holding unused brush and unrelated object; no completed routine.",
    ],
    "restaurant": [
        "restaurant table|comfortable, interested|chair, table, picture menu, waiter|boy bends to sit in chair; points to menu choice; communicates order to waiter|Original seated talking to mother, no sitting transition or waiter/order.",
        "restaurant table|interested|picture menu, table|lift or open menu; look over food pictures; point to chosen food image|Original menu held by mother; boy does not visibly inspect/point at choice.",
        "restaurant table before food arrives|patient, mildly restless then calm|paper, crayons, empty placemat|boy glances toward kitchen; picks crayon; draws slowly while waiting beside mother|Original no drawing tools and no waiting action.",
        "restaurant table during meal|content, calm|food plate, fork/spoon, family table|pick up small bite from plate; bring utensil to mouth; lower utensil and chew gently|Original no eating contact; menu/conversation cannot show meal consumption.",
        "restaurant table|grateful, friendly|water glass, waiter, served plate|boy looks at waiter and gestures please; waiter sets item safely on table; boy nods thanks|Original no service interaction or manners sequence.",
        "restaurant exit then route home|satisfied, relaxed|cleared plate, chair, exit door|boy pushes chair back and stands; waves goodbye; walks out beside mother|Original remains seated with menu, no departure.",
    ],
    "airport": [
        "airport entrance, check-in then security|curious, calm|blue backpack, suitcase, check-in desk, security tray|boy arrives with grown-up; approaches check-in desk; places belonging in security tray|Original alone by departure window, no adult/check-in/security.",
        "airport check-in counter|attentive|ticket or boarding pass, large suitcase, conveyor|show ticket to staff; lift suitcase handle; staff receives bag onto belt|Original no counter/ticket or bag handoff.",
        "airport security lane|calm, cooperative|tray, small belongings, scanner, staff|boy takes belongings from pocket; places them inside tray; walks through lane while staff helps|Original plane-window background cannot depict security or tray use.",
        "airport departure gate|patient, curious|gate seats, window, plane outside, backpack|boy sits beside grown-up; turns toward window; points gently to plane|Original boy stands alone; no waiting seat or companion.",
        "airplane cabin|focused, comfortable|aircraft seat, seatbelt buckle, overhead bin|boy finds seat and sits; brings belt ends together; clicks buckle closed across lap|Original still in terminal, no cabin/seat or belt.",
        "airplane cabin at takeoff|mild surprise then reassured|secure seatbelt, cabin window, clouds|boy remains buckled as view climbs; opens mouth in yawn; swallows and relaxes|Original plane parked outside terminal; no onboard takeoff/yawn.",
        "destination airport then vehicle pickup|relieved, excited|arrivals exit, collected bag, vehicle, child restraint|walk through arrivals with bag and adult; sit safely in vehicle; secure age-appropriate restraint before departure|Original departure terminal, no arrival/baggage/vehicle ride.",
    ],
    "playground": [
        "playground queue|patient, friendly|slide queue marker, swing|boy waits clear of equipment; friend finishes turn; boy approaches only when equipment is clear|Original both children playing close together, no queue or waiting order.",
        "playground slide|happy, attentive to safety|slide, ladder, clear landing zone|boy sits at top when landing clear; seated slide pose moves down; feet reach ground while friend waits away|Original seated on play structure beside friend, no slide descent.",
        "playground open area|friendly, hopeful|play structure in background|boy turns toward friend; gestures invitation with open hand; friend responds and joins|Original children already playing, no invitation/response poses.",
        "playground swing bay|happy, patient|swing seat, chains, safe waiting spot|one child grips chains and swings gently; swing slows to stop; child stands aside and friend approaches for next turn|Original no swing contact or turn exchange.",
        "playground beside equipment|concerned then reassured|small scraped knee, bench, trusted adult|friend sits with sad expression and sore knee; boy signals adult while staying near; adult kneels calmly to help|Original both smiling and playing; injury concern and helper absent.",
        "playground exit|slight disappointment then reassured|park gate, trusted adult|adult signals time to go; boy and friend wave; boy walks out with adult|Original children continue play, no goodbye/exit.",
    ],
    "sharing": [
        "indoor playroom table|friendly, happy|original colorful tabletop toy|boy holds toy; offers it across table; friend accepts with both hands|Original shared hold captures only midpoint, no turn or giving animation.",
        "indoor playroom table|hopeful, patient|toy held by friend|boy looks at friend and asks with open hand; pauses without grabbing; friend looks up and responds|Original both holding toy and smiling; no asking/waiting distinction.",
        "indoor playroom table|happy, generous|original colorful toy|boy extends toy while still supporting it; friend's hands close on toy; boy releases once friend has it|Original static shared hold lacks clear owner transfer or support sequence.",
        "indoor playroom table|happy, engaged|two compatible toys or blocks|boy places block; friend adds matching piece; both admire shared construction|Original one toy passed, no cooperative play sequence.",
        "indoor playroom table|patient, settled|friend's toy, separate alternative toy|boy waits with hands away from friend's toy; chooses different toy; plays independently while friend finishes|Original both reaching same toy; no alternative activity or waiting.",
        "indoor playroom table|quiet pride, happy|shared toy resting safely on table|children put toy down together; exchange smiles; boy nods with proud relaxed posture|Original smile broadly fits emotion but cannot convey action completion or movement.",
    ],
    "asking_for_help": [
        "home doorway|uncertain then reassured|trusted adult, door handle beyond easy reach|boy pauses at difficult task; turns to trusted adult; gestures for help as adult listens|Original open-hand interaction loosely fits but does not depict need or asking motion.",
        "home doorway with family; classroom inset for teacher|safe, reassured|family photo card, teacher picture card|adult indicates family card; indicates teacher card; child nods and points to trusted helper|Original one unnamed adult only, no teacher/family examples.",
        "home doorway or classroom|calm, confident|trusted adult nearby|boy lifts hand; holds raised hand while asking; adult turns toward him|Original child arm low, blue help bubble cannot replace raised hand.",
        "home doorway|focused, understood|simple picture communication card, difficult door handle|boy points to task; chooses matching picture or gestures; adult follows point and nods|Original generic hands and help label do not show communicating specific need.",
        "home doorway|relieved, grateful|door handle, safely opening door|adult listens at child's level; opens difficult door with child clear of hinge; child nods thanks|Original no actual help/task completion.",
        "home doorway|quiet confidence, relief|open doorway, trusted adult|boy lifts head with confident expression; adult nods encouragement; boy moves through doorway calmly|Original generic smile only, no confidence/completed task sequence.",
    ],
    "personal_space": [
        "indoor hallway|comfortable, friendly|clear floor gap|boy notices friend nearby; takes one small step back; both stand with comfortable gap|Original fixed gap is appropriate but no giving-space action.",
        "indoor hallway|attentive, comfortable|unobstructed arm-length gap|boy gently raises one arm; extends arm into empty gap without touching friend; lowers it leaving space|Original arms down; arrow graphic cannot show arm-length check.",
        "indoor hallway|hopeful, respectful|clear gap, optional question symbol|boy asks with open hands while staying apart; friend considers; boy waits for clear response before any approach|Original no hug request; must not animate unsolicited hug.",
        "indoor hallway|accepting, friendly|clear gap|friend gently shakes head no; boy acknowledges and stays back; boy waves and friend waves back|Original smiling gap has no refusal/acceptance or alternative greeting.",
        "indoor hallway|assertive then comfortable|clear floor gap|boy raises open palm and asks for space; friend takes step back; boy relaxes with space restored|Original gap already established, no request or response.",
        "indoor hallway|relaxed, kind|clear gap|both lower hands in relaxed posture; exchange small smiles; wave while maintaining comfortable distance|Original static positive emotion broadly matches, but no meaningful motion.",
    ],
    "saying_no": [
        "home indoor room|calm, confident|offered lollipop held by adult|adult offers item at respectful distance; girl raises open palm; adult withdraws offer without pressure|Original refusal midpoint fits, no offer/withdrawal action.",
        "home indoor room|kind, calm|offered item kept away from girl|girl looks at adult; gently shakes head left then right; settles facing adult with calm mouth|Original static hand and speech bubble lack head movement.",
        "home indoor room|accepting, calm|toy girl offers to friend|girl offers toy without pushing; friend politely declines; girl nods okay and draws toy back|Original girl is refusing adult candy; does not show another person saying no to her.",
        "public indoor space near trusted adult|concerned, assertive then safe|clear path to trusted adult, stop-hand gesture|girl raises firm stop hand with serious face; turns away from uncomfortable interaction; tells nearby trusted adult|Original happy candy refusal does not represent unsafe feeling or telling helper.",
        "home indoor room|firm, self-assured|personal-space gap, open palm|girl makes clear stop gesture before unwanted touch; other person immediately stops and steps back; girl relaxes|Original candy offer is not a touch-boundary example; do not depict unwanted contact.",
        "home indoor room|confident, friendly|declined item moved aside|girl finishes calm no gesture; adult nods acceptance and removes offer; girl smiles gently|Original static midpoint cannot show accepted refusal and closure.",
    ],
    "staying_safe": [
        "sidewalk at marked road crossing|attentive, calm|mother's hand, curb, zebra crossing, stopped traffic|boy holds mother's hand on sidewalk; turns head left and right; crosses only when adult confirms safe|Original already in road; no looking-both-ways or wait-before-cross sequence.",
        "sidewalk beside busy road|attentive, secure|mother's hand, curb, cars confined to road|boy reaches mother's hand; hands clasp; they walk along sidewalk remaining behind curb|Original both already in crosswalk, not sidewalk as narration requires.",
        "sidewalk at pedestrian signal|patient, attentive|pedestrian red stop/green walk signal, crossing, stopped cars|stand behind curb during red pedestrian signal; green pedestrian signal appears; remain with adult and check vehicles before step|Original green signal with characters mid-crossing cannot show waiting for red or safe transition.",
        "public shop entrance or sidewalk safe waiting spot|worried then reassured|uniformed shop worker or police helper, visible landmark|boy stops and stays beside landmark; signals nearby official helper without wandering; helper comes to child and listens|Original boy accompanied by mother crossing road, not lost or stationary with helper.",
        "public safe waiting spot with official helper|thoughtful then reassured|helper's notepad or communication card, family picture|boy points to picture of grown-up; says or indicates grown-up's name; helper notes information while child stays put|Original no helper or name-communication interaction.",
        "safe sidewalk after reunion|relieved, happy|mother's hand, pedestrian crossing safely behind|mother meets child and takes hand; child looks toward helper and thanks them; both continue together on sidewalk|Original mid-road scene cannot show reunion/help or safe final sidewalk state.",
    ],
}


def png_info(path: Path) -> dict:
    data = path.read_bytes()
    width, height = struct.unpack(">II", data[16:24])
    return {
        "path": path.relative_to(ROOT).as_posix(),
        "width": width,
        "height": height,
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "type": "flattened_scene_illustration",
        "separate_rig_layers": False,
    }


def main() -> None:
    DOCS.mkdir(exist_ok=True)
    baseline_path = DOCS / "story_assets_baseline.json"
    current = json.loads((ROOT / "assets/data/stories.json").read_text(encoding="utf-8"))
    if baseline_path.exists():
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    else:
        baseline = {
            "audit_date": "2026-10-26",
            "stories": current["stories"],
            "assets": [png_info(ROOT / f"assets/images/stories/{sid}.png") for sid in PLAN],
        }
        baseline_path.write_text(json.dumps(baseline, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    current_by_id = {s["id"]: s for s in current["stories"]}
    reviewed_manifest_path = DOCS / "generated_scene_assets.json"
    reviewed_manifest = json.loads(reviewed_manifest_path.read_text(encoding="utf-8")) if reviewed_manifest_path.exists() else {}
    reviewed_by_id = {s["scene_id"]: s for s in reviewed_manifest.get("scenes", [])}
    evidence_path = DOCS / "test_verification.json"
    evidence = json.loads(evidence_path.read_text(encoding="utf-8")) if evidence_path.exists() else {}
    evidence_matches = evidence.get("stories_sha256") == hashlib.sha256((ROOT / "assets/data/stories.json").read_bytes()).hexdigest()
    scenes = []
    for story in baseline["stories"]:
        sid = story["id"]
        assert len(PLAN[sid]) == len(story["pages"]), sid
        reference = f"assets/images/stories/{sid}.png"
        for index, page in enumerate(story["pages"]):
            environment, emotion, props, beats, mismatch = PLAN[sid][index].split("|")
            narration = " ".join(p.strip() for p in [page["lead"], page["body"]] if p.strip())
            current_page = current_by_id[sid]["pages"][index]
            animation = current_page.get("animation")
            review = reviewed_by_id.get(f"{sid}-p{index + 1}", {})
            reviewed = review.get("qa_status") == "reviewed_ready" and all(
                (ROOT / review.get(key, "")).is_file() and
                hashlib.sha256((ROOT / review[key]).read_bytes()).hexdigest() == review.get(hash_key)
                for key, hash_key in [("atlas", "atlas_sha256"), ("poster", "poster_sha256")]
            )
            integrated = reviewed and animation is not None and animation.get("asset") == review.get("atlas") and current_page["image"] == review.get("poster")
            prompt = (
                f"Use case: illustration-story / identity-preserve. Reference image: {reference}. "
                f"Create situation-specific animation poses for {story['title']}, scene {index + 1:02}. "
                f"Identity lock: {IDENTITIES[sid]} "
                f"Narration (do not render as image text): {narration} "
                f"Environment: {environment}. Emotion: {emotion}. Props/contact: {props}. "
                f"Ordered animation beats: {beats}. "
                "Maintain the original 2D cartoon linework, warm shading, exact eyes, nose, mouth, hair, skin tone, "
                "clothing and proportions. Draw distinct coherent limb/hand/object poses with fixed camera and background. "
                "Keep each prop in contact with its correct hand or support. Keep heads, hands, feet and key props inside "
                "a ten-percent safe margin. No camera zoom/pan as action; no added text, watermark or unrelated characters. "
                "Production target: 4096x3072 background and 2048px character layers or equivalent high-resolution "
                "frame exports; transparent PNG for isolated character/prop layers. Do not upscale a small pose and call it native 4K."
            )
            scenes.append({
                "scene_id": f"{sid}-p{index + 1}",
                "story_id": sid,
                "story_title": story["title"],
                "page": index + 1,
                "lead": page["lead"],
                "body": page["body"],
                "narration": narration,
                "original_image": reference,
                "original_focus": page.get("focus"),
                "original_character_identity": IDENTITIES[sid],
                "required_environment": environment,
                "required_emotion": emotion,
                "required_props": [p.strip() for p in props.split(",")],
                "animation_beats": [b.strip() for b in beats.split(";")],
                "original_mismatch": mismatch,
                "current_image": current_page["image"],
                "current_image_exists": (ROOT / current_page["image"]).is_file(),
                "current_animation": animation,
                "production_status": "limited_animation_integrated_device_qa_pending" if integrated else "reviewed_artwork_not_integrated" if reviewed else "missing_scene_animation",
                "artwork_qa_notes": review.get("qa_notes"),
                "actual_generation_prompt": review.get("prompt"),
                "native_frame_resolution": [review.get("frameWidth"), review.get("frameHeight")] if review.get("frameWidth") else None,
                "generation_prompt": prompt,
                "question_count": len(story.get("questions", [])),
                "transition": "manual_next_or_thumbnail; quiz_if_present_after_last_scene; replay_available",
                "completion_checklist": {
                    "correct_character_identity_visually_verified": reviewed,
                    "environment_visually_verified": reviewed,
                    "action_visually_verified": reviewed,
                    "emotion_visually_verified": reviewed,
                    "object_contact_visually_verified": reviewed,
                    "animation_runtime_verified": integrated and evidence_matches and evidence.get("all_scene_rendering_passed", False),
                    "narration_timing_on_device_verified": False,
                    "tablet_sharpness_verified": False,
                    "safe_framing_verified": reviewed,
                },
            })
    original_assets = []
    for original in baseline["assets"]:
        current_info = png_info(ROOT / original["path"])
        original_assets.append({**original, "original_unchanged": current_info["sha256"] == original["sha256"]})
    out = {
        "audit_date": "2026-10-26",
        "implementation_review_date": "2026-10-27",
        "story_count": len(baseline["stories"]),
        "scene_count": len(scenes),
        "bundled_questions_before_change": sum(len(s.get("questions", [])) for s in baseline["stories"]),
        "inventory_scope": "Bundled Flutter stories, original assets, story player, editor, server and admin models. Device-specific TTS and tablet display require runtime review.",
        "original_assets": original_assets,
        "scenes": scenes,
    }
    (DOCS / "scene_asset_inventory.json").write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    lines = [
        "# Story asset audit", "", "Audited 26 October 2026.", "",
        f"The original bundle has {len(baseline['stories'])} stories, {len(scenes)} scenes and zero comprehension questions. "
        "Each story reuses one flattened PNG. There are no separate character, expression, prop, background, Rive or sprite assets in the original bundle. "
        "The 12 originals are 760–776px wide and 576–644px high, below the requested large-tablet artwork targets.", "",
        "`story_assets_baseline.json` preserves original story data and SHA-256 hashes. "
        "`scene_asset_inventory.json` contains the detailed per-scene requirements, exact narration and original-character-referenced generation prompts. "
        "Run `python tools/audit_story_assets.py` to refresh implementation evidence. File existence and animation metadata are evidence only; they do not prove artwork/action/identity quality.", "",
        "## Original identity constraints", "",
    ]
    for sid, identity in IDENTITIES.items():
        lines.extend([f"- **{sid}:** {identity}"])
    lines.extend(["", "## Scene-by-scene mapping", "", "| Scene | Narration | Environment, action and emotion | Original mismatch |", "| --- | --- | --- | --- |"])
    for scene in scenes:
        action = "; ".join(scene["animation_beats"])
        lines.append(f"| {scene['scene_id']} | {scene['narration']} | {scene['required_environment']}; {action}; {scene['required_emotion']} | {scene['original_mismatch']} |")
    lines.extend([
        "", "## Integration and verification findings", "",
        "- The original page image renderer uses cover plus optional zoom, which can crop faces, limbs and props. New scene art should use contain within a stable aspect ratio and safe artwork margins.",
        "- Original narration exposes only speaking/stopped state. Word progress, pause/resume and stale asynchronous callback protection are needed for action timing. A speech-rate-based clock is only a fallback when the engine supplies no word events.",
        "- The story player advances manually by Next, swipe or thumbnail, and opens a quiz only when questions exist. There are no forced time limits. Preserve this behavior and all remotely authored questions.",
        "- Existing quiz feedback allows gentle retries; question models originally have text choices only. Future image answers need explicit per-choice asset references that survive editor, API, server review and admin round trips.",
        "- The original Java server cleans pages into known image/lead/body/focus fields; animation metadata would otherwise disappear during seeding, save or approval. The admin app also compares only those fields. Review both paths when adding metadata.",
        "- RemoteStoryRepository originally resolves only page image URLs. Any remote atlas/choice assets also need safe resolution; bundled assets should remain bundled.",
        "- tools/gen_stories.py originally reconstructs all story data and discards any new animation mappings/questions. Preserve authored fields during regeneration.",
        "- No original games module exists in this repository. Parent gate, subscriptions, drafts, review submissions and remote story sync are the existing non-player flows that require regression checks.",
        "- An established server data file takes precedence over bundled seeds; updating assets/data/stories.json alone does not migrate an already-running server's published stories. Any migration must preserve admin-authored text, questions and edits.",
        "- Toilet scenes must conceal private anatomy and use non-explicit practical hand/prop guidance; personal-space/hug scenes must wait for consent; road scenes must distinguish pedestrian signal from vehicle lights and never step off a curb during red.",
        "", "## Release gate", "",
        "Each scene needs visual review of original identity, environment, action, emotion, object contact and safe framing. "
        "Tablet sharpness and device TTS timing remain separate runtime checks. "
        "Unchecked items in the JSON are deliberately not claimed complete. Generated files and passing structural tests alone do not satisfy these checks.",
    ])
    (DOCS / "story_asset_audit.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Inventoried {out['story_count']} stories / {len(scenes)} scenes; all originals unchanged: {all(a['original_unchanged'] for a in original_assets)}")


if __name__ == "__main__":
    main()
