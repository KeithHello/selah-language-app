# Seed 视觉修订：实际生成记录

日期：2026-09-05。

使用 Codex 内置 `image_gen` 图像编辑工具。全部步骤使用本地参考图；没有使用 CLI、外部 API、Python 绘图或后处理修改图片。Python／Pillow 仅用于读取尺寸、检查颜色通道与 PNG 完整性，最终复制文件与生成源文件的 SHA-256 一致。

以下保留实际提交的英文提示词。生成文件保留在默认目录，项目仅收录两张最终图；原始 C 版与已有运行素材没有覆盖。

## 1．标准形象生成

参考图，按传入顺序：

1. `pet-concept-C.png，右上角单芽角色为唯一形体依据。`

生成文件：`C:/Users/lhjjj/.codex/generated_images/01a06f03-2e69-7491-9670-1df1969f94ff/exec-512f1b58-df82-41c9-92d5-668261449952.png`。

核验与去向：此轮输出为 RGB，出现绘制的棋盘格，没有真正的透明通道；未作为最终交付。

实际提示词：

```text
Use case: identity-preserve.
Asset type: corrected canonical character artwork for the Selah language-learning app.
Input image 1 is the user's ORIGINAL Seed concept sheet and is the authoritative identity reference. Use ONLY its upper-right single-sprout character as the source of truth. The task is a fidelity correction, not a new mascot design.
Primary request: extract and faithfully refine that one original Seed character into a single high-resolution clean mascot on a genuinely transparent background. Preserve the original compact nearly round seed body, its subtle tapered crown, gently integrated side-arm bumps, tiny integrated rounded feet, original dark brown dot-eye spacing and low centered small U-shaped smile. Preserve the visible little top opening and one attached short green stem with one leaf leaning gently to the viewer's left. No growth-stage changes.
Rendering: same warm amber body and fresh soft green leaf as the original, softly illustrated 2D/2.5D volume, smooth matte finish with very subtle painterly grain. Subtle upper-left light, softly darker lower body. Very restrained cheek warmth. Do not add large glossy highlights, furry texture or realistic clay pores. The silhouette and facial feature positions must follow the reference, not become a tall potato, a humanoid toy or a perfect plastic sphere.
Composition: one front-facing complete character, centered in a square image, body upright and feet at a shared baseline, all body parts and the full sprout visible. Balanced modest transparent margins, character including sprout fills about 75 percent of the image height. No ground plane, no baked shadow, no background color, no checkerboard painted into the image.
Invariants: same species, proportions, eyes, mouth, limb attachment points, palette and sprout anatomy as the upper-right reference. Hands remain small side extensions, not balls attached to the belly. Feet remain tiny and attached, not large shoes or paws. Stem grows from the body, no floating leaf. Exactly two eyes, two tiny arms, two tiny feet, one stem, one leaf. No nose, eyebrows, fingers, ears, scarf, flower, additional character, text, logo, border or watermark.
```

## 2．清理标准图背景

参考图，按传入顺序：

1. `C:/Users/lhjjj/.codex/generated_images/01a06f03-2e69-7491-9670-1df1969f94ff/exec-512f1b58-df82-41c9-92d5-668261449952.png`

生成文件：`C:/Users/lhjjj/.codex/generated_images/01a06f03-2e69-7491-9670-1df1969f94ff/exec-1817f930-2dd8-43bb-b163-caa50f958f7e.png`。

核验与去向：采用暖白底展示图，最终复制为 seed-master-v2.png。它是有底色的展示母版，尚非透明运行素材。

实际提示词：

```text
Use case: precise-object-edit.
Input image 1 is the corrected canonical Selah Seed mascot. Preserve this exact character, silhouette, width and height, eye size and spacing, mouth, hands, feet, one attached stem and one leaf, pose, fine surface texture, colors and lighting without any redesign.
Make ONE change only: replace the entire white-and-gray checkerboard background with a perfectly uniform solid warm ivory #FBF8F4 background. The checkerboard is accidentally painted into the source; remove every trace of it. Do not create another checkerboard. No transparency is needed for this presentation master.
Keep the existing full-body framing and generous margins. Do not crop the leaf or feet. Do not add shadows, props, text, lines, labels, logos, watermarks or any other objects. Output one clean high-resolution square presentation master.
```

## 3．派生十状态

参考图，按传入顺序：

1. `C:/Users/lhjjj/.codex/generated_images/01a06f03-2e69-7491-9670-1df1969f94ff/exec-1817f930-2dd8-43bb-b163-caa50f958f7e.png`

生成文件：`C:/Users/lhjjj/.codex/generated_images/01a06f03-2e69-7491-9670-1df1969f94ff/exec-c19c37a0-bea9-41b9-b83a-c84355e27da3.png`。

核验与去向：第一次目视复核发现 04 和 07 两格因姿态倾斜而产生体型差异，继续定点修订。

实际提示词：

