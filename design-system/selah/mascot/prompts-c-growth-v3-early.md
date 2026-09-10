# C 第一、第二阶段 V3：风格统一生成记录

日期：2026-09-05。主人认可第三至第五阶段 V3 效果，本轮以第三阶段为母版重做第一、第二阶段静态外形，组成五阶段对照。第一阶段十种已确认动作和第三至第五阶段原图保留。

使用内置 `image_gen`，每个阶段单独调用。唯一参考是已目视检查的 `seed-c-s3-leaves-v3.png`，不将旧五阶段总览输入模型，避免旧长叶造型影响输出。

## 共同提示词

```text
Use case: identity-preserve. Asset type: premium short-velour mascot growth-stage concept, one standalone full-body character, square image, no collage, no text.
Input image: the selected Stage 03 leaf-stage Selah C plush companion. This is the identity, textile, color, face, limb construction, neutral pose, camera and lighting master. Design an EARLIER GROWTH STAGE in the EXACT SAME plush family so the result can be placed next to that image and its bud/flower siblings as one coherent series.
Preserve the reference's oat-cream VERY SHORT VELOUR with visible soft directional loops, refined plush seam structure, dark chocolate embroidered oval eyes and tiny restrained eye catchlights, curved stitched little smile, subtle peach cheek blush, short smooth oval fingerless arms and two little rounded feet. Same gently bottom-heavy seed body, same placement and proportions of facial features relative to body, same warm expression. Keep exactly two arms and two feet. No fingers, thumbs, ears, tail, accessories or props.
Calm FRONT-FACING neutral standing pose, both feet flat, arms naturally resting at sides, open eyes. The developmental distinction comes from the specified top growth and modest youthful body proportions, never from changing the character, camera, material, pose or color. Same warm ivory seamless studio background and floor as reference, diffuse upper-left softbox, subtle contact shadow, same straight-on product photograph feeling. Match the supplied image's square framing; baseline of the feet at about 83% of canvas height, centered horizontally, generous ivory margins and all botanical growth fully visible. Do NOT zoom in to fill the frame for a smaller stage. Same apparent physical camera scale across this series.
Plant parts use the reference's muted sage/soft olive short velour, rounded softly sewn edges and delicate seam veins, growing directly from a single small crown root on a mostly hidden VERY SHORT stem. Keep the full cream forehead exposed. No long fur, shaggy hair, glossy plastic, glass, ceramic, leaf cape, scarf, tall stalk, long rabbit-ear-shaped leaves, forehead hat, blossom, flower bud, extra leaves, floating icons, text, labels, watermark, checkerboard, frame or pedestal. Deliver one beautiful tactile collectible, coherent with the supplied stage-three master.
```

## 第一阶段

```text
STAGE 01 / FIRST MEETING / TINY FOLDED SPROUT.
Make a slightly smaller and rounder young version of the reference seed: about 88-90% of the mature reference body height and about 92% of its width, a plump soft base with the SAME sewn construction, eye style, relative face placement, arm/foot shapes and calm standing pose. Keep feet on the same baseline and background composition; do not change camera scale. It must look like a younger member of the same exact product family, not a different chibi species.
Replace ALL THREE mature leaves with EXACTLY ONE small, thick, partly folded tender sage-green sprout. This is a SINGLE leaf whose two edges gently curl inward around a subtle central seam, forming a soft folded teardrop, rounded at the tip, leaning slightly sideways, not a tall vertical pointed spear. No separate second leaf. Height above the scalp about 12-15% of the cream body height, width about 14-17% of body width. Short naturally attached root at the upper crown, with no visible long stem. A simple small folded sprout silhouette, youthful and restrained, clear even in a thumbnail. Absolutely NO paired leaves or mature leaf cluster.
```

## 第二阶段

```text
STAGE 02 / SPROUTING / TWO UNFURLING LEAVES.
Use a body slightly more developed than Stage 01, about 95% of the mature reference body height and 97% of its width. Keep the same gently pear-shaped oat-cream body construction, relative face placement, arm/foot shapes and calm neutral pose as the reference. Feet stay on the same baseline; do not change camera scale, exposure or material.
Replace the reference's mature THREE-leaf cluster with EXACTLY TWO short broad unfurling sage velour leaves from one tiny crown root. They are softly cupped young seed leaves, spreading sideways in a low gently asymmetrical arc. One slightly wider leaf reaches outward toward viewer-left, a slightly smaller leaf opens outward and a little upward toward viewer-right. Both tips rounded and subtly curled, with a simple fine sewn vein and tiny olive/sage color variation. The leaves have substantial soft fabric thickness like the reference. Total paired leaf span about 42-46% of cream body width, maximum leaf rise about 15-18% of body height. The two-leaf outline is clearly wider and more open than a single folded sprout, but noticeably simpler and narrower than the mature three-leaf cluster in the reference. Low near-invisible attached stem, leaves meet naturally at the crown. No tall V, no long upright bunny ears, no extra third leaf, no center spike, no leafy hood.
```

## 2026-09-06 交付与核验

第一、第二阶段各通过一次内置 `image_gen` 调用生成；最终文件为 `seed-c-s1-first-sprout-v3.png` 与 `seed-c-s2-paired-leaves-v3.png`，均为 1254 × 1254 RGB PNG。原件保留，工作区副本未经脚本缩放、裁切、变形或抠图。

目视：第一阶段是一枚卷边折芽，圆润幼年身体与第三阶段属于同一短绒角色；第二阶段是两片宽短叶横向展开，无额外第三片叶、长茎或叶披肩，脸和四肢完整。比例数值是设计目标，两图属于外形概念稿，不是像素配准的动画帧。

五张均使用 Windows 自带 `System.Drawing.Bitmap` 完成 PNG 解码，并核对文件签名、尺寸、色彩类型及 SHA-256；五个哈希各不相同，副本与原件一致。第三至第五阶段及第一阶段十动作原图与既有哈希记录一致。五阶段整体待主人审阅，未替换网页运行素材。

原件路径、尺寸、字节数与逐张 SHA-256 见 [五阶段资产清单](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-growth-v3-all-assets.json) ，原图对照见 [五阶段统一稿](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-growth-v3-all-review.md) 。
