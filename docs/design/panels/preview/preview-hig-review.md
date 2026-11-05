# Preview HIG 契合度检查

Last updated: 2026-11-05

本文按 [HIG UI Validation Workflow](../../hig-ui-validation.md) 的记录格式，对中间的
Preview 面板做一次 macOS HIG 契合度检查，并给出符合 HIG 的控件方向。
配套设计稿：[preview-hig-mockup.html](preview-hig-mockup.html)（浏览器直接打开）。

这是一份评审记录，不是新的设计规范。结论被采纳后，应把对应条目合并进
[Preview UI Design Spec](preview-ui.md)，再按条目开 issue 实施。
写法与 [Inspector HIG 契合度检查](../inspector/inspector-hig-review.md) 一致。

## 范围

已检查：

| 状态 | 入口 | 实现 |
| --- | --- | --- |
| Header：元数据、Safe Frames、背景色、Fit | 始终显示 | `PreviewCanvasView.swift` `PreviewHeader` |
| 画布：空状态、视频、overlay | 始终显示 | `PreviewCanvasView.body`、`swiftUIOverlayLayer`、`skiaOverlayLayer` |
| Overlay 选择、拖动、吸附 | 点击或拖动 overlay | `overlayDragGesture`、`PreviewSnapResolver`、`PreviewSelectionAffordance` |
| 右键菜单 | 右键 overlay | `OverlayElementContextMenu` |
| 播放条 | 始终显示 | `PreviewPlaybackControls`、`PreviewRateMenu` |
| 键盘与菜单栏 | Space、J/K/L、方向键、Home/End、⌫ | `MainEditorView.swift` `onKeyPress`、`RunningOverlayApp.swift` Playback 菜单 |

未检查：VoiceOver 朗读顺序、Reduce Motion、实际播放性能。

依据的 HIG skill：`hig-patterns`（playing-video、undo-and-redo、drag-and-drop、
feedback）、`hig-components-menus`（buttons、toolbars、pop-up-buttons、
the-menu-bar、context-menus）、`hig-components-controls`（toggles）、
`hig-inputs`（keyboards、pointing-devices）、`hig-foundations`
（accessibility、color）。

## 结论摘要

画布本身做得很扎实：normalized 坐标、吸附线、⌘ 临时关闭吸附（与 Keynote 一致）、
方向键 1px 和 Shift 10px 微调、拖动结束时提交一次撤销，都符合 HIG。
问题集中在**画布外的控件**和**缺失的反馈**：

- 播放条没有当前时间，整个应用里也找不到播放头时间。
- 规范写明的角点缩放手柄没有实现。
- 指针在 overlay 上不会变化，用户看不出它可以拖。
- Header 里的 pop-up 和 toggle 都是自绘的。

明确违背 HIG 的有 3 项（P1）。P1 和 P2 条目按出现顺序编号为 1–8，
与设计稿中的黄色编号一一对应。

## P1：明确违背 HIG

### [P1] 看不到播放头的当前时间

- **Surface**：Preview 播放条，以及整个编辑器。
- **Evidence**：`preview-ui.md` 的 Bottom Playback Row 明确要求 “Do not show:
  Timecode / Playback time text”。全仓库 `Sources/RunningOverlay/UI` 中没有任何
  时间码显示；Timeline 只在悬停 ruler 时显示**指针位置**的时间，而不是播放头的时间
  （`TimelineView.swift:574-605`）。
- **HIG basis**：`hig-patterns/playing-video`（播放界面应让用户知道当前位置和
  进度）；`hig-patterns/feedback`（状态要持续可见，而不是只在悬停时出现）。
- **Problem**：
  - 用户用 ←/→ 逐帧对齐时，看不到当前是第几秒、第几帧。
  - 截图核对、和手表数据比对时，也读不到当前的 activity 时间。
  - 这个应用的核心任务是“对齐时间”，而它恰好不显示时间。
- **Expected behavior**：播放条左侧显示播放头时间，使用等宽数字，例如
  `23:41.12`。点击后可以在 project timeline 时间和 activity elapsed 时间之间切换，
  或者在 `.help` 中同时显示两者。
- **Suggested fix**：
  - 修改 `preview-ui.md`，撤销 “Do not show timecode” 这一条，然后在
    `PreviewPlaybackControls` 左侧加只读时间读数。
  - 读数必须明确标出时间域，不要把 project timeline 时间和 activity elapsed 时间
    混在一起（AGENTS.md 的时间域约束）。
  - 这是对已有设计决策的修改，需要产品确认。
- **Validation**：focused test 覆盖时间读数的格式化（负数、超过 1 小时、帧小数）。

### [P1] 规范中的角点缩放手柄没有实现

- **Surface**：选中的 overlay。
- **Evidence**：`preview-ui.md` 规定 “Selected overlay gets a subtle blue selection
  border and small corner handles … Dragging any corner handle scales the selected
  overlay”。实现中的 `PreviewSelectionAffordance` 只有一个描边矩形，
  并且 `.allowsHitTesting(false)`（`PreviewCanvasView.swift:1211-1218`）。
  仓库中没有任何 handle 相关代码。
