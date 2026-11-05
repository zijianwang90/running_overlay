# Inspector HIG 契合度检查

Last updated: 2026-11-04

本文按 [HIG UI Validation Workflow](../../hig-ui-validation.md) 的记录格式，对
Inspector 的各个状态做一次 macOS HIG 契合度检查，并给出符合 HIG 的控件设计方向。
配套设计稿：[inspector-hig-mockup.html](inspector-hig-mockup.html)（浏览器直接打开）。

这是一份评审记录，不是新的设计规范。结论被采纳后，应把对应条目合并进
[Inspector UI Design Spec](inspector-ui.md)，再按条目开 issue 实施。

## 范围

已检查：

| 状态 | 入口 | 实现 |
| --- | --- | --- |
| Outer：Added Overlays 列表 | `selection == .none` / `.timelineClips` | `ParameterPanelView.swift` `InspectorOuterView`、`OverlayElementRow` |
| Outer：空列表 | 无 overlay | `AddedOverlaysSection` |
| Detail：Overlay 切换条 | 两个及以上 overlay | `OverlaySwitcherBar` |
| Detail：Overlay 详情（以 Route Map 为例） | `selection == .overlayElement` | `RouteMapOverlayDetailView.swift` 与 `InspectorRows/*` |
| Detail：Section 开关关闭后的禁用态 | Background Map 关闭 | `RouteMapOverlayDetailView.swift` |
| Detail：Clip 详情 | `selection == .timelineClip` | `ClipDetailView` |
| Footer：Reset / Done | 所有详情页 | `InspectorDetailFooterBar` |

未检查：运行时的 VoiceOver 朗读顺序、Full Keyboard Access 的实测、
Increase Contrast，以及 Overlay Pool。这几项需要真机窗口，下一轮补。

依据的 HIG skill：`hig-components-controls`（toggles、sliders、
segmented-controls、text-fields、steppers）、`hig-components-menus`（buttons、
pop-up-buttons、disclosure-controls、context-menus）、`hig-components-layout`
（panels、lists-and-tables）、`hig-foundations`（typography、color、dark-mode、
accessibility）。

## 结论摘要

整体信息架构没问题：右侧 inspector、两栏布局（左标签、右控件）、可折叠分组、
共享模块都和 HIG 一致。问题集中在**控件层**：多处控件是自绘的，看上去像系统
控件，行为却不一样。另外，详情页沿用了 iOS 的导航栈和模态提交模型（Back、Done），
而 macOS 的 inspector 是非模态的。

明确违背 HIG 的有 5 项（P1），见下文 1–5。剩下的是一致性或打磨层面的问题。

## P1：明确违背 HIG

### [P1] 滑杆旁的数值框看起来能编辑，其实不能

- **Surface**：所有 `InspectorDenseSliderRow`（Scale、Width、Height、Opacity、
  Size、Map Opacity、Map Zoom 等，覆盖所有 overlay）。
- **Evidence**：`InspectorRows/InspectorDenseComponents.swift:87-95`。数值用
  `Text(displayText)` 渲染，外面套了和输入框完全相同的背景、圆角和描边。
- **HIG basis**：`hig-components-controls/sliders`（建议给滑杆配一个对应的文本框
  和 stepper）、`hig-components-controls/text-fields`（数值输入使用 number
  formatter）、`hig-components-menus/buttons`（每个控件都应清楚表达自身用途）。
- **Project basis**：`inspector-ui.md` Interaction Rules 规定数值字段在 submit 时提交。
- **Problem**：用户点进去没有反应，没法输入精确值，比如 Width 376 → 380。
  外观在暗示可编辑，实际只能看。
- **Expected behavior**：数值框是真正的 `TextField`，带 number formatter，
  回车或失焦时提交；↑/↓ 按 1 个步长调整，Shift+↑/↓ 按 10 个步长调整；
  可以附带一个小号 stepper。
- **Suggested fix**：把 `InspectorDenseSliderRow` 的 readout 换成
  `InspectorBufferedNumberField` 的同类实现，复用 `finishContinuousEdit()`
  的撤销分组。如果某行确实只读，就去掉输入框外观，只保留次级文字。
- **Validation**：focused test 验证输入值会 clamp 到 range，并且只注册一个撤销点；
  手动检查 Tab 顺序。

### [P1] 自绘按钮没有按下态和悬停态

- **Surface**：Outer 行上的 eye、lock、trash，行主体；详情页 Back、Trash；
  切换条的 ↑/↓。
