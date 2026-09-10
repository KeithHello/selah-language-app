# C 第三至第五阶段 V3：生成与核验记录

日期：2026-09-05。第一阶段十动作已获主人认可，本轮只生成第三、第四、第五阶段同站姿外形稿，不修改网页或动作代码。使用内置 `image_gen`；参考第一阶段母版生成第三阶段，再以第三阶段作为后两张的身体和布光参考。

## 共同提示词

```text
Use case: stylized-concept, premium plush character product design. Deliver ONE single-character full-body design image, square 1024 x 1024, no collage, no text. The reference image supplies the approved Selah C plush identity, face, fabric and neutral standing pose. Preserve its oat-cream very short velour body, tactile tiny directional fibers, refined seams, chocolate brown embroidered oval eyes with a restrained catchlight, little embroidered curved smile, soft warm blush, exactly two smooth OVAL fingerless plush arms and exactly two stubby feet. No thumbs, fingers, extra limbs, ears, tail or accessories. Keep a calm FRONT-FACING neutral standing pose, both feet flat on one floor baseline, arms relaxed slightly away from sides, open eyes. This is a slightly more grown, bottom-heavy stable pear-shaped seed companion, but recognizably the same character; face remains the focal point. Refined velour product rendering, subtle fabric variations rather than long fur, no shiny plastic or ceramic. Seamless warm ivory #FBF8F4 background and floor, diffuse softbox light from upper left, delicate contact shadow; identical gentle studio setup across the series. Entire head growth, body, hands and feet visible with generous white margins. Keep camera and physical figure scale constant: cream BODY alone about 48% of canvas height, feet baseline about 80% from top, room above for the modest plant growth. No panels, typography, watermarks, scenery, props, floating icons, checkerboard or pedestal. Never use the previously rejected hanging leaf cloak/long leaf hair, towering bud, tall upright stalk, hat-like crown or giant flat daisy. Botanical parts grow naturally from a small attached root at the upper crown, slightly toward viewer-right, with a very short concealed stem. Leaves and flower must share the same high-quality short velour/felt material family, subtle stitched veins and rounded soft edges. Do not put foliage across the forehead or down beside the cheeks. Keep the full face and cream body exposed.
```

## 阶段 3

```text
STAGE 03 / GREEN LEAVES: replace the reference's single baby sprout with a LOW, ORGANIC, ASYMMETRIC CLUSTER OF THREE SHORT BROAD LEAVES. One broader sage-green leaf curves sideways toward viewer-left, a second smaller soft olive leaf curls sideways and slightly back toward viewer-right, and a third short leaf tucks behind them. This is a compact low leaf rosette growing from the crown, not three vertical spikes. Gentle cupping, a few refined sewn veins, slight material color variation, carefully curled edges, simple readable silhouettes. Leaf cluster total width about 60-65% of cream body width, maximum rise above scalp about 18-20% of body height. The left-right spread creates a calm horizontal outline, with the crown center and forehead still fully readable. NO flower or bud, NO downward hanging leaves, NO leafy hood or cape, NO hair-like tendrils, NO bunny-ear V. Use the same neutral standing posture and calm open-eyed smile as the reference. Make the stable pear body just a little more grown than the baby reference, not taller than its mature sibling stages. Show one complete premium plush collectible.
```

## 阶段 4

```text
STAGE 04 / CLOSED FLOWER BUD: keep the reference mature stage-three cream body, standing pose, face, arms, feet, seams, camera, figure size and lighting unchanged. Transform only the top botanical cluster into a low natural cradle of THREE short sage leaves carrying ONE rounded closed flower bud offset a little toward viewer-right. The bud is SOFT CREAMY APRICOT-BLUSH, muted and sophisticated, with three/four overlapping velour petal folds and a rounded curved tip (NOT a pointed cone). Its lower third is visibly nestled/cupped INSIDE the sage leaves, organically emerging from them. Very short mostly concealed attached stem, bud gently leans about 15 degrees sideways. Bud height about 25% of cream body height, width about 27-30% of body width: clearly readable but much smaller than the head. Leaf cradle remains mostly sideways, with full forehead exposed. This is a modest living flower bud grown from the head, not a pink hat, a tall tulip on a stalk or an ornamental badge. No open bloom, no petal ring around face, no neck scarf, no hanging leaf cloak. The focal point must remain the companion's warm face. Identical neutral standing pose and camera scale to the mature leaf-stage reference.
```

