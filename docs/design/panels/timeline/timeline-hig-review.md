# Timeline HIG 契合度检查

Last updated: 2026-11-05

本文按 [HIG UI Validation Workflow](../../hig-ui-validation.md) 的记录格式，对底部的
Timeline 面板做一次 macOS HIG 契合度检查，并给出符合 HIG 的控件方向。
配套设计稿：[timeline-hig-mockup.html](timeline-hig-mockup.html)（浏览器直接打开）。

这是一份评审记录，不是新的设计规范。结论被采纳后，应把对应条目合并进
[Timeline UI Design Spec](timeline-ui.md)，再按条目开 issue 实施。
写法与 [Inspector HIG 契合度检查](../inspector/inspector-hig-review.md) 一致。

## 范围

已检查：

| 状态 | 入口 | 实现 |
| --- | --- | --- |
| Header：预览轨道可见性、折叠空隙、缩放 | 始终显示 | `TimelineView.swift` `TimelineView.body` |
| Ruler、悬停读数、C 键悬停拖播 | 有 Activity | `drawRuler`、`RulerHoverTooltip`、`scrubPlayheadIfNeeded` |
| 标签列、Activity 轨、视频轨与 clip | 有内容 | `drawStickyLabelColumn`、`drawFitTrack`、`drawClip` |
| 选择：单击、框选 | 时间区域 | `mouseDown`、`mouseDragged`、`clipsIntersectingMarquee` |
| Clip 拖动、折叠模式 | 展开或折叠 | `mouseDragged`、`mouseUp` |
| 右键菜单 | 右键 clip 或轨道 | `rightMouseDown`、`addClipMenuItems` |
| 缩放手势、拖放 | ⌘ 滚轮、捏合、从 Media Pool 拖入 | `scrollWheel`、`magnify`、`draggingEntered` 等 |
| 键盘 | ⌫、C、方向键 | `keyDown`、`keyEventMonitor`、`MainEditorView` 的 `onKeyPress` |

未检查：VoiceOver 实测（见 P1，当前画布没有任何无障碍元素可测）、
Reduce Motion 下的自动滚动。

依据的 HIG skill：`hig-inputs`（keyboards、pointing-devices、gestures）、
`hig-foundations/accessibility`、`hig-components-controls`（sliders、toggles）、
`hig-components-menus`（buttons、pull-down-buttons、context-menus）、
`hig-patterns`（drag-and-drop、undo-and-redo、feedback）。

## 结论摘要

时间线的核心交互方向是对的：用 AppKit 自绘保证精度，ruler 点击即跳转，
⌘ 滚轮和捏合以指针为中心缩放，框选跨轨道，删除和移动都能撤销，
⇧Z 缩放到合适大小与 FCP 一致。

问题集中在三处：

- 自绘画布没有任何无障碍信息，也没有指针反馈。
- C 键悬停拖播会在全局吞掉 “c” 的输入。
- Header 的两个开关看不出状态。

明确违背 HIG 的有 4 项（P1）。P1 和 P2 条目按出现顺序编号为 1–9，
与设计稿中的黄色编号一一对应。“看不到播放头时间”已决定不做，见
[Preview HIG 契合度检查](../preview/preview-hig-review.md)。

## P1：明确违背 HIG

### [P1] 指针悬停在 Timeline 上时，所有文本框都打不出 “c”

- **Status**：已完成（2026-11-05）：`TimelineHoverScrubKey.shouldConsume` 复用 `EditorEscapeKey.isTextInput`；悬停拖播本身也在文本输入有焦点时停止。
- **Surface**：Inspector 的数值框和文本框、Media Pool 的搜索框和重命名框、
  所有 sheet。
- **Evidence**：`TimelineView.swift:457-477`。`keyEventMonitor` 是窗口级的 local
  monitor，只要 `isMouseOverTimeline` 为真，就对 C 键的 keyDown 和 keyUp 返回
  `nil`，不检查当前 first responder 是不是文本输入。
- **HIG basis**：`hig-inputs/keyboards`（不要抢走系统和文本输入的标准按键；
  自定义快捷键只在相关的上下文中生效）。
- **Problem**：用户在 Inspector 里改 overlay 的文字标签，指针碰巧停在下方的时间线上，
  输入 “Cadence” 会变成 “adene”，没有任何提示。时间线占据窗口底部的整个宽度，
  这种情况很容易发生。
- **Expected behavior**：只有在没有文本输入焦点时，C 才进入悬停拖播。
  文本框获得焦点时，C 照常输入。
