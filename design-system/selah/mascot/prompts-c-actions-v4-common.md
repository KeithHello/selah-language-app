# C 五阶段五十动作 V4：公共生成约束

日期：2026-09-06。五阶段 V3 外形已确认；每个阶段仅输入自己的已确认母版，分别生成十个动作。原始文件与运行副本必须一致，实际模式以文件头和解码为准。

## 背景决策

第一阶段待机透明试稿 `exec-5aa96980-c2dd-4570-b35c-8bf6f6e76396.png` 实测 colorType=2、RGB、角落 alpha=255；棋盘格是图片像素，弃用该输出，不接入程序。本轮采用已获认可的暖白背景完整角色状态图，页面用完整图片展示与柔和背景衔接。透明分层素材未完成，不能将本轮 RGB 状态图标作透明 PNG。

## 实际公共提示词

```text
Use case: identity-preserve. Deliver ONE complete full-body Selah C short-velour plush mascot in ONE clearly readable action key pose. Use the supplied image as the exact approved character/stage reference: keep its oat-cream very short directional velour, fabric seams, chocolate embroidered oval eyes, tiny stitched mouth, warm subtle blush, same body shape, two short oval fingerless plush arms and two stubby plush feet. Keep the stage's EXACT botanical construction, number, color, relative size and crown attachment; do not invent more leaves, a long stem, a cloak, ears, fingers, thumbs, tail or props. Material and face must stay recognizably the same toy across poses. Strong pose differences should come from real-looking plush limb articulation, stance, sitting, leaning and expression, not rubber deformation or camera changes.
OUTPUT: one square premium plush character state illustration, on a perfectly even WARM IVORY #FBF8F4 studio backdrop and floor matching the approved reference. Keep all FOUR EDGES of the square a uniform plain warm ivory, with the only contact shadow very local and soft beneath the feet. No pattern, no checkerboard, no gradients at the outside edges, no text, no labels, no icons, no scenery, no pedestal or props. This is the same clean warm studio styling as the reference image. Preserve all velour edge fibers naturally.
Square 512 x 512 composition, complete character including every botanical tip and all limbs inside with at least 10% empty margin on ALL sides. The standing character including growth is about 72-76% of the square height, centered horizontally, ground baseline near 84% height. Same physical toy/camera scale across this stage: seated/crouched poses remain lower in frame with more space above, NOT zoomed in to fill the whole square. Follow the mother reference's fabric, color and face construction exactly, soft upper-left studio lighting on the character. Vary articulated pose and expression, not body shape, material, features or head growth. ONE complete character, ONE action key pose, no contact sheet or strip. Highest priority: stage identity, correct short oval arms/two little feet, readable action, premium short velour.
```

在公共提示词后追加本阶段植物／身体不变量和明确动作姿态。每图一次内置 `image_gen` 调用，每批不超过四张；保存真实提示词、原件路径、尺寸、色彩模式、哈希及目视检查，保留原件。手臂只做布偶关节式动作，无手指、拇指或拉长胳膊，花叶不跨阶段改变。每图至少留 10% 空白边缘，确保 Web 小尺寸和动作过渡不裁切。
