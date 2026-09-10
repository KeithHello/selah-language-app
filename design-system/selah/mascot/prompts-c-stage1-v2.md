# C 第一阶段十动作 V2：图像生成记录

日期：2026-09-05。使用内置 `image_gen`，每张独立调用；没有使用 CLI／外部图像 API，没有脚本抠图。本轮是带暖白背景的关键姿态设计稿，不要求透明通道，不作为已经完成的动画序列。

## 参考与保存约定

- 已选身份／材质参考：`seed-v4-c-soft-plush.png` 左侧大角色。
- 第一张产生阶段一统一母版；其余九张以该母版为直接参考，保持阶段结构和身份。
- 十张分别保存为 `seed-c-s1-XX-<action>-v2.png`，保留历史版本。
- 五阶段外形另用一张对照图说明，其余四十动作没有生成。
- 生成结果经目视、PNG 完整性、尺寸／色彩模式和复制 SHA-256 核对后补充下方记录。

## 每次调用的共同提示词

```text
Use case: stylized-concept. Create ONE premium 3D plush mascot key-pose concept image, square 1024 x 1024, not a collage. Image 1 is the approved C soft-plush identity/material reference; when a stage-one master is supplied, preserve that exact character. Selah is a tiny oat-cream seed sprite, rounded low-centered pear/bean body, soft very short velour with subtle directional fibers and restrained sewn seams, dark chocolate embroidered eyes and mouth, faint blush, exactly two little mitten-like plush arms and two stubby feet. It is a sewn cloth collectible, NOT plastic, ceramic, resin or a hairy animal. STAGE ONE ONLY: one short folded sage-green sprout at the crown, small and upright/curved, no open large leaf, no extra leaves, flower, leaf cape, costume, ears or tail. Preserve the same limb length, face placement, body proportions and fabric in every pose. Arms may rotate and bend naturally as articulated soft plush arms; feet stay attached. Clear readable pose silhouette at small UI size. Eye-level camera, mild three-quarter perspective only when specified, soft diffuse studio light from upper left, detailed tactile fabric and gentle contact shadow. Seamless warm ivory #FBF8F4 floor and background, no horizon, generous identical margins, entire sprout/hands/feet in frame. Character body approximately 48% of image height in a standing pose, same physical camera scale in every image; allow space above for raised hands and jumps. No text, letters, numbers, labels, panels, props, floating symbols, motion streaks, watermarks or checkerboard. This is a review key pose, not an animation sprite sheet. Keep the original character recognizable while creating the exact action below.
```

## 01 · 自然待机

参考：`seed-v4-c-soft-plush.png`。

```text
ACTION 01 / calm idle, stage-one master: front-facing natural standing posture, feet resting clearly on the floor, arms relaxed slightly away from its sides so two little hands read clearly, open embroidered oval eyes, tiny curved friendly smile. A young slightly rounder version of the reference plush with only one small CLOSED/FOLDED sprout (leaf height about 12% of body height). Quiet alert curiosity. Do not reproduce the reference contact sheet, large open leaf, Chinese labels, or multiple characters. Deliver only one complete standing character.
```

## 02 · 害羞眨眼

共同提示词加以下动作段，参考第一阶段 01 母版：

```text
ACTION 02 / shy blink: the SAME stage-one plush master now sits in a visibly tucked crouch, both feet forward on the floor, knees tucked close to its round belly; both tiny mitten hands are gently pressed against its two cheeks. Both eyes CLOSED in relaxed embroidered arcs, small shy smile, head/body bowed very slightly. Make a compact triangular/cuddled silhouette clearly different from standing; head sprout remains one small folded leaf. It looks bashful and comfortable, not sleepy, sad or crying.
```

## 03 · 舒展叶摆

共同提示词加以下动作段，参考第一阶段 01 母版：

```text
ACTION 03 / playful stretch with sprout sway: the SAME plush balances with its viewer-right foot firmly planted, the other foot lifted sideways just a little. Entire bean-shaped body leans clearly 18 degrees toward viewer-left. Its viewer-right arm reaches upward and outward, its other arm stretches lower toward viewer-left, producing a clear diagonal stretch silhouette. Open bright embroidered eyes looking up toward the raised hand, joyful small smile. The same single short folded sprout bends gently in the direction opposite the body lean, attached at crown. Cloth body preserves its volume and limb length; no long arms, no detaching sprout. NOT a two-feet airborne jump.
```

