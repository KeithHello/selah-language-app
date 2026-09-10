# C 短绒阶段 4（闭合花苞）十动作提示词 v4

日期：2026-09-06。用途：为阶段 4 生成十张独立的全身动作关键图。每张图只使用 `seed-c-s4-bud-v3.png` 作为参考，不混用其它阶段母版。动作顺序与 `SpriteActionId.values` 对齐。

## 公共身份与材质段落

```text
Use case: identity-preserve. Deliver ONE complete full-body Selah C short-velour plush mascot in ONE clearly readable action key pose. Use the supplied image as the exact approved character/stage reference: keep its oat-cream very short directional velour, fabric seams, chocolate embroidered oval eyes, tiny stitched mouth, warm subtle blush, same body shape, two short oval fingerless plush arms and two stubby plush feet. Keep the stage's EXACT botanical construction, number, color, relative size and crown attachment; do not invent more leaves, a long stem, a cloak, ears, fingers, thumbs, tail or props. Material and face must stay recognizably the same toy across poses. Strong pose differences should come from real-looking plush limb articulation, stance, sitting, leaning and expression, not rubber deformation or camera changes.

OUTPUT: one square premium plush character state illustration, on a perfectly even WARM IVORY #FBF8F4 studio backdrop and floor matching the approved reference. Keep all FOUR EDGES of the square a uniform plain warm ivory, with the only contact shadow very local and soft beneath the feet. No pattern, no checkerboard, no gradients at the outside edges, no text, no labels, no icons, no scenery, no pedestal or props. This is the same clean warm studio styling as the reference image. Preserve all velour edge fibers naturally.

Square 512 x 512 composition, complete character including every botanical tip and all limbs inside with at least 10% empty margin on ALL sides. The standing character including growth is about 72-76% of the square height, centered horizontally, ground baseline near 84% height. Same physical toy/camera scale across this stage: seated/crouched poses remain lower in frame with more space above, NOT zoomed in to fill the whole square. Follow the mother reference's fabric, color and face construction exactly, soft upper-left studio lighting on the character. Vary articulated pose and expression, not body shape, material, features or head growth. ONE complete character, ONE action key pose, no contact sheet or strip. Highest priority: stage identity, correct short oval arms/two little feet, readable action, premium short velour.
```

## 阶段 4 不变量（追加在公共提示词后）

```text
Use the supplied Stage 04 closed-bud reference image as the ONLY visual reference for this batch. Keep exactly one low, rounded creamy apricot-pink CLOSED flower bud, offset slightly toward viewer-right, nestled in the same low sage leaf cradle and attached at the same small crown root. The bud stays closed in every image; never introduce open petals. Keep its modest height and width, low leaf support and visible forehead consistent in all ten actions. Do not add a second bud, extra leaf, long stalk or any new decoration.
```

## 动作提示词

### A01 — gentleFloat / 轻托花苞

```text
STAGE 04 ACTION 01 / gentleFloat. Standing in a calm three-quarter-neutral pose. One short oval hand is raised beside the lower side of the head, gently supporting the air near the closed bud without touching it or stretching longer; the other hand rests at the body side. Eyes look slightly upward toward the bud with a quiet expectant expression. Feet stay planted on one shared baseline. Keep the closed bud and its root fixed; only the body and arms form this readable pose.
```

### A02 — blink / 低头闭眼

```text
STAGE 04 ACTION 02 / blink. Seated low with the head slightly bowed. Both short oval hands are lightly overlapped in front of the belly, with no fingers. Eyes are gently closed for a blink and the mouth remains a tiny calm curve. Feet stay visible and grounded in front. The closed bud and low leaf cradle keep their exact stage-four geometry and root position.
```

### A03 — leafSway / 侧倾平衡

```text
STAGE 04 ACTION 03 / leafSway. Lean the whole compact body slightly to one side in a clear balance pose. The two short oval arms are at distinct heights, one raised higher and one lowered, both still close to the body and equal in short length. The head and closed bud follow the body lean as one unit, while the flower root remains attached to the crown. Keep both feet visible, with a subtle weight shift but no stretched limbs.
```

### A04 — listenEnter / 认真听

```text
STAGE 04 ACTION 04 / listenEnter. Stand upright with a small side lean. Bring one short oval hand close to the cheek in a listening gesture without touching or elongating it; keep the other hand relaxed at the side. Eyes are open and attentive, mouth neutral. Feet remain flat and the closed bud stays low, rounded and firmly rooted in the leaf cradle.
```

### A05 — listenPlaying / 稳坐聆听

```text
STAGE 04 ACTION 05 / listenPlaying. Sit steadily with both small feet placed forward and fully visible. Both short oval hands rest slightly out to the sides. Raise the head a little, eyes open and quietly listening, with a calm small smile. Keep the body broad and compact, and keep the closed bud, leaves and crown root unchanged.
```

### A06 — listenComplete / 感谢

```text
STAGE 04 ACTION 06 / listenComplete. Stand with both short oval hands lifted to the upper chest in a small grateful gesture, still clearly short and fingerless. Bow the head slightly and close the eyes with a satisfied gentle smile. Keep both feet grounded, the compact body proportion unchanged, and the closed bud low and supported by the same leaf cradle.
```

### A07 — recRecording / 靠近开口

```text
STAGE 04 ACTION 07 / recRecording. Place one short oval hand over the chest and lean the body slightly forward. Bring the other short oval hand beside the mouth as a soft speaking cue, without fingers or a long arm. Use a small round open mouth and focused open eyes. Feet remain stable; the closed flower bud must stay closed and rooted in place.
```

### A08 — recDone / 记录完成

```text
STAGE 04 ACTION 08 / recDone. Stand firmly with both feet grounded. Lift both short oval hands slightly in front of the chest in a restrained happy acknowledgement. Eyes are open and bright, with a soft pleased smile. Keep the body and the stage-four closed bud modest and unchanged; no props or celebratory confetti.
```

### A09 — quizGood / 向上庆祝

```text
STAGE 04 ACTION 09 / quizGood. Show a clear low crouched loading pose transitioning into an upward stretch: the compact body rises, both short oval arms lift high while keeping their original short length, and the toes lift just slightly from the floor. Face has an open joyful embroidered smile and happy eyes. Keep the entire body inside frame, do not elongate limbs, and keep the closed bud and low leaves attached and closed.
```

### A10 — quizFail / 温柔鼓励

```text
STAGE 04 ACTION 10 / quizFail. Use a low-center-of-gravity pose, leaning slightly forward. Both short oval hands rest against the chest, clearly visible and fingerless. Lift the eyes gently toward the viewer with a warm encouraging expression and a tiny smile; never cry, frown or wilt. Feet stay grounded and the closed bud remains the same rounded stage-four bud on its fixed crown root.
```

## 统一负面约束

```text
No second character, no extra arms or legs, no fingers or thumbs, no ears, tail, horns, hair, scarf, jewelry, hat, wand, cup, microphone, book, text, logo, watermark, border, collage, split panel, pedestal, ground plane, cast shadow, white or colored background, painted checkerboard, long fur, glossy plastic, ceramic, glass, metallic surface, stretched body, deformed face, missing feet, cropped body, open flower, visible long stalk, tall pointed bud, giant flower or leaves covering the forehead.
```
