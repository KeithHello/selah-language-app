# C 第一阶段十动作 V4：生成记录

日期：2026-09-06。以 `seed-c-s1-first-sprout-v3.png` 为唯一外观母版，保留已认可的十种姿态意图。公共提示词与 RGB 背景决策见 `prompts-c-actions-v4-common.md`。使用内置 image_gen；每图独立调用，原件保留。

## 阶段不变量

```text
STAGE 1: the small round young seed from the reference, EXACTLY ONE tiny folded sage sprout (one leaf curled inward, NOT two separate leaves). No additional foliage or blossom. Keep youthful round proportions and the sprout small.
```

## 实际动作提示词（追加到公共提示词与阶段不变量后）

### 01 · 自然待机

```text
ACTION 01 / gentleFloat: Stand front-facing with two feet grounded, both oval arms resting slightly away from the body, open eyes and a tiny calm smile. Reproduce the approved neutral pose and warm ivory scene.
```

### 02 · 害羞眨眼

```text
ACTION 02 / blink: Sit low in a shy compact curled pose, both small oval hands held gently at the cheeks, both eyes softly CLOSED in a gentle curved embroidered expression, tiny closed smile. Two small feet visible in front, body still natural plump plush, single folded sprout unchanged.
```

### 03 · 舒展叶摆

```text
ACTION 03 / leafSway: Stand balanced on ONE grounded little foot with the other foot visibly lifted sideways, lean the whole body diagonally in a playful stretch. One short arm up diagonally and the other extended outward for balance, open eyes, gentle smile. Single folded sprout tilts with the head but stays the same structure. Clear asymmetric full-body silhouette.
```

### 04 · 侧耳准备听

```text
ACTION 04 / listenEnter: A noticeable listening pose: body leans forward and gently sideways in a three-quarter direction, one oval hand raised beside the face as if cupping an imaginary ear, other arm relaxed slightly behind. Both feet grounded, eyes open and attentive, mouth tiny and closed. No actual ears or ear accessory.
```

### 05 · 坐稳认真听

```text
ACTION 05 / listenPlaying: Sit firmly with both little feet pointing forward and both small hands resting together near the knees in front of the lower belly. Body upright, head slightly lifted, both eyes wide attentive, tiny quiet closed smile. Stable rounded sitting silhouette, clearly different from standing or leaning.
```

### 06 · 点头致意

```text
ACTION 06 / listenComplete: A small polite bow: stand on two grounded feet, tilt body and head forward, both short oval hands overlap gently at the lower belly. Eyes softly CLOSED in content curved shapes, small grateful stitched smile. Strongly readable bow, no extra fingers and no elongated arms.
```

### 07 · 陪你开口

```text
ACTION 07 / recRecording: Stand upright, BOTH short oval hands beside the mouth like a small megaphone gesture without fingers, mouth open in a small embroidered O, eyes open and alert, encourage the user to speak. Feet grounded. The hands stay short and attached at their normal sides; do not stretch them into long arms.
```

### 08 · 轻轻拍手

```text
ACTION 08 / recDone: Stand with a slight three-quarter body turn, one little foot drawn back. BOTH oval hands meet together in front of the chest in a gentle CLAP. Eyes open and bright, happy tiny smile. Exactly two clearly separate plush oval hands, no fingers, palms or human anatomy.
```

### 09 · 开心小跳

```text
ACTION 09 / quizGood: A happy little JUMP captured in mid-air: both tiny feet visibly off the floor, arms lifted diagonally outward in a joyful V while keeping short plush limb lengths. Eyes curve happily, broad cheerful embroidered smile. Clear air gap under the feet and a small soft local floor shadow. Same small folded sprout remains attached.
```

### 10 · 伸手再试一次

```text
ACTION 10 / quizFail: A warm invitation to try again: crouch/sit LOW with knees/feet forward, lean gently toward viewer, one short smooth OVAL hand reaches outward at low chest height, other hand rests against the chest. Both eyes OPEN, soft reassuring small smile. Hands remain simple rounded stuffed nubs with no thumb, no fingers and no curling human gesture. Clearly different from clapping, a bow and standing.
```

## 当前核验

01—10 均已完成生成、逐张目视、PNG 解码及原件／设计／运行三份复制哈希核对。十图均为 1254 × 1254 RGB PNG，无真实透明通道；十个 SHA-256 值互不重复。
