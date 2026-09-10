# C 短绒 · 第一阶段十动作 V2

日期：2026-09-05。**第一阶段十个动作已获主人确认，尚未接入网页。** 下方五阶段 V2 为历史提案，其中第三至第五阶段未采用；最新待确认外形见 [三阶段 V3](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-growth-v3-review.md) 。

这一版以身体姿态、站坐重心、手势与表情区分十个动作，统一使用奶油短绒种子和小芽叶。后续目标为五阶段各十种独立表现，共 50 种；目前只完成第一阶段十张，后四十种仍为后续设计。

## 第一阶段十图

| 01 · 自然待机 | 02 · 害羞眨眼 |
| --- | --- |
| ![自然待机](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s1-01-idle-v2.png) | ![害羞眨眼](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s1-02-blink-v2.png) |
| 双脚站稳、双手自然放开，建立第一阶段基准。 | 蜷坐、手贴脸、闭眼，轮廓收拢。 |

| 03 · 舒展叶摆 | 04 · 侧耳准备听 |
| --- | --- |
| ![舒展叶摆](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s1-03-leaf-sway-v2.png) | ![侧耳准备听](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s1-04-listen-enter-v2.png) |
| 一脚支撑、一脚抬起，斜向伸展。 | 侧耳前倾，一手贴近脸侧。 |

| 05 · 坐稳认真听 | 06 · 点头致意 |
| --- | --- |
| ![坐稳认真听](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s1-05-listen-playing-v2.png) | ![点头致意](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s1-06-listen-complete-v2.png) |
| 坐稳、双脚朝前，双手放在膝前。 | 前倾致意、双手腹前，弯眼微笑。 |

| 07 · 陪你开口 | 08 · 轻轻拍手 |
| --- | --- |
| ![陪你开口](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s1-07-rec-recording-v2.png) | ![轻轻拍手](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s1-08-rec-done-v2.png) |
| 两手靠近嘴侧，小圆口陪你开口。 | 两手在胸前拍合，站姿开心。 |

| 09 · 开心小跳 | 10 · 伸手再试一次 |
| --- | --- |
| ![开心小跳](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s1-09-quiz-good-v2.png) | ![伸手再试一次](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-s1-10-quiz-retry-v2.png) |
| 双脚离地、双臂向上，庆祝一次。 | 重心放低，一手邀请、一手贴胸。 |

## 五阶段整体区别（V2 历史稿）

![五阶段外形提案](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-growth-v2.png)

| 阶段 | 一眼可见的结构 |
| --- | --- |
| 初见 | 小而圆的身体、一枚短芽 |
| 萌芽 | 更挺拔的种子、V 形双叶 |
| 绿叶 | 三叶冠、两侧叶披肩 |
| 花苞 | 大颗闭合珊瑚粉花苞、叶披肩 |
| 开花 | 完整五瓣花冠、金色花心、开放姿态 |

五阶段以结构和动作性格递进；不会把同一套动作只换小装饰后当成 50 种已完成表现。阶段二至五的最终体型、花叶尺寸与专属动作仍需后续确认和出图。

## 当时的确认重点（历史记录）

1. 第一阶段十种姿态是否足够明确，尤其是侧耳／坐听、致意／拍手／小跳的区别。
2. 五阶段的外形差距是否达到预期，同时仍然像同一个伙伴。
3. 花苞和花冠的大小、叶披肩是否符合角色气质。

这些是静态关键姿态，不是完整动作序列。实施时仍需统一模型／可变形图层、动作过渡和静态退化；不能直接轮播十张独立生成图。PNG 为带暖白背景的 RGB 设计图，不宣称透明资产已完成。

详细结构和五十格动作矩阵草案见 [设计说明](E:/develop/self-dev/workbuddy/language-study/docs/superpowers/specs/2026-09-05-seed-plush-50-state-design.md) ；实际内置工具提示词、来源与核验见 [生成记录](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/prompts-c-stage1-v2.md) 。
