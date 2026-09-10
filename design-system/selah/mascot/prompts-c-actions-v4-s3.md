# C 短绒五阶段动作素材：阶段 3（绿叶）

日期：2026-09-06。状态：已按公共 prompt 生成；本轮采用暖白 RGB 背景，不宣称透明。

## 参考与固定身份

- 唯一参考图：`design-system/selah/mascot/seed-c-s3-leaves-v3.png`（阶段 3 外形母版）。
- 用途：Selah 正式角色状态 PNG；每个动作是独立完整关键姿态，不是序列帧。
- 固定结构：奶油燕麦色短绒种子精灵，成熟圆润身体；深棕刺绣双眼和小弧线嘴；两只椭圆布手（无手指、无拇指）和两只小椭圆布脚；头顶恰好三片低矮、宽短、鼠尾草绿叶簇，叶根固定且相连，无披肩。
- 每图只改变动作姿态、重心和对应表情；不得增加叶、耳朵、帽子、长茎、披肩或道具；整只角色（含三叶、双手、双脚）完整入画，不裁切。

## 统一生成提示词

```text
Use case: identity-preserve. Deliver ONE complete full-body Selah C short-velour plush mascot in ONE clearly readable action key pose. Use the supplied image as the exact approved character/stage reference: keep its oat-cream very short directional velour, fabric seams, chocolate embroidered oval eyes, tiny stitched mouth, warm subtle blush, same body shape, two short oval fingerless plush arms and two stubby plush feet. Keep the stage's EXACT botanical construction, number, color, relative size and crown attachment; do not invent more leaves, a long stem, a cloak, ears, fingers, thumbs, tail or props. Material and face must stay recognizably the same toy across poses. Strong pose differences should come from real-looking plush limb articulation, stance, sitting, leaning and expression, not rubber deformation or camera changes.
OUTPUT: one square premium plush character state illustration, on a perfectly even WARM IVORY #FBF8F4 studio backdrop and floor matching the approved reference. Keep all FOUR EDGES of the square a uniform plain warm ivory, with the only contact shadow very local and soft beneath the feet. No pattern, no checkerboard, no gradients at the outside edges, no text, no labels, no icons, no scenery, no pedestal or props. This is the same clean warm studio styling as the reference image. Preserve all velour edge fibers naturally.
Square 512 x 512 composition, complete character including every botanical tip and all limbs inside with at least 10% empty margin on ALL sides. The standing character including growth is about 72-76% of the square height, centered horizontally, ground baseline near 84% height. Same physical toy/camera scale across this stage: seated/crouched poses remain lower in frame with more space above, NOT zoomed in to fill the whole square. Follow the mother reference's fabric, color and face construction exactly, soft upper-left studio lighting on the character. Vary articulated pose and expression, not body shape, material, features or head growth. ONE complete character, ONE action key pose, no contact sheet or strip. Highest priority: stage identity, correct short oval arms/two little feet, readable action, premium short velour.
```

## 十个动作追加段

动作顺序与运行时枚举固定为：`gentleFloat`、`blink`、`leafSway`、`listenEnter`、`listenPlaying`、`listenComplete`、`recRecording`、`recDone`、`quizGood`、`quizFail`。每次调用均在统一生成提示词末尾追加且只实现对应一项：

| 序号 | 动作 ID | 追加姿态要求 |
| --- | --- | --- |
| 01 | `gentleFloat` | 稳稳站立；两手放在身体后侧、仅部分可见；从容开放眼神；三叶低矮成簇不漂浮。 |
| 02 | `blink` | 稳坐并侧头；双眼轻闭；两手放在膝前；三叶根部固定、无披肩。 |
| 03 | `leafSway` | 身体侧向舒展；两臂不对称展开；三叶保持低矮原结构，只随头部产生柔和朝向变化，叶根不变。 |
| 04 | `listenEnter` | 坐姿向一侧转身；单手抬到脸旁示意听；另一手支撑身体；表情清醒专注。 |
| 05 | `listenPlaying` | 稳站；双手在腹前交叠；眼神专注；下巴稍抬；身体保持陪伴式安静。 |
| 06 | `listenComplete` | 一手贴胸；另一手放低；从容前倾并点头；满足的小笑，不夸张变形。 |
| 07 | `recRecording` | 前倾坐姿；一手贴胸、一手向前伸；嘴为小圆形张开；眼神专注；无道具或声波。 |
| 08 | `recDone` | 站立；一只手轻贴另一侧胸前；另一手放在身旁；开心微笑，双脚稳。 |
| 09 | `quizGood` | 侧迈一步；双臂大展开；抬头、弯眼欢喜；三叶保持原有三片低矮结构和叶根。 |
| 10 | `quizFail` | 坐稳；一只椭圆小布手轻拍身旁的空地、贴近地面；另一手在膝前；睁眼柔和邀请，不哭泣或惩罚。 |

## 生成记录

每张由内置 `image_gen` 独立调用一次；实际 prompt、原件路径、设计目标路径、运行副本路径、尺寸、PNG 色彩模式、字节数、SHA-256、复制哈希和目视审核结果写入 `seed-c-actions-v4-s3-assets.json`。原件保留，运行副本仅复制，不做脚本抠图、缩放或合成。实际输出为公共 prompt 指定的暖白 RGB PNG，不将 RGB 标为 RGBA。

| actionIndex | actionId | source 原件 | design 文件 | runtime 文件 |
| ---: | --- | --- | --- | --- |
| 1 | `gentleFloat` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-116380e5-c983-492e-9c8a-4ea4e13bdca9.png` | `seed-c-s3-a01-v4.png` | `PlushV4S3A01.png` |
| 2 | `blink` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-3f420d4d-8b29-47b3-9ed8-df1b6c222a11.png` | `seed-c-s3-a02-v4.png` | `PlushV4S3A02.png` |
| 3 | `leafSway` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-64b2f00c-59f9-4d4c-aeb9-d8b28578153d.png` | `seed-c-s3-a03-v4.png` | `PlushV4S3A03.png` |
| 4 | `listenEnter` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-e2baf372-00ed-4532-bf7d-3769fb3c22c0.png` | `seed-c-s3-a04-v4.png` | `PlushV4S3A04.png` |
| 5 | `listenPlaying` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-89ff6dd8-d40d-49df-b972-2ff48a355af6.png` | `seed-c-s3-a05-v4.png` | `PlushV4S3A05.png` |
| 6 | `listenComplete` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-efe52341-77cd-4202-98a4-d6cb914fd920.png` | `seed-c-s3-a06-v4.png` | `PlushV4S3A06.png` |
| 7 | `recRecording` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-7172e816-bc24-4aac-8e5e-e8bb5b146731.png` | `seed-c-s3-a07-v4.png` | `PlushV4S3A07.png` |
| 8 | `recDone` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-790714ea-eb6c-4a6f-831d-7e8e704311fa.png` | `seed-c-s3-a08-v4.png` | `PlushV4S3A08.png` |
| 9 | `quizGood` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-8adb40ee-e942-4c83-9d6b-5be507c6812b.png` | `seed-c-s3-a09-v4.png` | `PlushV4S3A09.png` |
| 10 | `quizFail` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-8148847e-0ead-404c-9333-e632aec47b4a.png` | `seed-c-s3-a10-v4.png` | `PlushV4S3A10.png` |