## 04 · 侧耳准备听

共同提示词加以下动作段，参考第一阶段 01 母版：

```text
ACTION 04 / ready to listen: SAME plush in a distinct three-quarter pose facing viewer-left, feet firmly planted apart, torso leaning forward noticeably as if moving closer to hear. One small mitten is raised beside the side of the face in a cupped listening gesture (do NOT add an ear); the other small arm is swept slightly behind its side. Eyes open and attentive, closed tiny smile. Its silhouette must clearly communicate side-leaning and one raised hand, not upright idle. Same one small folded sprout and body construction.
```

## 05 · 坐稳认真听

共同提示词加以下动作段，参考第一阶段 01 母版：

```text
ACTION 05 / sustained attentive listening: SAME plush is seated upright directly on its round base, both little feet projecting forward clearly with rounded soles visible, both mitten hands resting together low at the knees/belly. Body front-facing, chin/gaze raised slightly toward viewer-right, embroidered eyes open and focused, tiny relaxed closed mouth. Distinct broad-bottom seated silhouette, calm steady posture; neither hand near the cheeks or mouth. Same short folded sprout. No headphones or devices; listening should read through seated calm and upward attention.
```

## 06 · 点头致意

共同提示词加以下动作段，参考第一阶段 01 母版：

```text
ACTION 06 / listening completed, grateful nod: SAME plush standing on two planted feet but in a clear gentle forward bow of about 20 degrees. Both small mitten hands overlap neatly in front of the LOWER belly. Eyes CLOSED as happy upward crescent embroidered arcs; small contented smile. Show the top seam and crown slightly because of the bow, folded sprout tilted forward WITH its crown attachment. Full body retains volume, not squashed. This is a courteous one-time bow, not a jump, clap, sleep, or shame. No hands beside the face.
```

## 07 · 陪你开口

共同提示词加以下动作段，参考第一阶段 01 母版：

```text
ACTION 07 / encouraging speech recording: SAME plush standing upright with feet apart, BOTH small mitten hands lifted symmetrically around the sides of its mouth like a tiny speaking funnel, elbows comfortably outward. Eyes open wide and awake, mouth a small clearly visible round embroidered O framed by the hands, friendly expression. The hands sit below its eyes and must not hide its face. Distinct high-hands silhouette. Same exact small closed folded sprout. No microphone, devices, sound symbols or speech bubble. This is a single state key pose, not claiming audio-driven lip sync.
```

## 08 · 轻轻拍手

共同提示词加以下动作段，参考第一阶段 01 母版：

```text
ACTION 08 / speech captured, one happy clap: SAME plush in a mild three-quarter view facing viewer-right, BOTH mitten hands pressed together in a clear mid-clap at UPPER chest level, well below the mouth. Eyes OPEN with happy friendly expression, mouth a joyful curved smile. One foot is on the ground supporting it, the other drawn slightly back while still near the ground; body upright, not bowing or jumping. Show two hands meeting instead of merged deformed limb. Same short folded sprout. No props, checkmarks or symbols.
```

## 09 · 开心小跳

共同提示词加以下动作段，参考第一阶段 01 母版：

```text
ACTION 09 / successful practice, joyful hop at apex: SAME plush clearly airborne a short distance above the floor, BOTH feet fully separated from its soft shadow, knees/feet slightly tucked. BOTH small arms spread UPWARD diagonally in an open V (natural stubby plush arm length, not long human arms). Embroidered eyes curved into smiling crescents, broad joyful open smile. Body volume and young round pear shape preserved with only physically gentle cloth flex, no balloon swelling or rubber stretching. Same single small folded sage sprout bobs above the crown, securely attached. This must be the most energetic key pose of the set and unmistakably different from the grounded stretch, clap or bow. No confetti, stars, text or extra props.
```

## 10 · 伸手再试一次

