# Pet Layered Sprite Pilot Design

> 状态：已获主人批准（方案 A）
> 日期：2026-08-03
> 适用范围：首批 10 个精灵动作的静态分层素材与 SwiftUI 原生微动效实施

## 1. 目标

在不引入视频、GIF、Lottie、Rive 或新依赖的前提下，把当前 SwiftUI Shape 精灵升级为「统一分层静态精灵 + SwiftUI 原生微动效」，完成首批 10 个动作的真实设备可用版本。

## 2. 边界

### 本轮包含

- 统一 2.5D 静态身体素材（不包含背景、阴影、叶片、光环）。
- 闭眼与柔和眼神两张透明表情覆盖层。
- 现有 10 个动作 ID 的视觉渲染。
- `Assets.xcassets` 与精灵素材管线。
- Debug 环境可见的 10 动作 Gallery。
- Reduce Motion、后台暂停、一次性动作恢复。
- 单元测试与 iOS 模拟器验证。

### 本轮不包含

- 剩余 110 个动作。
- 新增表情系统与表情素材库。
- 视频、MP4、GIF 运行时素材。
- Lottie、Rive 或其他动画依赖。
- 成长形态重制（叶片、花苞、花朵继续使用现有原生装饰层）。
- 修改学习、录音、Listen、Practice 业务流程。
- 修改动画 ID、状态机优先级与业务触发点。

## 3. 设计方向

- 品牌方向：Quiet Growth。
- 角色：单一固定 2.5D 种子精灵。
- 材质：柔和黏土质感，哑光、低反射。
- 情绪：安静、陪伴、不施加压力。
- `quiz-fail`：非惩罚性，不使用红色警告、哭泣、震动、摔倒或惩罚文案。

## 4. 运行结构

```text
PetSpriteView
├─ PetLayeredArtwork
│  ├─ 静态身体精灵图（Sprite Sheet）
│  ├─ 闭眼覆盖层
│  ├─ 柔和眼神覆盖层
│  └─ 现有原生装饰层（sprout／leaf／bud／bloom）
├─ 原生阴影层
├─ 状态光环（Listen／Recording／完成）
└─ SwiftUI 位移、旋转、缩放与淡化
```

`PetAnimationController`、`PetAnimationStateMachine`、`PetAnimationDescriptor` 保持不变。首轮只替换 `PetSpriteView` 的绘制层与动作参数，控制改动范围。

## 5. 素材规格

### 5.1 运行时素材清单

| 素材 | 内容 | 用途 |
|---|---|---|
| `seed-body-sheet` | 12 帧身体姿态序列（6×2） | `gentle-float`、`listen-enter`、`listen-playing`、`quiz-good` 等身体姿态 |
| `seed-eyes-closed` | 透明闭眼覆盖层 | `blink`、`quiz-fail`、`rec-done` |
| `seed-eyes-soft` | 透明柔和眼神覆盖层 | `quiz-fail`、`rec-done` |

### 5.2 画布与导出

- 工作母版：`1200 × 1440px`。
- App 导出：
  - `@1x`：`240 × 288px`。
  - `@2x`：`480 × 576px`。
  - `@3x`：`720 × 864px`。
- sRGB、透明 PNG。
- 三张素材使用完全相同的画布、脚底锚点和面部坐标。
- 不烘焙落地阴影、背景、光环和文字。
- 身体素材不包含叶片。

### 5.3 姿态帧约定

身体精灵序列包含 12 帧，每帧是同一角色在统一机位下的固定姿态：

1. 中性
2. 上浮（gentle-float 峰值）
3. 左倾 12°（listen-enter）
4. 纵向拉伸（listen-playing 峰值）
5. 上跳（listen-complete 峰值）
6. 高跳 + 旋转（quiz-good 峰值）
7. 下沉（quiz-fail 峰值）
8. 左倾 6°（rec-recording）
9. 上跳（rec-done 峰值）
10. 中性（备用）
11. 中性（备用）
12. 中性（备用）

## 6. 10 个动作渲染映射

### 6.1 待机

| 动作 | 静态基础 | SwiftUI 微动效 | Reduce Motion |
|---|---|---|---|
| `gentle-float` | 上浮姿态帧 | 3 秒循环呼吸，阴影同步 | 静止中性帧 |
| `blink` | 中性帧 | 闭眼层 0.3 秒淡化切换 | 快速两帧切换 |
| `leaf-sway` | 中性帧 | 装饰层 ±10° 摆动 | 装饰层静止 |

### 6.2 Listen

| 动作 | 静态基础 | SwiftUI 微动效 | Reduce Motion |
|---|---|---|---|
| `listen-enter` | 左倾 12° 帧 | 姿态淡入，紫色光环淡入 | 仅紫色光环 |
| `listen-playing` | 拉伸帧 | 0.24 秒轻微缩放脉冲 | 静态紫色光环 |
| `listen-complete` | 上跳帧 | 上跳回弹，绿色光环淡出 | 仅光环淡化 |

### 6.3 Recording

| 动作 | 静态基础 | SwiftUI 微动效 | Reduce Motion |
|---|---|---|---|
| `rec-recording` | 左倾 6° 帧 | 珊瑚光环脉动，姿态保持 | 静态珊瑚光环 |
| `rec-done` | 上跳帧 | 上跳回弹，柔和眼神，绿色光环 | 表情切换与光环淡化 |

### 6.4 Practice

| 动作 | 静态基础 | SwiftUI 微动效 | Reduce Motion |
|---|---|---|---|
| `quiz-good` | 高跳帧 | 上跳、20° 旋转回弹、叶片轻甩 | 绿色反馈淡入 |
| `quiz-fail` | 下沉帧 | 轻微下沉后恢复，柔和眼神 | 短暂柔和表情切换 |

## 7. 动画与辅助功能原则

- 所有循环使用有限次数，进入后台或视图消失后停止。
- 一次性动作结束后必须恢复当前上下文状态。
- `leaf-sway` 继续受 `decorationStage != .none` 门控。
- Reduce Motion 下禁用位移、旋转、缩放与持续脉冲，只保留必要的状态切换。
- VoiceOver 只读取一个精灵语义，不逐层读取装饰图片。
- 光环峰值透明度不超过 0.45，不做全屏特效。

## 8. 测试与验证

### 8.1 单元测试

- 10 个动画 ID 都有视觉配置。
- 所有一次性动作都有结束时间。
- reaction 完成后恢复 context。
- `leaf-sway` 受装饰阶段限制。
- 三张素材都能被加载。
- Reduce Motion 每个动作都有退化方案。
- 精灵序列帧索引计算正确。

### 8.2 平台验证

- Swift 单元测试通过。
- iOS Simulator Release 构建通过。
- 无签名归档通过。
- 真机视觉、性能、解码与耗电验收。
- 后台、前台、页面切换和快速连续触发验证。

Windows 本机无法完成 Xcode 与真机验证，「代码完成」与「平台验证完成」分开汇报。

## 9. 完成标准

首批 10 个动作只有同时满足以下条件才能标记完成：

- 角色在所有动作中保持同一身份与比例。
- 10 个动作在真实 `100 × 120pt` 尺寸下可以区分。
- 无图片切换闪烁或明显解码卡顿。
- 一次性动作结束后正确恢复原状态。
- Reduce Motion 全覆盖。
- VoiceOver 不逐层读取装饰图片。
- 未引入新依赖、视频或额外动作。
- 自动测试、iOS 构建与归档通过。
- 真机视觉与性能完成验收。

## 10. 后续

首批 10 个动作经过真实自用稳定后，再评估其他动作、表情素材与视频方案。