- **Suggested fix**：在 monitor 里复用 PR #58 中 `EditorEscapeKeyMonitor` 的
  `isTextInput(firstResponder)` 判断；当前焦点是文本输入时直接返回 `event`。
- **Validation**：focused test 覆盖“文本输入为 first responder 时，monitor 不消费 C”。
  如果 monitor 难以测试，就把判断提取成纯函数来测。

### [P1] 时间线画布对 VoiceOver 不可见

- **Status**：已完成（2026-11-05）：画布、轨道、clip、播放头；Activity 分段尚未暴露。VoiceOver 实测仍待人工检查。
- **Surface**：整个画布：轨道、clip、Activity 轨、播放头。
- **Evidence**：`TimelineCanvasNSView` 只实现了 `draw(_:)`，没有
  `accessibilityChildren`、`accessibilityRole` 或任何 `setAccessibility*` 调用。
  全仓库 UI 目录中都没有自定义无障碍元素。
- **HIG basis**：`hig-foundations/accessibility`（自定义控件必须提供无障碍信息，
  让 VoiceOver 用户可以感知和操作）。
- **Problem**：VoiceOver 进入时间线只会读到一个没有名字的组。读不出有几条轨道、
  clip 的名字和位置，也读不出播放头在哪里。
- **Expected behavior**：
  - 画布的 role 为 group，标签为 “Timeline”。
  - 每条轨道是一个子元素，例如 “Layer 1, 3 clips”。
  - 每个 clip 是可选中的元素，读出名称、起点和时长，支持
    `accessibilityPerformPress` 选中。
  - 播放头是一个 slider（`NSAccessibility.Role.slider`），value 为当前时间，
    支持 increment 和 decrement（逐帧移动）。
- **Suggested fix**：给 `TimelineCanvasNSView` 实现 `accessibilityChildren()`，
  返回轻量的 `NSAccessibilityElement`，frame 复用 `clipRect`。第一步先做播放头和
  clip，Activity 分段放到后面。
- **Validation**：用 Accessibility Inspector 手动检查；可以加一个 focused test，
  断言 `accessibilityChildren` 的数量与 clip 数量一致。

### [P1] 自绘画布没有指针反馈

- **Status**：已完成（2026-11-05）：ruler 和播放头使用 `resizeLeftRight`；播放头线 ±3pt 可抓取。
- **Surface**：clip、ruler、播放头、折叠模式下的 clip。
- **Evidence**：`TimelineView.swift` 没有任何 `NSCursor` 调用，
  也没有 `resetCursorRects`。
- **HIG basis**：`hig-inputs/pointing-devices`（指针形状应反映当前位置可以做的
  操作；不能执行的操作要有提示）。
- **Problem**：
  - 悬停 clip 时看不出能拖。
  - 折叠模式下 clip 拖不动（`TimelineView.swift:631-636`），但指针和展开模式一模一样，
    用户只会觉得“拖不动”，不知道为什么。
  - 播放头只能在 ruler 里拖，在轨道区域拖播放头线会变成框选。
- **Expected behavior**：
  - 展开模式下，悬停 clip 显示 `openHand`，拖动时显示 `closedHand`。
  - 折叠模式下，悬停 clip 显示 `operationNotAllowed`，并在 `.help` 中显示
    “Show gaps to move clips”。
  - 悬停 ruler 显示 `resizeLeftRight` 或 I-beam 形状的定位指针。
  - 播放头线左右各 3pt 的范围可以直接抓取拖动，并显示 `resizeLeftRight`。
- **Suggested fix**：在 `mouseMoved` 里按命中区域设置指针，或者在 `resetCursorRects`
  中按 clip 的 rect 添加 cursor rect。
- **Validation**：手动检查。

### [P1] 折叠空隙按钮的激活态不可见

- **Status**：已完成（2026-11-05）：`Toggle` + `.toggleStyle(.button)`，Timeline 菜单有带勾选的 “Hide Gaps Without Video”。
- **Surface**：Header 右侧的折叠空隙按钮。
- **Evidence**：`TimelineView.swift:30-37`。
  - 激活态依赖 `.tint(...)`，但 `EditorIconButtonStyle` 的前景色写死为
    `textSecondary`，从不读取 tint（`EditorTheme.swift:74-98`），所以 tint 不生效。
  - 图标语义反了：折叠时用空心 `arrow.left.and.right.square`，
    展开时反而用实心 `.fill`。
- **HIG basis**：`hig-components-controls/toggles`（开关要准确显示当前状态）。
- **Problem**：`timeline-ui.md` 规定 “Gap visibility/collapsed mode is controlled by
  the header icon only”。正因为没有别的状态提示，这个图标就是唯一的线索，
  而它现在既不变色，实心和空心的含义也和习惯相反。用户切换后，只能从时间线内容
  的变化去猜当前处于哪种模式。