共同提示词加以下动作段，参考第一阶段 01 母版：

```text
ACTION 10 / gently invite another try: SAME plush in a low grounded half-kneeling/seated lunge, its viewer-left foot forward while the other foot tucked under its body, weight lowered. One short mitten arm extends forward toward the viewer-left as a welcoming offered hand, palm shape visible with no human fingers; its other mitten rests over its own chest. Eyes OPEN, softly arched attentive brow/upper-eye expression, compassionate small asymmetric smile, head/body tilted slightly toward the offered hand. Clear one-hand-reaching silhouette and low center of gravity. Encouraging, patient and confident, NEVER sad, tearful, wilted, disappointed or punitive. Same intact short folded sprout and seed identity; no props or symbols.
```

## 输出与审核

十张第一阶段设计图与一张五阶段对照图已生成、目视检查并归档，仍待主人确认。10 张动作图均为 1254 × 1254 RGB PNG；五阶段对照为 1672 × 941 RGB PNG。PNG 解析／完整性、11 张各不相同的 SHA-256，以及输出原件与项目副本哈希一致性检查全部通过。

| 图号 | 文件 | 目视核对 |
| --- | --- | --- |
| 1 | `seed-c-s1-01-idle-v2.png` | 基准站姿、双手双脚完整，小芽叶与短绒身份清晰。 |
| 2 | `seed-c-s1-02-blink-v2.png` | 双脚朝前坐姿、双手贴脸、闭眼；区别于待机和坐听。 |
| 3 | `seed-c-s1-03-leaf-sway-v2.png` | 斜向伸展、单脚支撑、另一脚抬起；区别于双脚腾空。 |
| 4 | `seed-c-s1-04-listen-enter-v2.png` | 侧倾与一手贴脸侧，双脚仍着地；没有新增耳朵。 |
| 5 | `seed-c-s1-05-listen-playing-v2.png` | 双脚朝前坐稳、手置膝前、眼睛睁开；区别于蜷坐眨眼。 |
| 6 | `seed-c-s1-06-listen-complete-v2.png` | 前倾致意、手在腹前、双眼弯笑；区别于高位拍手。 |
| 7 | `seed-c-s1-07-rec-recording-v2.png` | 双手靠近嘴侧、圆口、睁眼；没有设备或悬浮图标。 |
| 8 | `seed-c-s1-08-rec-done-v2.png` | 站姿胸前拍手、睁眼笑；区别于弯眼鞠躬和腾空庆祝。 |
| 9 | `seed-c-s1-09-quiz-good-v2.png` | 两脚离地、双臂向上、开心笑，落影与身体分离。 |
| 10 | `seed-c-s1-10-quiz-retry-v2.png` | 低重心邀请、手贴胸；局部修订后去除额外拇指和弯手形。 |
| growth | `seed-c-growth-v2.png` | 五个阶段标注正确；单芽、双叶、叶冠、闭苞、五瓣开花有明确剪影差异。 |

所有实际来源、大小、色彩模式和哈希见 `seed-c-stage1-v2-assets.json`。第一阶段十图为静态关键姿态，不是严格配准的逐帧序列；微小相机／软织物体积差异仍需在动画建模或绑定时统一。当前没有修改、构建或验收网页新动画；不把生成图当作 50 动作已经实现。

## 10 号局部修订

初稿手部出现独立拇指和 C 形弯手，与同组椭圆小布手不一致。仅修订两手轮廓，其余姿态、表情、身体和背景保持；原始初稿保留在工具默认输出目录，不作为最终第十张交付。

```text
Use case: precise-object-edit. Image 1 is the EDIT TARGET: the stage-one cream short-velour Selah seed in its low, one-hand-offered encouraging pose. Image 2 is only the hand-shape/material identity reference (neutral standing master). Make ONE precise local correction in Image 1: replace BOTH hands with the same smooth simple oval, fingerless plush mitten paddles as the standing master. Remove the separate little thumb nub sticking from the TOP of the outstretched hand on viewer-left, and remove the pronounced C-shaped/human hand curl from the hand over the chest on viewer-right. Two rounded oval plush hands only, NO fingers, NO thumbs, NO cuffs, no palm lines. Preserve the exact current offered-hand direction, lowered asymmetric feet pose, arm attachment points, one hand forward and the other resting on the chest. Keep the entire rest of Image 1 unchanged: pear body proportions, crown sprout size and direction, embroidered expressive eyes, gentle raised brows, smile, blush, short velour, seams, lighting, background, contact shadow, camera, framing and figure scale. Do not turn the pose into standing idle or put both hands together. Preserve gentle invitation and warmth. Single character, square image, no text or symbols.
```

