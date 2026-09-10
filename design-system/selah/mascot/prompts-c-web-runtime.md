# C Web 运行图集生成记录

日期：2026-09-05。均使用内置 imagegen；未使用外部 CLI／API。

## 首次单角色提取

提示词：

```text
Use case: background-extraction and precise-object-edit.
Asset type: production PNG sprite for Selah Flutter Web, not a design sheet.
Input image: selected and approved C short-plush character reference. Extract ONLY the large character on the left. Preserve exactly its cream oat short velour texture, broad low pear-shaped body, small cloth arms, tiny feet, subtle left seam, brown stitched eyes and small smile, sage fabric leaf, lighting and proportions. Keep the entire character visible. Do not redesign it.
Primary edit: isolate this one character onto a genuinely transparent background with alpha=0 outside the character. No text, no other characters, no ground or cast shadow, no white backdrop, no checkerboard painted into RGB, no label or border. Center with tight usable bounds and about 6% transparent breathing room all around.
Composition: single straight-on character, square image, front view same as approved hero. This is a cutout, so preserve all subtle fuzzy edge detail in alpha. Genuine RGBA transparency required. Do not create an infographic. Keep its shape calm and consistent with the reference.
```

输出：`C:/Users/lhjjj/.codex/generated_images/01a06f03-2e69-7491-9670-1df1969f94ff/exec-aa5f2176-7946-4f59-8804-f73a3f06ab09.png`。实际 1254 × 1254、RGB，含绘制棋盘格；未接入。

## 身体与叶片图集

提示词：

```text
Use case: precise-object-edit / background-extraction. Reference is the approved large left-hand C short-plush seed character. Make a production material atlas, not a concept sheet. One square canvas, exactly two isolated parts: on the LEFT occupying x=8%-67% y=25%-91%, the exact same cream oat plush body with attached small hands and tiny feet, but REMOVE ALL eyes and mouth (leave the face completely blank; preserve gentle blush and uninterrupted cream short-velour texture). Remove the leaf and its stem from the body, smoothly close the crown with plush fabric. Body is broad, squat, rounded pear silhouette and left subtle seam, same as reference; avoid taller narrower reinterpretation. On the RIGHT occupying x=72%-94% y=8%-34%, isolate the SAME sage-green stitched fabric leaf with its short stem pointing down-left, unchanged texture, do not attach it to the body. Both parts individually complete. Do NOT put anything else anywhere on the canvas. These two pieces will be attached and animated in Flutter. Lighting matches the approved reference, soft upper-left studio light. Short soft premium velour, not long fur or shiny plastic. Transparent background as REAL ALPHA, empty pixels with zero opacity, NOT a drawn checkerboard. No ground shadow. No labels, no text, no facial features, no eyes. If alpha is unsupported, use solid pure white #FFFFFF everywhere outside the two parts; never draw a checkerboard. Preserve the approved identity and proportions.
```

输出复制到 `SelahFlutter/assets/sprites/SeedPlushAtlas.png`。实际 1254 × 1254、RGB，含棋盘背景。保留原始像素，Flutter 以轮廓裁切后绘制；不得称为透明 PNG。身体与手脚同层，五官由 Canvas 以固定眼位绘制，叶片独立沿叶根微摆。

轮廓坐标根据色彩与背景差异测量，并在 `plush_companion_art.dart` 中固定；该过程仅读取素材、生成几何坐标，没有重绘或处理 PNG。真实显示与边缘检查以浏览器截图为准。