- **Evidence**：`ParameterPanelView.swift:730-760` `InspectorIconButton` 使用
  `.buttonStyle(.plain)`，并在 label 里自绘背景；`OverlayElementRow` 的行主体
  也是 `.plain`（`ParameterPanelView.swift:510-516`）。
- **HIG basis**：`hig-components-menus/buttons`（自定义按钮必须有按下态）。
- **Problem**：点击时没有视觉反馈，用户分不清是否点中、是否生效。
  加上撤销以后也看不出有没有删掉。
- **Expected behavior**：图标按钮至少要有按下态和悬停态；hover 时出现底色，
  按下时加深。
- **Suggested fix**：新增一个 `ButtonStyle`，读取 `configuration.isPressed`，
  用 `onHover` 驱动悬停底色，替换 `.plain`。或者直接用
  `.buttonStyle(.borderless)` 搭配 `.controlSize(.small)`，系统会提供状态。
- **Validation**：手动检查；无需快照。

### [P1] Added Overlays 不是列表：没有选中态，也不支持键盘操作

- **Surface**：Inspector Outer。
- **Evidence**：`OverlayElementRow` 是若干张卡片组成的 `VStack`，每张卡片是一个
  `Button`（`ParameterPanelView.swift:476-590`）。
- **HIG basis**：`hig-components-layout/lists-and-tables`（用户选中列表项时要给出
  恰当反馈；macOS 列表应使用平台的行样式）、`hig-inputs/keyboards`。
- **Problem**：
  - 在 Preview 或 Timeline 选中某个 overlay 后，回到列表看不到它被选中。
  - 不能用 ↑/↓ 移动选择，不能用 Return 打开，不能用 ⌫ 删除。
  - 每一行都常驻 3 个带边框的图标按钮，6 行一共 18 个，其中 6 个是红色垃圾桶。
- **Expected behavior**：
  - 使用标准 `List` 并绑定 selection，选中行显示系统选中底色。
  - 双击或 Return 进入详情，⌫ 删除（可撤销），⌘D 复制。
  - eye 和 lock 只在非默认状态（已隐藏、已锁定）时常驻；悬停时才显示全部操作。
  - 删除收进右键菜单，并支持 ⌫。
- **Suggested fix**：用 `List(selection:)` 替换 `VStack + ForEach`；行内动作使用
  `.borderless` 图标按钮，用 hover 控制显隐；右键菜单沿用
  `OverlayElementContextMenu`。
- **Validation**：focused test 覆盖 selection 同步和删除撤销；手动检查键盘操作。

### [P1] 父开关关闭后，子控件的禁用态不一致

- **Surface**：Background Map 关闭时；Background、Border、Stats Bar 等带
  header 开关的分组。
- **Evidence**：截图里 Map Style、Opacity、Zoom 都变灰了，但 Map POIs 的开关
  仍可操作（`RouteMapOverlayDetailView.swift:173` 没有传 `isEnabled`）。
  另外，禁用是用 `.opacity(0.5)` 整行降透明度实现的
  （`InspectorDenseComponents.swift:98`），文字对比度会低于 WCAG AA。
- **HIG basis**：`hig-components-controls/toggles`（存在设置层级时使用 checkbox；
  控件的状态要准确反映在外观上）、`hig-foundations/accessibility`（对比度）。
- **Problem**：用户以为 POI 能独立打开。实际上它对渲染没有效果，因为底图已经关了。
- **Expected behavior**：父级关闭时，所有子行使用系统的 `.disabled(true)`，
  标签改用 tertiary label 颜色，同时保留可读性。
- **Suggested fix**：在 section 层统一下发 `.disabled(!isEnabled)`，删除逐行的
  `isEnabled` 参数和 opacity 降级。
- **Validation**：focused test 断言 POI 行在 map 关闭时处于禁用状态。

### [P1] 占位按钮永远禁用

- **Surface**：Inspector 顶栏右侧的 filter/settings 按钮。
- **Evidence**：`ParameterPanelView.swift:690`，`isEnabled: false` 是写死的，
  action 为空。
- **HIG basis**：`hig-components-menus/buttons`（每个按钮都要清楚表达用途）；
  macOS 上禁用态的含义是“当前上下文不可用”，而不是“将来才会有”。
- **Problem**：用户会去找什么条件能让它可用，但这个条件并不存在。
- **Suggested fix**：在 filter 功能实现之前，先移除这个按钮。
- **Validation**：无需测试。

## P2：与 macOS 惯例冲突