- **Expected behavior**：折叠时按钮处于“按下”的激活态（强调色图标加浅色底），
  展开时为普通态；图标固定为同一个符号，不靠实心和空心区分状态。
- **Suggested fix**：改为 `Toggle(isOn:)` 搭配 `.toggleStyle(.button)`，
  系统会提供激活态外观和无障碍的 `isSelected`。图标固定为
  `arrow.left.and.right.square`。同时在 Timeline 菜单增加 “Hide Gaps Without Video”，显示勾选状态。
- **Validation**：focused test 覆盖菜单项和按钮读取同一个状态；手动检查外观。

## P2：与 macOS 惯例冲突

### [P2] 预览轨道可见性菜单的入口不清楚

- **Status**：已完成（2026-11-05）：pull-down “Preview Layers” 加 “N of M”；标签列每条轨道有 eye 开关，标签列加宽到 84pt。
- **Evidence**：`TimelineView.swift:12-27`。左侧是一个 “Preview” 文字标签，
  后面跟一个 `eye` 图标的 `Menu`，没有菜单指示器。
- **HIG basis**：`hig-components-menus/pull-down-buttons`（pull-down 按钮要显示指示器，
  让用户知道点击会打开菜单）；`buttons`（图标按钮要清楚表达用途）。
- **Problem**：“Preview” 标签看起来像这个面板的标题，而不是 eye 按钮的说明；
  eye 图标通常表示“显示或隐藏”，用户点了以为会隐藏什么，结果弹出一个菜单。
  有轨道被禁用时，按钮外观也没有任何变化。
- **Suggested fix**：
  - 改为一个带指示器的 pull-down：`Label("Preview Layers", systemImage: "eye")`，
    使用 `.menuIndicator(.visible)`。
  - 有轨道被禁用时，图标换成 `eye.slash` 并显示数量，例如 “2 of 3”。
  - 更理想的做法是把可见性开关放回标签列，每条轨道前面一个 eye（FCP 和 Resolve
    的轨道开关都在轨道头上），header 的菜单只作为批量入口。

### [P2] 缩放滑杆的数值没有单位，两端没有按钮

- **Status**：已完成（2026-11-05）：读数为可见时长，两端有放大镜按钮，右侧 Fit 按钮。
- **Evidence**：`TimelineView.swift:39-53`。滑杆范围是 0...100 的非线性映射，
  右侧读数显示 “Fit” 或像素每秒的原始数字（如 `37`、`4.5`）。
- **HIG basis**：`hig-components-controls/sliders`（可以在两端放图标表示最小值和
  最大值；数值读数要让用户看得懂）。
- **Problem**：“37” 对用户没有意义，看不出放大了多少，也不能据此回到同一个缩放级别。
- **Suggested fix**：
  - 两端加 `minus.magnifyingglass` 和 `plus.magnifyingglass` 的小按钮，
    分别对应 ⌘- 和 ⌘+。
  - 读数改为“可见时长”，例如 “2 min” 或 “30 s”，比像素每秒更容易理解；
    或者干脆去掉读数，只在 Fit 状态下显示 “Fit”。
  - 读数右侧可以放一个 “Fit” 按钮，对应 ⇧Z。

### [P2] Clip 选择不支持修饰键

- **Status**：已完成（2026-11-05）：⌘ 点击、Shift 点击（同一轨道）、⌘A（Edit > Select All）。
- **Evidence**：`mouseDown` 在命中 clip 时直接调用 `project.selectClip`
  （`TimelineView.swift:629-630`），不读 Shift 和 Command。多选只能靠框选。
  也没有 ⌘A 选择全部 clip。
- **HIG basis**：`hig-inputs/pointing-devices`、`keyboards`（⌘ 点击切换单项选择，
  Shift 点击扩展选择，⌘A 全选，这些是 macOS 的通用约定）。
- **Suggested fix**：⌘ 点击切换该 clip 是否选中；Shift 点击选中同一轨道上从锚点到
  当前 clip 的范围；时间线获得焦点时，⌘A 选择全部 clip。
  修改都走 `project.selectClips`，不新增选择状态。

### [P2] 右键菜单的作用范围混在一起

