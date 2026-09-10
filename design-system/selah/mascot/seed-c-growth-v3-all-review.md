# C 短绒：五阶段统一外形 V3

日期：2026-09-06。主人认可第三至第五阶段效果后，本轮补齐风格统一的第一、第二阶段。五张整体对照待主人审阅。

## 五阶段原图对照

| 第一阶段 · 初见 | 第二阶段 · 萌芽 | 第三阶段 · 绿叶 | 第四阶段 · 花苞 | 第五阶段 · 开花 |
| --- | --- | --- | --- | --- |
| ![初见](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s1-first-sprout-v3.png) | ![萌芽](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s2-paired-leaves-v3.png) | ![绿叶](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s3-leaves-v3.png) | ![花苞](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s4-bud-v3.png) | ![开花](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s5-bloom-v3.png) |
| 小折芽 | 双叶初展 | 三叶成簇 | 叶包花苞 | 立体绽放 |

五张使用同一奶油燕麦色短绒、棕色刺绣五官、圆润布手布脚和暖白布光。第一阶段身体略小、略圆；第二阶段自然长大；第三至第五阶段延续稳定的成熟种子形体。植物从小折芽、展开双叶、三叶簇，递进到花苞与开花。

## 本轮改动

| 阶段 | 结构与辨识点 | 原图 |
| --- | --- | --- |
| 1 · 初见 | 一枚向内折拢的小芽，身体略小、圆润；绒面、五官和椭圆手脚沿用第三阶段风格。 | [查看原图](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s1-first-sprout-v3.png) |
| 2 · 萌芽 | 两片宽短叶横向展开，叶根紧贴头顶；叶形比第三阶段更简单，身体介于第一与第三阶段之间。 | [查看原图](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s2-paired-leaves-v3.png) |
| 3 · 绿叶 | 低矮的三叶簇向侧后展开，保留此前认可原图。 | [查看原图](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s3-leaves-v3.png) |
| 4 · 花苞 | 杏粉闭合花苞由叶片承托，保留此前认可原图。 | [查看原图](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s4-bud-v3.png) |
| 5 · 开花 | 五瓣立体布花斜向开放，保留此前认可原图。 | [查看原图](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s5-bloom-v3.png) |

第一阶段的新图是外形母版提案，已经认可的十种动作意图和十张原图均保留。后续动作制作时再统一到确认后的外形；本轮没有重画十个动作，也没有将五张站姿计为五十种动画。

## 交付与核验

五张均为 1254 × 1254 RGB PNG，带暖白背景。两张新增图片使用内置 `image_gen`，均以第三阶段原图为唯一参考，分别生成一次；后三张直接沿用原图，未重新生成或脚本合成。

已检查新图的单叶／双叶数量、脸与四肢、材质及构图。五张 PNG 解码、文件签名、尺寸、色彩类型和复制哈希检查通过，哈希各不相同；后三张及第一阶段十动作原图与已有记录的哈希一致。

本轮属于静态外形设计，尚未接入网页。下一步先确认五阶段统一外形，再细化第二至第五阶段各十种动作，并统一可动画结构、过渡与 Reduce Motion 姿态。

提示词及生成记录：[第一、第二阶段](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/prompts-c-growth-v3-early.md) ，[第三至第五阶段](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/prompts-c-growth-v3.md) 。原件来源及完整元数据：[五阶段资产清单](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-growth-v3-all-assets.json) 。
