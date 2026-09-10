# C 短绒阶段 5（开放五瓣布花）十动作提示词 v4

日期：2026-09-06。用途：为阶段 5 生成十张独立的全身动作关键图。每张图只使用 `seed-c-s5-bloom-v3.png` 作为参考，不混用其它阶段母版。动作顺序与 `SpriteActionId.values` 对齐。

## 公共身份与材质段落

```text
Use case: identity-preserve. Deliver ONE complete full-body Selah C short-velour plush mascot in ONE clearly readable action key pose. Use the supplied image as the exact approved character/stage reference: keep its oat-cream very short directional velour, fabric seams, chocolate embroidered oval eyes, tiny stitched mouth, warm subtle blush, same body shape, two short oval fingerless plush arms and two stubby plush feet. Keep the stage's EXACT botanical construction, number, color, relative size and crown attachment; do not invent more leaves, a long stem, a cloak, ears, fingers, thumbs, tail or props. Material and face must stay recognizably the same toy across poses. Strong pose differences should come from real-looking plush limb articulation, stance, sitting, leaning and expression, not rubber deformation or camera changes.

OUTPUT: one square premium plush character state illustration, on a perfectly even WARM IVORY #FBF8F4 studio backdrop and floor matching the approved reference. Keep all FOUR EDGES of the square a uniform plain warm ivory, with the only contact shadow very local and soft beneath the feet. No pattern, no checkerboard, no gradients at the outside edges, no text, no labels, no icons, no scenery, no pedestal or props. This is the same clean warm studio styling as the reference image. Preserve all velour edge fibers naturally.

Square 512 x 512 composition, complete character including every botanical tip and all limbs inside with at least 10% empty margin on ALL sides. The standing character including growth is about 72-76% of the square height, centered horizontally, ground baseline near 84% height. Same physical toy/camera scale across this stage: seated/crouched poses remain lower in frame with more space above, NOT zoomed in to fill the whole square. Follow the mother reference's fabric, color and face construction exactly, soft upper-left studio lighting on the character. Vary articulated pose and expression, not body shape, material, features or head growth. ONE complete character, ONE action key pose, no contact sheet or strip. Highest priority: stage identity, correct short oval arms/two little feet, readable action, premium short velour.
```

## 阶段 5 不变量（追加在公共提示词后）

```text
Use the supplied Stage 05 full-bloom reference image as the ONLY visual reference for this batch. Keep exactly one fully open, three-dimensional FIVE-PETAL creamy ivory/apricot cloth flower, offset slightly toward viewer-right, supported by the same low sage leaf cradle and attached at the same small crown root. The five petals stay open in every image and never return to a bud; keep the small warm ochre stitched center and modest sculptural size consistent. Do not add a second bloom, extra leaf, long stalk or any new decoration.
```

## 动作提示词

### A01 — gentleFloat / 欢迎

```text
STAGE 05 ACTION 01 / gentleFloat. Stable standing pose with both short oval arms naturally opened a little to welcome the viewer. Eyes open with a gentle warm embroidered smile. Feet are flat on one baseline and the body remains compact and broad. The five-petal flower stays fully open, modest and rooted in the same low leaf cradle.
```

### A02 — blink / 贴脸闭笑

```text
STAGE 05 ACTION 02 / blink. Sit low and comfortably. Raise both short oval arms beside the cheeks, keeping them smooth, fingerless and short. Close the eyes into curved happy embroidered arcs with a closed smiling mouth. Both feet remain visible in front. The five-petal flower stays open and unchanged.
```

### A03 — leafSway / 四分之一转身

```text
STAGE 05 ACTION 03 / leafSway. Turn the compact body a clear quarter turn while keeping the face readable. Stretch the two short oval arms along a diagonal, one slightly forward and one slightly back, with no long limbs. Shift the weight subtly but keep both feet visible. The open five-petal flower follows the head as one attached botanical crown; its root remains fixed.
```

### A04 — listenEnter / 侧坐回头

```text
STAGE 05 ACTION 04 / listenEnter. Sit in a side-facing pose and turn the head back toward the viewer. Place one short oval hand beside the face in a listening gesture and use the other hand as a small support near the body. Eyes are open and attentive, mouth calm. Keep both feet and the fully open flower visible, with no stretched arm or long stem.
```

### A05 — listenPlaying / 安静侧坐

```text
STAGE 05 ACTION 05 / listenPlaying. Quiet side-seated pose: both short oval arms angle behind the body as support, but both hands remain visibly distinct and fully inside the frame. Place both small feet forward. Eyes are open and focused in attentive listening. The open five-petal bloom and low leaves remain attached at the crown root.
```

### A06 — listenComplete / 致意

```text
STAGE 05 ACTION 06 / listenComplete. Stand with a small turn of the body. Open both short oval arms outward in a restrained greeting or thank-you gesture. Tilt the head slightly forward, eyes softly pleased, mouth a tiny smile. Keep feet grounded and keep the fully open five-petal flower stable and rooted.
```

### A07 — recRecording / 鼓励开口

```text
STAGE 05 ACTION 07 / recRecording. Stable standing pose leaning a little closer to the viewer. Hold both short oval arms forward with palms implied by smooth oval plush shapes, one slightly nearer the mouth; no fingers. Use a small round open mouth and an attentive encouraging expression. Feet stay grounded, and the open bloom remains unchanged.
```

### A08 — recDone / 轻托表达

```text
STAGE 05 ACTION 08 / recDone. Stand firmly with both feet stable. Extend both short oval arms forward in a gentle presenting or light-cupping gesture, as if offering encouragement, but show no object and no fingers. Eyes are happily open with a soft smile. Keep the five-petal flower fully open, sculptural and connected to the same leaf cradle.
```

### A09 — quizGood / 花开庆祝跳

```text
STAGE 05 ACTION 09 / quizGood. Show a small airborne turning jump: the compact body rotates slightly, both short oval arms angle diagonally outward, and both small feet clearly leave the floor. Keep all body parts inside frame and preserve the short limb lengths. Face has an open joyful embroidered smile and bright happy eyes. The fully open five-petal bloom remains attached and readable, never changing into a bud.
```

### A10 — quizFail / 低位欢迎

```text
STAGE 05 ACTION 10 / quizFail. Lower the center of gravity in a reassuring welcome pose. Open both short oval arms at a low angle beside the body, with a slight head tilt to one side. Eyes are soft and kind, mouth a tiny encouraging smile; no sadness or tears. Keep feet grounded and keep the five-petal flower fully open on its fixed crown root.
```

## 统一负面约束

```text
No second character, no extra arms or legs, no fingers or thumbs, no ears, tail, horns, hair, scarf, jewelry, hat, wand, cup, microphone, book, text, logo, watermark, border, collage, split panel, pedestal, ground plane, cast shadow, white or colored background, painted checkerboard, long fur, glossy plastic, ceramic, glass, metallic surface, stretched body, deformed face, missing feet, cropped body, closed bud, unopened flower, visible long stalk, pointed tall petals, giant flower or leaves covering the forehead.
```

## 生成结果

A01—A10 均已完成独立生成、目视检查、PNG 解码与原件／设计／运行三份哈希核对。十图均为 1254 × 1254 RGB PNG，无透明通道；A09 原件为 `exec-7a4b7a83-d457-47b5-a96d-2e96feea4abf.png`，A10 原件为 `exec-6145a614-71ac-4389-9f85-f01316b3b441.png`。