- **Status**：已完成（2026-11-05）：删除轨道写成 “Delete Layer 1…” 并在 sheet 中确认。
- **Evidence**：`TimelineView.swift:688-736`。
  - 右键 clip 时，菜单同时包含 clip 操作和 “Delete Layer 1”，后者删除整条轨道。
  - 右键空白轨道时，菜单里只有 “Delete Layer 1” 这一项。
  - “Apply +1.23s Offset to All Clips in Layer 1” 很长，而且菜单项没有显示快捷键。
  - 多选 clip 后右键，菜单只作用于被点击的那一个，同时把多选改成单选。
- **HIG basis**：`hig-components-menus/context-menus`（菜单只包含与被点击对象相关的
  命令；破坏性操作放在最后并标明；保持菜单简短）。
- **Problem**：右键 clip 想删 clip，却容易点到删除整条轨道。虽然能撤销，
  但误操作的代价很高。
- **Suggested fix**：
  - Clip 菜单：“Apply Offset to Layer”、“Reset Offset”、分隔线、
    “Delete Clip ⌫”。偏移量放到 `.help`，或者作为灰色的副标题。
  - 删除轨道只在右键**标签列**或空白轨道时出现，写成 “Delete Layer 1…”。
  - 右键已选中的 clip 时保留多选，菜单作用于全部选中项，与 Media Pool 的规则一致。

### [P2] 悬停读数只给指针位置

- **Status**：已完成（2026-11-05）。
- **Evidence**：`RulerHoverTooltip` 固定 220pt 宽、10pt 字号，内容为
  “时间 • 时刻 • 距离”（`TimelineView.swift:221-268`）。悬停 Activity 分段时显示
  分段信息。
- **HIG basis**：`hig-foundations/typography`（macOS 上避免小于 10pt 的文字；
  10pt 已经是下限）；`hig-patterns/feedback`。
- **Problem**：读数很有用，但字号小、宽度固定，长内容会被截断。
- **Suggested fix**：字号提高到 11pt，宽度随内容自适应。不新增播放头时间读数
  （产品决定，见 Preview 评审）。

## P3：打磨

- **规范与实现不一致**（已完成，2026-11-05：`timeline-ui.md` 已改为 Activity，并删去拖动 Activity 轨的描述）：
  - `timeline-ui.md` 的 Label Column 写的是 `FIT`，实现已经改为 `Activity`
    （`TimelineView.swift:550`）。应以实现为准，更新规范。
  - FIT Track 一节同时写了 “The Activity layer is currently not draggable” 和
    Interaction Rules 中的 “FIT track drag changes FIT alignment”，两者矛盾；
    实现中点击 Activity 轨直接返回（`TimelineView.swift:625-627`）。
- **Clip 标题字号**：11pt 白字，叠在 72% 不透明度的蓝色上。未选中的 clip
  对比度偏低，建议未选中时也使用不透明的底色，靠描边区分选中。
- **Lap 颜色**：WU / RUN / REST / CD 只用颜色区分，悬停才有文字。
  宽度足够时，在分段内绘制缩写文字。
- **播放头颜色写死**：`timelinePlayheadRed` 是固定值，Increase Contrast 下不会加深。
- **`NSApplication.shared.activate(ignoringOtherApps:)`**：`mouseDown` 中主动激活应用
  （`TimelineView.swift:615`）。这个 API 在 macOS 14 起已弃用，而且点击本来就会
  激活窗口，建议删除。已删除（2026-11-05）。

## 要不要做成 FCP 时间线的样子

值得借鉴的部分：

| 借鉴 | 原因 |
| --- | --- |
| 轨道头上的可见性开关 | 状态就在被控制的对象旁边 |
| 指针随命中区域变化，不可用时显示禁止符号 | 标准指针反馈 |
| ⌘ 点击、Shift 点击、⌘A、框选 | 标准选择约定 |
| 缩放滑杆两端的放大镜图标 | HIG 推荐的滑杆形式 |

不必借鉴的部分：磁性时间线、连接片段、多种编辑工具（Blade、Trim、Position）。
本项目的时间线用于对齐，不是剪辑，`timeline-ui.md` 也明确把 trim 和 snapping
排除在外。

## 建议的落地顺序

1. 修复 C 键吞字（P1，改动很小，收益直接）。
2. 折叠按钮改为 toggle 按钮，增加对应的菜单项（P1，改动小）。
3. 指针反馈（P1，改动集中在 `TimelineCanvasNSView`）。
4. Clip 选择修饰键、右键菜单整理（P2；涉及选择语义，需要人工评审）。
5. 预览轨道可见性入口、缩放滑杆两端按钮和读数（P2）。
6. 无障碍元素（P1，工作量最大，可以分两步：先做播放头和 clip，再做 Activity 分段）。
7. P3 打磨，同步修正 `timeline-ui.md` 中与实现不一致的描述。