## 阶段 5

```text
STAGE 05 / FULL BLOOM: keep the reference mature stage-three cream body, standing pose, face, arms, feet, seams, camera, figure size and lighting unchanged. Grow a fully open, THREE-DIMENSIONAL CUPPED CLOTH FLOWER from the same compact sage-leaf cradle on the upper crown, slightly offset toward viewer-right, on a very short concealed connected stem. Exactly FIVE broad soft petals with gently turned curled edges, varied overlap and subtle depth; creamy ivory with muted apricot/blush toward the petal bases. The open blossom faces diagonally upward and sideways in a soft three-quarter angle about 30-35 degrees, NOT straight flat at the viewer. It is fully blossomed and clearly different from a closed bud, but cupped and sculptural like a small handmade textile camellia/anemone, NOT a large circular daisy disk. The flower center is a small cluster of warm ochre embroidered knots, no large yellow coin. Flower width about 50-55% of body width and height about 25-28% of body height. Two or three short sage leaves support the blossom at its base; the leaves do not drape down the face or body. Its diagonal unfurling outline must be noticeably different from the horizontal leaf cluster and upright closed bud. Refined naturally grown companion, no long stalk, no headdress, no oversized flower hat, no floral face frame, no leaf cloak. Face and cream seed body remain the main subject. Identical neutral standing pose and same physical camera scale to the mature leaf-stage reference.
```

## 第四、第五阶段实际追加的参考约束

```text
CRITICAL REFERENCE LOCK: this supplied image is the already selected mature leaf-stage base. Retain exactly its cream body silhouette, eye placement, mouth, arm and foot shapes, neutral pose, light and background. Edit the botanical growth only. Keep the flower modest; the face remains dominant.
```

第三阶段参考 `seed-c-s1-01-idle-v2.png`；第四、第五阶段分别使用已目视检查的 `seed-c-s3-leaves-v3.png` 作为参考。每张通过一次独立的内置 `image_gen` 调用生成，没有使用 CLI、外部图片 API 或脚本重绘。

## 结果

三张已生成并完成目视与文件核验，待主人确认。提示词要求方形构图，工具实际输出均为 1254 × 1254 RGB PNG；记录实际输出尺寸，不按提示词中的 1024 × 1024 宣称交付。

| 阶段 | 工作区文件 | 目视核验 |
| --- | --- | --- |
| 3 绿叶 | `seed-c-s3-leaves-v3.png` | 三片短叶向侧后展开，后叶略立起；没有叶披肩，脸与四肢完整 |
| 4 花苞 | `seed-c-s4-bud-v3.png` | 杏粉色圆润闭合花苞偏侧生长，根部由小叶承托；没有长茎，延续第三阶段站姿与身体 |
| 5 开花 | `seed-c-s5-bloom-v3.png` | 五瓣布花斜向上展开，花瓣卷边和前后层次清晰；花心是小颗粒，整张脸露出 |

PNG 解码与完整性检查通过，三个 SHA-256 均不同，工作区副本与各自原件哈希一致。第一阶段十张图与既有资产清单中的哈希全部一致。尺寸比例是设计目标，三张为生成的静态外形参考，不是经过像素配准的动画帧。

原件、实际尺寸／色彩模式、字节数、SHA-256 与逐张核验记录见 [资产清单](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-growth-v3-assets.json) ，原图对照见 [三阶段确认稿](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-growth-v3-review.md) 。所有原件保留，副本未做脚本缩放、裁切、变形或抠图；网页代码和运行素材未改。