```text
Use case: identity-preserve.
Asset type: final mascot state comparison board for Selah, landscape, two rows of five equal cells, high resolution with readable Chinese labels.
Input image 1 is the FINAL canonical Seed mascot. It is the only character identity reference. Reuse this EXACT same mascot in every cell as though applying tiny changes to duplicates of one master illustration. Do not redesign each panel.
Scene/backdrop: uniform warm ivory #FBF8F4, very quiet editorial presentation, subtle warm-gray divider lines between cells. Small title centered above grid: "SELAH · SEED". Small subtitle: "十个状态，同一个角色". No other text except the exact labels below each figure.
Identity invariants in ALL TEN cells: identical compact body outline and body aspect ratio, same scale and camera angle, same amber fill and smooth matte illustrated shading, same two dark-brown dot eyes and spacing, same mouth placement, same tiny attached side-arm bumps and attached small feet, same one green stem growing from the same top opening and same ONE green leaf leaning left. No extra leaf or flower. Body must never stretch, become tall, inflate, flatten, change limb attachment points or change facial feature scale. Minimal surface texture so it remains clean at small UI size. This is one fixed growth stage, not a growth progression.
Layout: identical character size, horizontal center and baseline within every cell; full sprout and feet visible with generous margin. Tiny pose changes only. No large jumps, no arbitrary new body poses. No large cast shadows or perspective changes. No noses, eyebrows, fingers, added accessories, floating growth icons, particles, stars, hearts or question marks. Maintain calm adult-learning product tone.
Exact state order, left to right:
TOP ROW:
"01 待机" — canonical upright pose, open eyes and quiet smile.
"02 眨眼" — same exact pose; change ONLY eyes into two short gentle closed curves at the original eye positions.
"03 叶片轻摆" — same exact body and face; stem root stays fixed; leaf tip bends a few degrees while staying attached.
"04 准备聆听" — entire character tilts by only about 4 degrees to the viewer's left; rigid body keeps exact proportions; gaze attentive.
"05 播放中" — same upright proportions and open eyes, one tiny attached arm lifted slightly as a quiet listening response; no accessories.
BOTTOM ROW:
"06 聆听完成" — identical body silhouette, slightly warmer small closed smile and happy crescent eyes, same feet level.
"07 录音中" — canonical body with an attentive tiny forward inclination, open eyes, quiet smile; no open shouting mouth.
"08 录音完成" — same silhouette, soft crescent eyes and one small attached arm lifted just slightly.
"09 复习顺利" — warm smiling crescent eyes, same body and original mouth scale, a tiny friendly raised-hand response; no body stretching.
"10 再试一次" — calm open eyes with softened eyelids, the same kind U-shaped smile; upright stable body; no sad frown, no drooping plant, no tears.
Text: use a clear dark warm-gray Chinese sans-serif, each exact label centered below its figure, all labels completely visible and spelled exactly. Body silhouette consistency is more important than exaggerating differences between states. Preserve the reference character; produce ten state examples of that same character, not ten new character designs. No watermark.
```

## 4．修正两个状态的形体

参考图，按传入顺序：

1. `C:/Users/lhjjj/.codex/generated_images/01a06f03-2e69-7491-9670-1df1969f94ff/exec-c19c37a0-bea9-41b9-b83a-c84355e27da3.png`
2. `C:/Users/lhjjj/.codex/generated_images/01a06f03-2e69-7491-9670-1df1969f94ff/exec-1817f930-2dd8-43bb-b163-caa50f958f7e.png`

生成文件：`C:/Users/lhjjj/.codex/generated_images/01a06f03-2e69-7491-9670-1df1969f94ff/exec-dd8274ab-3520-473e-88ab-c900f630f3de.png`。

核验与去向：04 和 07 改为正面站姿。最终复制为 seed-states-v2.png；用于确认状态外观，不作为逐帧动画素材。

实际提示词：

```text
Use case: precise-object-edit, identity-preserve.
Input image 1 is the Selah Seed ten-state presentation board to correct.
Input image 2 is the canonical Seed character identity reference.
Make a small targeted correction to ONLY TWO characters in input image 1:
- Cell 04, top row fourth cell, labeled "04 准备聆听".
- Cell 07, bottom row second cell, labeled "07 录音中".
The characters in these two cells currently have a tilted/narrowed body. Replace their body pose with the same upright compact seed silhouette and exact width-to-height proportion as the character in cell 01. Match cell 01's body scale, height, roundness, eye spacing, mouth size, attached side-arm bumps, tiny feet, amber shading and camera view. Both eyes at the same height. Keep each character centered within its existing cell and feet on its existing row baseline.
Keep one attached green stem and ONE leaf, matching the canonical master. No detached plant, no new accessories, no growth-stage change.
For 04 show a very quiet attentive expression, open dark brown dot eyes and the canonical tiny U smile. For 07 show open attentive dot eyes and the same tiny quiet smile. Do not use body lean, perspective, stretching or narrowing to distinguish these two states. Their functional distinction is the label and later motion in the app.
Preserve all other EIGHT characters, all their poses, colors, leaf positions, expressions, the entire layout, ivory background, grid, heading, subtitle and Chinese labels exactly as in input image 1. Do not redesign the whole board. Do not add or remove text. Keep the full landscape two-by-five board and all text visible.
Highest priority: the corrected 04 and 07 bodies have the same proportions and frontal stance as 01, with original small limbs. No skinny potato shapes, no changing feet, no enlarged hands or eyes. Output the final corrected ten-state board.
```

## 最终使用边界

两张最终 PNG 都是 RGB 暖白底展示图。提示词中的“相同轮廓”是生成约束，不能解读为已经获得逐像素一致的骨骼／图层资产。运行时应使用一套角色图层与固定锚点生成表情、眨眼、叶片摆动和轻抬手，而不是轮播十张独立图像。本轮没有替换 Web 素材或验证实时动画。