## 五阶段外形对照图提示词

参考：第一阶段 01 母版。

```text
Use case: stylized-concept / character evolution design sheet. Create ONE landscape 1920 x 1080 premium design review image with exactly FIVE full-body plush seed sprites arranged in a single clean evenly spaced left-to-right row, on one shared ground baseline, plenty of room above all plant structures. The supplied image is the precise STAGE ONE identity reference, not a pose/layout to repeat five times. Preserve the same friendly face family, oat-cream very-short velour textile, dark brown embroidered eyes/smile, blush, sewn seams, exactly two small mitten arms and two stubby feet. Tactile sophisticated soft-plush product rendering, warm ivory #FBF8F4 seamless background, gentle diffuse light and small natural contact shadows, no checkerboard. The user rejected barely different stages: make the FIVE SILHOUETTES AND PLANT STRUCTURES IMMEDIATELY DIFFERENT at thumbnail size, not merely larger or smaller copies and not tiny icons attached to the same body.

Stage 1 at far left, label "01 初见": the reference tiny round low-centered seed body, only ONE short folded sage-green sprout, about 20% of body height, no other leaves or cape or flower. Calm standing posture.
Stage 2, label "02 萌芽": slightly taller youthful seed body and TWO LARGE open cotyledon leaves above the crown, forming an unmistakable open V silhouette, each leaf roughly 40% of body height; sprout is an actual plant, not bunny ears. One little hand raised in friendly curiosity. NO flowers.
Stage 3, label "03 绿叶": a slightly taller, balanced mature pear body. THREE generous sage/olive leaves fan from the crown as a distinct leafy crown; TWO shorter leaves growing from behind the upper body fold over the sides as a botanical leaf mantle, leaving the face and belly fully visible. Stable confident posture with arms relaxed out. Leaves have stitched veins, all plant structures share connected stems, NO flowers.
Stage 4, label "04 花苞": a rounded mature cream body with a clearly visible sage leafy mantle and ONE LARGE CLOSED coral-blush fabric flower BUD on a short attached crown stem. The closed oval bud must be substantial, about 45% of body height, its four/five folded petal seams readable, supported by two green sepals. The head silhouette is now a flower bud, NOT just another green leaf tuft. Arms slightly held forward with gentle anticipation. Do not open the flower yet.
Stage 5 at far right, label "05 开花": the same grown companion with a broad leaf mantle, upright relaxed body, and a fully OPEN FIVE-PETAL blush-cream PLUSH FLOWER attached on a short crown stem, clearly above its face. Broad rounded petals and a warm golden embroidered/felt center, flower width about 75% of body width, strong floral silhouette. Arms open in a welcoming gesture. It must read as an actual flower growing from its head, NOT a hat, animal ears or a flower-shaped face. The seed's original brown eyes and smile remain below the flower.

Keep body scale progression gentle, approximately 1.00, 1.08, 1.12, 1.15, 1.18; differences must come primarily from structural shape and leaves/bud/bloom, not a uniform scale trick. All five share one premium plush material family, cream bodies, sage greens and restrained coral-pink only for bud/flower. No mushrooms, resin, amber, glass, fur, extra limbs, floating plant parts, props, decorative stars, arrows, infographic clutter, scenery, additional characters or state thumbnails. Clear generous gaps between five characters. Header exact Chinese text "C 短绒织物 · 五阶段外形提案" and small subtitle "初见 → 萌芽 → 绿叶 → 花苞 → 开花". Put the five exact stage labels centered below their corresponding figures, elegant dark warm-brown type, restrained and legible. This is a static concept proposal for review, not a screenshot or implemented app.
```
