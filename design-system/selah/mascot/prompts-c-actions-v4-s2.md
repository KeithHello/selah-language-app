# C 短绒五阶段动作素材：阶段 2（萌芽）

日期：2026-09-06。状态：已按公共 prompt 生成；本轮采用暖白 RGB 背景，不宣称透明。

## 参考与固定身份

- 唯一参考图：`design-system/selah/mascot/seed-c-s2-paired-leaves-v3.png`（阶段 2 外形母版）。
- 用途：Selah 正式角色状态 PNG；每个动作是独立完整关键姿态，不是序列帧。
- 固定结构：奶油燕麦色短绒种子精灵，圆润下部略宽；深棕刺绣双眼和小弧线嘴；两只椭圆布手（无手指、无拇指）和两只小椭圆布脚；头顶恰好两片低矮、宽短、鼠尾草绿双叶，叶根固定且相连。
- 每图只改变动作姿态、重心和对应表情；不得增加叶、耳朵、帽子、长茎、披肩或道具；整只角色（含双叶、双手、双脚）完整入画，不裁切。

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
| 01 | `gentleFloat` | 一只脚轻迈前；单臂做小幅招呼；双眼睁开，友好小笑；双叶仍低矮并固定于同一叶根。 |
| 02 | `blink` | 低身坐姿；一只眼轻眨、另一只眼保持睁开；一臂停在挥手高度；双叶结构和叶根不变。 |
| 03 | `leafSway` | 一脚支撑小转身；两臂一前一后；双叶只做柔和朝向变化，叶根与连接处固定，不增叶。 |
| 04 | `listenEnter` | 向前迈一步；摊开两只小布手；侧头向前靠近，表达准备倾听；脸保持清醒专注。 |
| 05 | `listenPlaying` | 坐姿，双脚朝前；一脚轻抬；两手自然旁放；睁眼认真听，动作安静稳定。 |
| 06 | `listenComplete` | 抬单臂致意；另一手放在腹前；身体微倾，眼神温和并带满足小笑。 |
| 07 | `recRecording` | 一手靠近小嘴；另一手向前鼓励；嘴为小圆形张开，双眼清醒专注；不得画实时声波或道具。 |
| 08 | `recDone` | 双手在胸前拍合；两脚站稳；轻点头，开心但克制地笑；双叶仍是同一对低矮双叶。 |
| 09 | `quizGood` | 转身迈步庆祝；双臂张开；其中一脚离地；明显开心笑；保持全身、双叶完整入画。 |
| 10 | `quizFail` | 侧身低重心；向前招一只手；另一手放在身体侧面；表情温柔、邀请再试，不哭泣、不萎蔫、不惩罚。 |

## 生成记录

每张由内置 `image_gen` 独立调用一次；实际 prompt、原件路径、设计目标路径、运行副本路径、尺寸、PNG 色彩模式、字节数、SHA-256、复制哈希和目视审核结果写入 `seed-c-actions-v4-s2-assets.json`。原件保留，运行副本仅复制，不做脚本抠图、缩放或合成。实际输出为公共 prompt 指定的暖白 RGB PNG，不将 RGB 标为 RGBA。

| actionIndex | actionId | source 原件 | design 文件 | runtime 文件 |
| ---: | --- | --- | --- | --- |
| 1 | `gentleFloat` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-8bb456ac-5a18-4772-be71-2fcc70abffdd.png` | `seed-c-s2-a01-v4.png` | `PlushV4S2A01.png` |
| 2 | `blink` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-ba5110de-1b41-4292-ba5f-1383bb62864f.png` | `seed-c-s2-a02-v4.png` | `PlushV4S2A02.png` |
| 3 | `leafSway` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-5da88a6b-4893-4b19-8e78-0b0fd207edca.png` | `seed-c-s2-a03-v4.png` | `PlushV4S2A03.png` |
| 4 | `listenEnter` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-eda05189-0a5c-4708-b682-4b5cbf904d16.png` | `seed-c-s2-a04-v4.png` | `PlushV4S2A04.png` |
| 5 | `listenPlaying` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-918bda92-6a69-4146-bfbf-8037a3d5a8eb.png` | `seed-c-s2-a05-v4.png` | `PlushV4S2A05.png` |
| 6 | `listenComplete` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-30972eee-6b1d-4c9e-910d-8dc01a8e01e7.png` | `seed-c-s2-a06-v4.png` | `PlushV4S2A06.png` |
| 7 | `recRecording` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-bd7813db-a37f-4ca0-a69e-213bf4032197.png` | `seed-c-s2-a07-v4.png` | `PlushV4S2A07.png` |
| 8 | `recDone` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-a6077c96-17b6-4418-8ca3-437e37526590.png` | `seed-c-s2-a08-v4.png` | `PlushV4S2A08.png` |
| 9 | `quizGood` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-b5d172a4-45b3-4f4a-a061-d66c571fd152.png` | `seed-c-s2-a09-v4.png` | `PlushV4S2A09.png` |
| 10 | `quizFail` | `C:/Users/lhjjj/.codex/generated_images/01a0722f-3752-7830-9303-01388752eefb/exec-3a8a04f3-2ebd-43af-9c14-00beb1d76cd4.png` | `seed-c-s2-a10-v4.png` | `PlushV4S2A10.png` |