- **HIG basis**：`hig-inputs/pointing-devices`（可直接操作的对象要提供明确的操作点）；
  `hig-components-menus/buttons`（外观要表达能做什么）。
- **Problem**：缩放只能去 Inspector 拖 Scale 滑杆，画布上无法直接调整大小。
  规范和实现不一致，后续的人会以为这个功能已经存在。
- **Expected behavior**：选中框四角有 6–7pt 的方形手柄，悬停时指针变为对角缩放箭头；
  拖动时实时更新 `scale`，结束时提交一次撤销；按住 Option 从中心缩放。
- **Suggested fix**：在 `PreviewSelectionAffordance` 上加四个 handle，复用
  `overlayDragGesture` 的连续撤销分组（`finishContinuousEdit()`）。
  如果短期不做，就先从 `preview-ui.md` 中删掉这一段，避免规范超前于实现。
- **Validation**：focused test 断言一次 handle 拖动只注册一个撤销点。

### [P1] 指针不提示可拖动

- **Surface**：所有可选中的 overlay，以及锁定的 overlay。
- **Evidence**：Preview 中没有任何 `NSCursor` 调用（全仓库只有分栏拖动条用了
  `NSCursor`，见 `SplitCursorRegion.swift`）。锁定的 overlay 点击没有任何反应
  （`PreviewCanvasView.swift:217-219`）。
- **HIG basis**：`hig-inputs/pointing-devices`（指针形状应反映当前位置可以做的
  操作）。
- **Problem**：用户看不出画布上的哪些东西可以拖。锁定的 overlay 点了没反应，
  也没有任何提示，用户会以为应用卡住了。
- **Expected behavior**：
  - 悬停可移动的 overlay 时显示 `openHand`，拖动时显示 `closedHand`。
  - 悬停 handle 时显示对应的缩放箭头。
  - 悬停锁定的 overlay 时保持箭头，并在 `.help` 中显示 “Locked”。
    点击时可以在选中框位置短暂显示锁形标记。
- **Suggested fix**：给 overlay 命中区加 `.onContinuousHover`，或者复用
  `SplitCursorRegion` 的做法提供 cursor rect。
- **Validation**：手动检查。

## P2：与 macOS 惯例冲突

### [P2] Fit 和播放速度是自绘的 pop-up

- **Evidence**：Fit 菜单（`PreviewCanvasView.swift:1042-1075`）和速度菜单
  （`PreviewCanvasView.swift:2878-2916`）都用 `chevron.down` 自绘，并设置了
  `.menuIndicator(.hidden)`。
- **HIG basis**：`hig-components-menus/pop-up-buttons`（互斥值选择用 pop-up button，
  指示器是上下双箭头；单箭头属于 pull-down，用于执行命令）。
- **Problem**：与 Inspector 评审中的 P2 相同。另外，Fit 菜单的 help 写的是
  “Preview Zoom”，实际只有 Fit 和 Fill 两项，不能放大到 100% 或 200% 查看细节。
- **Suggested fix**：
  - 都改为 `Picker(.menu)` 搭配 `.controlSize(.small)`。
  - Fit 菜单补上 “50% / 100% / 200%”，并提供菜单栏命令 View > Zoom In（⌘+）、
    Zoom Out（⌘-）、Zoom to Fit（⇧Z）。注意 ⌘+ / ⌘- 目前分配给了 Timeline 菜单，
    需要按焦点区域分派，或者 Preview 改用 ⌘⇧+ 等组合。
  - 如果短期不做缩放，help 改为 “Fit Mode”。

### [P2] Header 的开关按钮不报告状态

- **Evidence**：Safe Frames 是普通 `Button` 加自绘的激活态
  （`PreviewCanvasView.swift:1022-1030`），help 文案不随状态变化，
  VoiceOver 读不出开或关。`PreviewIconButtonStyle` 只有按下态，没有悬停态
  （`PreviewCanvasView.swift:1258-1280`）。
- **HIG basis**：`hig-components-controls/toggles`（开关类按钮要清楚显示当前状态）；
  `hig-components-menus/buttons`（自定义按钮要有悬停和按下态）。
- **Suggested fix**：
  - 改为 `Toggle(isOn:)` 搭配 `.toggleStyle(.button)`。系统会提供激活态外观和
    `isSelected` 无障碍属性。
  - 悬停态复用 Inspector 分支里的 `InspectorIconButtonStyle`（PR #58）。
  - 在 View 菜单增加 “Show Safe Frames”（⌘'），让这个开关有菜单栏入口。

### [P2] Stop 与 Pause 重复，Previous / Next 含义不清

- **Evidence**：
  - 播放 timeline 时，`stopPlayback()` 只是暂停并把速度重置为 1x，不会移动播放头
    （`ProjectDocument.swift:355-364`），效果和 Pause 一样。
  - Previous / Next 跳到上一个、下一个 clip 的起点（`ProjectDocument.swift:1185-1214`），
    help 只写 “Previous” / “Next”。
  - Playback 菜单里还有一组 “Previous Edit Point (Up Arrow)”，和播放条的
    Previous 是两套跳转逻辑。