### [P2] 详情页使用 iOS 式导航栈和模态提交

- **Evidence**：一个详情页同时有 Back、Overlay 切换条（弹出菜单加 ↑/↓）、
  底部 Reset 和 Done，共 3 套导航方式，外加一个“提交”按钮。
- **HIG basis**：`hig-components-layout/panels`（inspector 是非模态的，
  修改即时生效）；`hig-components-menus/buttons`（醒目样式只留给最可能执行的
  操作，而这里根本没有需要“完成”的操作）。
- **Problem**：蓝色大号 Done 暗示“不点就不保存”，但修改其实已经实时写入模型。
  Reset 和 Done 并排放置也很危险：Reset 会清空整个样式，却和 Done 一样显眼、
  距离很近。
- **Expected behavior**：
  - inspector 内容跟随选择：没有选择时显示列表，有选择时显示详情。
    在画布空白处点击或按 Esc 取消选择，即回到列表。
  - 顶部只保留一个 pop-up 切换器，加上 ↑/↓（或 ⌘[ / ⌘]）。
  - Reset 收进标题栏的 `⋯` 菜单，菜单项为 “Reset Style”；每个 section 在
    hover 时显示一个复位按钮（参考 FCP 的分组复位）。
  - 删除 Done 和 footer。
- **Note**：这项改动牵涉撤销语义和选择语义，按 AGENTS.md 需要人工评审。

### [P2] 折叠控件方向和位置不符合 macOS 惯例

- **Evidence**：`NumericOverlayDetailView.swift:813` 在行尾使用
  `chevron.up` / `chevron.down`。
- **HIG basis**：`hig-components-menus/disclosure-controls`。macOS 的
  disclosure triangle 收起时指向右（▸），展开时指向下（▾），并放在标题前，
  旁边有描述性标签。
- **Suggested fix**：把折叠三角放在 header 前部，使用 ▸ / ▾；也可以采用
  Xcode 和 FCP 的做法，在 hover 时于行尾显示 “Show” / “Hide” 文本按钮，二选一。
  分组标题前的装饰图标是可选项，去掉后会更接近系统 inspector。

### [P2] 用 switch 替代 checkbox

- **Evidence**：Background Map、Background、Border、Stats Bar 的 header 开关，
  以及 Map POIs、Shadow、Glow、Fade Out 的行内开关，都是 mini switch。
- **HIG basis**：`hig-components-controls/toggles`（macOS 上一般不要用 switch
  替代 checkbox；存在设置层级时使用 checkbox；单个开关设置优先用 checkbox）。
- **Problem**：section header 的开关控制着一组子设置，这正是 HIG 所说的
  “层级设置”。switch 在 macOS 上应保留给需要强调的单项设置，比如顶层的
  “启用此功能”。
- **Suggested fix**：header 使用标题前的 checkbox（FCP 的效果开关也是这样做的），
  行内开关同样改为 checkbox。同时去掉对 switch 的自定义 tint。

### [P2] 弹出菜单外观不是 pop-up button

- **Evidence**：Map Style 和切换器都使用 `InspectorDenseMenuLabel` 自绘，
  只有一个 `chevron.down`，切换器甚至设置了 `.menuIndicator(.hidden)`。
- **HIG basis**：`hig-components-menus/pop-up-buttons`。macOS 上，“从一组互斥值中
  选一个”用 pop-up button，其指示器是上下双箭头（⌃⌄）；单箭头属于 pull-down
  菜单（执行命令）。
- **Suggested fix**：使用系统 `Picker` 的 `.menu` 样式（会渲染成 `NSPopUpButton`），
  搭配 `.controlSize(.small)`，不再自绘。

### [P2] Outer 列表的删除按钮常驻红色

- **Evidence**：6 个常驻红色的垃圾桶。规范 `inspector-ui.md` 原文要求
  “use danger.red on hover or confirmation affordance, not constant bright red”，
  当前实现与规范本身冲突。
- **HIG basis**：`hig-components-menus/buttons`（destructive role 不要被过度强调）。
- **Suggested fix**：见上文 P1“Added Overlays 不是列表”的方案，删除收进右键菜单并支持 ⌫。

### [P2] 字号和控件尺寸脱离系统度量

- **Evidence**：
  - Outer 标题 22pt，加上营销式副标题 “Manage overlays in your scene”。
  - 详情页正文 12pt、caption 10pt、section 13pt，与 Outer 的 13/15/22pt 是两套体系。
  - 控件高 26pt、行高 34pt，都是自定义值。