- **HIG basis**：`hig-components-menus/buttons`（每个按钮的用途要清楚，
  不要放功能重复的按钮）；`hig-patterns/playing-video`。
- **Suggested fix**：
  - 删除 Stop。如果要保留“回到起点”，就叫 “Go to Start”，对应 Home 键。
  - Previous / Next 改名为 “Previous Clip” / “Next Clip”，或者统一成
    “Previous / Next Edit Point”，与方向键 ↑/↓ 共用一套逻辑。
  - 播放条形成 `|◀  ▶  ▶|` 三键布局，与 QuickTime 和 FCP 的检视器一致。

### [P2] Playback 菜单的快捷键写在标题里，且有重复项

- **Evidence**：`RunningOverlayApp.swift:136-177`。
  - 同时有 “Play” 和 “Play (K)” 两个菜单项。
  - “Go to Start (Home)”、“Previous Edit Point (Up Arrow)” 把按键写进了标题，
    没有使用 `keyboardShortcut`。注释说明这样做是为了避免抢走列表和文本框的
    方向键。
- **HIG basis**：`hig-components-menus/the-menu-bar`（快捷键显示在菜单项右侧的
  快捷键栏；不要为同一个命令放两个菜单项）。
- **Problem**：快捷键栏与其他 macOS 应用不一致；VoiceOver 会把 “(Up Arrow)”
  当作命令名称的一部分读出来。
- **Suggested fix**：
  - 删除 “Play (K)”。J/K/L 作为别名写在 “Play” 的 `.help` 或帮助文档里。
  - 用 AppKit 的 `NSMenuItem` 设置 `keyEquivalent`，配合
    `validateMenuItem`，只在焦点不在文本输入时启用。这样快捷键能显示在右侧，
    同时不会抢走文本框的按键。

### [P2] 播放速度只有 1x–8x，J 不能倒放

- **Evidence**：`setPlaybackRate` 把速度限制在 1...8
  （`ProjectDocument.swift:389-391`）；J 只会减速或暂停
  （`ProjectDocument.swift:375-387`）。
- **HIG basis**：`hig-patterns/playing-video`（播放控件应符合用户在其他媒体应用中
  形成的预期）。J/K/L 是专业剪辑软件的通用约定，J 表示倒放。
- **Problem**：熟悉 J/K/L 的用户按 J 会期待倒放，结果是暂停。另外没有 0.5x，
  对齐动作细节时不方便。
- **Suggested fix**：短期在速度菜单加 0.5x，在 J 的 help 中写明 “Slower”。
  倒放涉及视频解码和时间域，需要单独评估，不建议在本轮做。

## P3：打磨

- **“Guides On” HUD 重复**：Safe Frames 按钮已经显示激活态，画布左上角再显示一个
  “Guides On”（`PreviewCanvasView.swift:1087-1100`），还会盖住放在左上角的 overlay。
  建议删除。
- **空状态**：没有媒体时只显示一个 54pt 的 `film` 图标，文字为空字符串
  （`PreviewCanvasView.swift:73-80`）。建议显示 “No Video” 和一句下一步提示，
  或者干脆留空，不放图标。
- **背景色 color well**：`ColorPicker` 是系统 color well，符合 HIG。但它和
  Safe Frames、Fit 并排放在 header，属于低频设置。建议收进 Fit pop-up 下方，
  或者移到 View 菜单 “Canvas Background…”。
- **吸附反馈**：吸附发生时可以通过 `NSHapticFeedbackManager` 发送
  `.alignment` 反馈（Force Touch 触控板），这是 Keynote 的做法。
- **选中框**：1.4pt 蓝色描边加 5pt 外扩。在亮色视频上不太明显，建议加 1pt 深色外描边。
- **Skia 调试开关**：只在 DEBUG 构建中出现，不影响发布版本，保持现状。

## 要不要做成 FCP 检视器的样子

值得借鉴的部分：

| 借鉴 | 原因 |
| --- | --- |
| 检视器顶部右侧有缩放 pop-up（Fit / 50% / 100%） | 标准 pop-up，能查看细节 |
| 底部居中的时间码，左右是播放控件 | 用户总能看到当前位置 |
| 选中对象显示四角和边中点手柄，指针随之变化 | 直接操作 |
| 视图开关（安全框、网格）放在 View 菜单，并有快捷键 | 低频开关不占用画布空间 |

不必借鉴的部分：FCP 检视器底部的 Transform / Crop / Distort 模式切换。
本项目只需要移动和等比缩放，不需要多种变换模式。

## 建议的落地顺序

1. 播放条加时间读数（P1；先修改 `preview-ui.md`，需要产品确认时间域的显示方式）。
2. 指针反馈、锁定 overlay 的提示（P1，改动小）。
3. 角点缩放手柄（P1；涉及撤销分组，需要人工评审），或者先从规范中删掉这一段。
4. Fit 和速度改为系统 pop-up，Safe Frames 改为 toggle 按钮（P2，可复用 PR #58 的样式）。
5. 播放条按钮精简，Playback 菜单整理（P2）。
6. P3 打磨。