- **HIG basis**：`hig-foundations/typography`（macOS 正文默认 13pt；small 控件
  11pt，小于 10pt 的文字应避免）；`hig-components-layout/panels`（panel 标题
  要简短，并说明用途）。
- **Suggested fix**：
  - 统一使用系统 text style：标题 `.headline` 13pt semibold，正文 `.body`
    13pt 或 `.callout` 12pt，数值用 `.monospacedDigit()`。
  - 控件统一 `.controlSize(.small)`：高约 19–22pt，行高 24–28pt。
    这比现在更紧凑，接近 FCP 的密度，又是系统原生的。
  - 删除副标题。

## P3：打磨

- **标题重复**：切换条已经显示 “1 / 6 Route Map”，详情头又显示一次
  “Route Map”，另外还有一个没有信息量的 `Overlay` 徽章。建议合并成一个 header：
  pop-up 切换器 + 实时数值 + `⋯` 菜单。
- **坐标单位不明**：Position 显示 0.111 / 0.204，没有单位。建议显示为百分比，
  或标注 “Normalized”。也可以提供 px 显示，同时保持归一化存储，
  不改变时间域和空间域的模型约定。
- **Outer 行副标题重复**：“Route Map • Map” 里的名字和副标题重复。建议副标题
  只保留类型，或者干脆删掉。
- **自定义 tint**：segmented control 被设成蓝色实心（`.tint(accentBlue)`）。
  macOS 的选中段默认就使用系统强调色，去掉 tint 后才会尊重用户设置的系统强调色。
- **颜色写死为 hex**：`EditorTheme` 全部是固定色值，不跟随 Increase Contrast。
  只做深色模式是可以接受的产品决定（FCP 也只有深色），但颜色应该映射到语义色
  （`labelColor`、`secondaryLabelColor`、`separatorColor`、
  `controlAccentColor`），这样高对比度模式能自动生效。

## 要不要完全模仿 FCP

**不需要，也不建议。** FCP 是 Apple 自家的专业应用，但它本身并不是 HIG 的样板：
大量控件是自绘的，文字小、对比度低，数值文字可以拖动却没有任何视觉提示，
还有一整套关键帧体系。照搬的成本很高，而且会把它不符合 HIG 的部分一并继承过来。

值得借鉴的是它的**布局和交互模型**，因为这部分恰好和 HIG 一致：

| 借鉴 FCP | 原因 |
| --- | --- |
| 左标签、右控件的两栏布局，行高约 24pt | 密度合适，扫读效率高 |
| 滑杆 + 可编辑数值 + 单位后缀 | 对应 HIG“滑杆配文本框”的建议 |
| section 标题前用 checkbox 启用效果 | 对应 HIG“层级设置用 checkbox” |
| hover 时显示 Show/Hide 和分组复位 | 不常用的操作只在需要时出现，降低噪音 |
| inspector 跟随选择，没有 Done 和 Back | macOS inspector 的标准模型 |
| 顶部用 pop-up 显示当前对象和预设 | 标准 pop-up button |

不必借鉴的部分：

- 自绘的滑块和灰色调：用系统控件即可，自动获得状态、辅助功能和强调色。
- 关键帧菱形按钮：项目模型里没有动画关键帧，按 `inspector-ui.md` 的规定，
  不要做看起来能保存、实际却存不下来的 UI。
- 顶部的多 tab（Text / Video / Info）：overlay 的属性量还用不上 tab，
  折叠分组已经够用。
- 10–11pt 的小字：跑者和创作者不是全天候剪辑师，保持 12–13pt。

更贴切的参照物是 **Keynote / Pages 的 Format inspector** 和 **Xcode 的
Attributes inspector**：全部使用系统控件（small 尺寸），有 disclosure triangle、
checkbox、“文本框 + stepper”组合、pop-up button，密度接近 FCP，但完全符合 HIG。

## 建议的落地顺序

1. 数值框可编辑，并统一按钮的按下态和悬停态（P1，改动集中在 `InspectorDense*`
   原语，所有 overlay 同时受益）。
2. 修正禁用态下发，移除占位按钮（P1，改动小）。
3. Outer 改为 `List(selection:)`（P1，需要人工评审选择语义）。
4. checkbox、disclosure triangle、pop-up button 换回系统控件（P2，统一在共享模块里改）。
5. 移除 Done 和 footer，Reset 收进菜单（P2，需要人工评审撤销语义和选择语义）。
6. 统一字号和控件尺寸（P2，可能影响视觉快照，需要人工评审）。
