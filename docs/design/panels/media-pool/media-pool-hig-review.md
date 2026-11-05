# Media Pool HIG 契合度检查

Last updated: 2026-11-05

本文按 [HIG UI Validation Workflow](../../hig-ui-validation.md) 的记录格式，对左侧
Pool 面板的 Media 模式做一次 macOS HIG 契合度检查，并给出符合 HIG 的控件方向。
配套设计稿：[media-pool-hig-mockup.html](media-pool-hig-mockup.html)（浏览器直接打开）。

这是一份评审记录，不是新的设计规范。结论被采纳后，应把对应条目合并进
[Media Pool UI Design Spec](media-pool-ui.md)，再按条目开 issue 实施。
写法与 [Inspector HIG 契合度检查](../inspector/inspector-hig-review.md) 一致，
两份文档里重复出现的问题（按钮状态、pop-up 外观、字号）在这里只给出差异。

## 范围

已检查：

| 状态 | 入口 | 实现 |
| --- | --- | --- |
| Pool 模式切换 | 窗口工具栏 | `PoolPanelView.swift` `PoolModeSwitch` |
| Header 工具按钮 | Media 模式 | `MediaBrowserView.swift` `header` |
| 搜索与状态过滤 | Media 模式 | `searchAndFilterStrip`、`MediaFilterChipStyle` |
| Activity 状态行 | 已导入 FIT/GPX 且有媒体 | `fitStatusRow` |
| 媒体行与文件夹行 | 有媒体 | `mediaRowContainer`、`folderRow`、`MediaStatusDot` |
| 选择与键盘 | 有媒体 | `handleMediaTap`、`MediaBrowserKeyCaptureView` |
| 右键菜单 | 媒体行、文件夹行、空白处 | 各 `.contextMenu` |
| 空状态 | 无 Activity / 无媒体 / 过滤为空 | `fitImportPlaceholder`、`videoImportPlaceholder`、`emptyFilterPlaceholder` |
| 拖放 | 从 Finder 拖入，行拖到 Timeline 或文件夹 | `importDroppedVideoFiles`、`handleDrop` |

未检查：VoiceOver 实际朗读顺序、Full Keyboard Access 实测、Increase Contrast。
Overlay Pool 和 Templates 只在文末附录简单记录，不展开。

依据的 HIG skill：`hig-components-layout`（lists-and-tables、outline-views、
sidebars、panels）、`hig-components-search`（search-fields）、
`hig-components-controls`（segmented-controls）、`hig-components-menus`
（buttons、pop-up-buttons、context-menus、disclosure-controls）、
`hig-patterns`（drag-and-drop、undo-and-redo、file-management）、
`hig-inputs`（keyboards、pointing-devices）、`hig-foundations`
（color、accessibility、typography）。

## 结论摘要

功能完整，信息架构合理：资源库式的左栏、文件夹分组、按状态过滤、右键匹配到图层，
都和专业剪辑软件的 bin 一致。问题集中在**列表本身**：它是用 `LazyVStack` 拼出来的，
外观像 outline view，但缺少 outline view 的大部分行为。键盘只支持 ⌘A，
文件夹不能被选中，选中态不区分窗口焦点。另外，媒体选择和项目选择是两套互不相知的状态，
存在误删风险，需要实测确认。

明确违背 HIG 的有 4 项（P1），见下文 1–4。P1 和 P2 条目按出现顺序编号为 1–10，
与设计稿中的黄色编号一一对应。

## P1：明确违背 HIG

### [P1] 媒体列表不支持键盘操作

- **Surface**：所有媒体行和文件夹行。
- **Evidence**：`MediaBrowserView.swift:1082-1089`。`MediaBrowserKeyCaptureView`
  只拦截 ⌘A，其他按键交给 `super.keyDown`。列表本身是 `ScrollView + LazyVStack`
  （`MediaBrowserView.swift:259-287`），点击用 `onTapGesture` 识别
  （`MediaBrowserView.swift:417`）。
- **HIG basis**：`hig-components-layout/lists-and-tables`、`outline-views`（macOS
  列表要支持键盘导航，用户选中时要给出反馈）；`hig-inputs/keyboards`（支持
  用户熟悉的标准快捷键）。
- **Problem**：
  - ↑/↓ 不能移动选择，Shift+↑/↓ 不能扩展选择。
  - Return 不能预览，Space 不能快速查看，⌘⌫ 不能删除。
  - ←/→ 不能收起或展开文件夹。
  - Tab 无法把焦点移进列表（`focusRingType` 被设为 `.none`），
    Full Keyboard Access 用户进不来。
- **Expected behavior**：
  - ↑/↓ 移动选择，Shift+↑/↓ 扩展选择，⌘A 全选。
  - ←/→ 收起和展开文件夹；Option+←/→ 递归处理。
  - Return 开始源预览（等同当前的双击）。
  - ⌘⌫ 从 Media Pool 删除，可撤销。
  - 列表获得焦点时显示焦点环，或者用强调色选中底色表示焦点。
- **Suggested fix**：改为 `List(selection:)`，用 `OutlineGroup` 或
  `DisclosureGroup` 表达文件夹层级。系统会提供上面的大部分键盘行为、
  焦点环和 Full Keyboard Access。保留现有的斑马纹和行高，用 `.listRowBackground`
  实现。
- **Validation**：focused test 覆盖选择和删除后的撤销；手动检查键盘操作和 Tab 顺序。

### [P1] 媒体选择与项目选择互不感知，⌫ 可能删错对象（需实测）

- **Surface**：先选中 overlay 或 clip，再点击媒体行。
- **Evidence**：
  - 媒体选择是视图内部状态 `@State selectedMediaIDs`（`MediaBrowserView.swift:7`），
    `handleMediaTap` 不修改 `project.selection`（`MediaBrowserView.swift:548-577`）。
  - `MainEditorView.swift:215-224` 的 `.onKeyPress(.delete)` 调用
    `project.deleteSelectedItem()`，删除的是 `project.selection`，
    也就是之前选中的 overlay 或 clip（`ProjectDocument.swift:3117-3127`）。
- **HIG basis**：`hig-components-layout/lists-and-tables`（选中反馈要准确）；
  `hig-patterns/undo-and-redo`（撤销能补救，但不能代替正确的目标）。
- **Problem**：用户在 Media Pool 选中两个片段后按 ⌫，以为删的是片段。
  如果按键事件沿响应链到达 SwiftUI 的 `onKeyPress`，实际删掉的会是右侧
  Inspector 里还开着的那个 overlay。即使事件没有到达，Inspector 仍然显示 overlay
  详情，与 Media Pool 的选中态同时出现两个“当前选择”。
- **Expected behavior**：同一时刻只有一个键盘焦点区域，删除只作用于该区域的选择。
  在 Media Pool 中选中媒体时，Inspector 回到列表状态，或者显示媒体信息。
- **Suggested fix**：
  - 媒体获得选择时调用 `project.clearSelection()`。
  - `⌫` 由拥有焦点的视图处理：Media Pool 删除媒体，Timeline 删除 clip，
    Preview 删除 overlay。`MainEditorView` 的全局 `onKeyPress(.delete)` 只在
    Preview 或 Inspector 拥有焦点时生效。
  - 是否需要把媒体选择提升进 `ProjectDocument.selection`，按 AGENTS.md 属于选择
    语义变更，需要人工评审。
- **Validation**：先手动复现。如果能复现，用 focused test 断言“选中媒体后
  `project.selection == .none`”。

### [P1] 文件夹行不能被选中，单击就展开

- **Surface**：文件夹行。
- **Evidence**：`MediaBrowserView.swift:360-366`，整行 `onTapGesture` 直接调用
  `toggleFolderExpansion`。另外，收起文件夹时会悄悄丢掉其中已选中的媒体
  （`MediaBrowserView.swift:606-619`）。
- **HIG basis**：`hig-components-layout/outline-views`（用 disclosure triangle 展开
  和收起，行本身负责选择）；`hig-components-menus/disclosure-controls`。
- **Problem**：
  - 不能选中文件夹，于是不能对文件夹按 ⌫，也不能拖动文件夹。
  - 想点文件夹名字选中它，结果它展开了，列表随之跳动。
  - 收起文件夹会改变选择，而用户并没有点任何媒体。
- **Expected behavior**：单击行只选中文件夹；单击 disclosure triangle，或者按
  ←/→，才展开和收起；双击行切换展开。收起文件夹时，选择移到文件夹本身
  （Finder 的做法），不要静默丢弃。
- **Suggested fix**：随上一条改为 `List` + `OutlineGroup` 一并解决。
- **Validation**：focused test 断言收起文件夹后选择不会静默丢失。

### [P1] 状态只用颜色区分

- **Surface**：每行右侧的对齐状态点，Activity 状态行左侧的绿点。
- **Evidence**：`MediaStatusDot` 用 8pt 圆点区分绿、黄、灰三种状态
  （`MediaBrowserView.swift:1159-1198`），只有 hover 时的 `.help` 能看到文字。
- **HIG basis**：`hig-foundations/color`（不要只靠颜色传达信息）；
  `hig-foundations/accessibility`（色觉差异）。
- **Problem**：红绿色弱用户分不清绿色“已在时间线上”和黄色“可匹配”，
  而这正是用户导入后最需要看的信息。
- **Expected behavior**：状态同时用形状或符号表达，例如
  `checkmark.circle.fill`（已对齐）、`clock.badge`（可匹配）、
  `questionmark.circle`（需手动放置），颜色作为辅助。
- **Suggested fix**：把圆点换成 11–12pt 的 SF Symbol，保留现有颜色和 `.help`。
  同时让 `MediaStatusFilter` 的过滤条使用同样的符号，过滤条和行状态一一对应。
- **Validation**：手动检查；可以选做开启 Differentiate Without Color 时的截图。

## P2：与 macOS 惯例冲突

### [P2] Header 工具按钮重复了标准命令

- **Evidence**：`MediaBrowserView.swift:83-102`，“全选”（`checklist`）和
  “清除选择”（`xmark.circle`）做成了常驻的图标按钮。
- **HIG basis**：`hig-components-menus/buttons`、`toolbars`（工具栏只放常用、
  且没有别的入口的命令）。全选是 Edit 菜单里的标准命令（⌘A），
  清除选择是点击空白处或按 Esc。
- **Problem**：三个按钮里有两个是低频命令，占据了宝贵的标题栏位置；
  `xmark.circle` 也容易被误解成“关闭面板”。
- **Suggested fix**：Header 只保留 “New Folder” 和 “Import Media”（`plus`）。
  “Select All” 交给 ⌘A 和右键菜单；清除选择交给点击空白处和 Esc。

### [P2] 搜索框和过滤条是自绘的

- **Evidence**：搜索框是 `TextField(.plain)` 加自绘放大镜和清除按钮
  （`MediaBrowserView.swift:108-135`）；All / Ready / Aligned 是三个
  `MediaFilterChipStyle` 按钮（`MediaBrowserView.swift:151-158`）。
- **HIG basis**：`hig-components-search/search-fields`（使用系统 search field，
  提供 ⌘F 和清除按钮）；`hig-components-controls/segmented-controls`
  （互斥选项使用 segmented control）。
- **Problem**：
  - 没有 ⌘F，Esc 也不会清空搜索。
  - 三个 chip 外观像独立的按钮，看不出是互斥的一组。
  - 选中的 chip 是写死的蓝色，不跟随系统强调色。
- **Suggested fix**：搜索使用 `NSSearchField`（或 `.searchable`），绑定 ⌘F，
  Esc 清空。过滤改为 `Picker(.segmented)` 搭配 `.controlSize(.small)`，
  选项可加符号，与 P1 中的状态符号对应。

### [P2] “Replace” 是网页式下划线链接，Workout type 菜单没有指示器

- **Evidence**：`MediaBrowserView.swift:218-227` 与 `818-827` 用带下划线的文字
  按钮替换 Activity。`MediaBrowserView.swift:197-216` 与 `237-256`
  的 Workout type 菜单 `.menuStyle(.borderlessButton)` 只显示文字，
  而且实现了两份。
- **HIG basis**：`hig-components-menus/buttons`（macOS 上用 link 样式表示跳转，
  不用于替换数据这类操作）、`pop-up-buttons`（互斥值选择用 pop-up，
  要显示上下箭头指示器）。
- **Problem**：“Replace” 看起来像网页链接，用户不确定点了会去哪；
  Workout type 看起来是普通文字，用户发现不了它可以切换。
- **Suggested fix**：把 Activity 状态行做成一个小卡片：文件名、摘要、
  一个 small pop-up（Workout type），外加一个 `⋯` 菜单，里面放
  “Replace Activity…” 和 “Show in Finder”。两处 Workout type 实现合并为一个组件。

### [P2] 选中态不区分窗口焦点

- **Evidence**：`rowBackground` 只看 `selectedMediaIDs`
  （`MediaBrowserView.swift:887-895`），选中行一直是同一种蓝灰底色，
  左侧再加 2px 蓝条。
- **HIG basis**：`hig-components-layout/lists-and-tables`（macOS 列表在拥有焦点时用
  强调色表示选中，失去焦点时改为灰色）。
- **Problem**：点进 Timeline 后，Media Pool 的选中行看起来仍然处于激活状态，
  用户不知道键盘命令会作用到哪里。这也会放大上文 P1 的误删问题。
- **Suggested fix**：使用 `List` 的系统选中样式，焦点在列表时显示强调色，
  不在时显示灰色。如果坚持保留自绘配色，也要读取
  `@Environment(\.controlActiveState)` 和焦点状态，提供两套底色。

### [P2] 拖入视频时，不合法的拖放也显示“可以放下”

- **Evidence**：`importDroppedVideoFiles` 在 drop 发生**之后**才检查是否已导入
  Activity，不满足时弹出错误（`MediaBrowserView.swift:927-931`）。
  顶层 `.onDrop` 使用 `isTargeted: nil`，拖动过程中没有任何反馈（`MediaBrowserView.swift:47`）。
- **HIG basis**：`hig-patterns/drag-and-drop`（只在目标能接受时显示可放置的反馈；
  拒绝时不要等放下以后再报错）。
- **Problem**：用户把视频拖进来，指针显示可以放下，松手后才被告知要先导入 FIT。
- **Suggested fix**：
  - 还没有 Activity 时，拒绝视频的拖放，指针不显示 `+`。
  - 空状态的虚线框只在拖动合法文件时高亮，并显示 “Release to Import”。
  - 如果希望拖入视频时顺便引导，可以接受拖放并先打开 Activity 导入面板，
    但不能弹错误。

### [P2] 右键菜单的结构

- **Evidence**：`MediaBrowserView.swift:420-465`。
  - “Select All” 出现在单行的右键菜单里。
  - “Delete from Media Pool” 没有 destructive 标记，也没有显示快捷键。
  - 文件夹的右键菜单里没有 “Show in Finder”，也没有 “New Folder”。
- **HIG basis**：`hig-components-menus/context-menus`（只放和被点对象相关的常用命令；
  菜单项显示对应的快捷键，与菜单栏保持一致）。
- **Suggested fix**：
  - 移除行菜单里的 “Select All”（空白处的菜单保留）。
  - “Delete from Media Pool” 放在最后一组，显示 ⌘⌫。删除可以撤销，
    与 Inspector 评审的结论一致，不需要标红，也不需要二次确认。
  - 文件夹菜单补上 “New Folder”，删除文件夹的菜单项写明是否连同内容一起删除。

## P3：打磨

- **文件夹图标反了**：收起时显示实心 `folder.fill`，展开时显示空心 `folder`
  （`MediaBrowserView.swift:329`）。Finder 不会随展开状态更换图标；
  建议固定使用 `folder`，展开状态只交给 disclosure triangle。
- **Disclosure 符号**：`chevron.right` / `chevron.down` 方向正确，但尺寸是 10pt
  semibold。系统 outline view 的 disclosure triangle 更细，交给 `OutlineGroup`
  渲染即可。
- **步骤指示器像按钮**：空状态的 “1 Activity → 2 Videos” 用带描边的圆角块表示
  （`MediaBrowserView.swift:984-996`），看起来可以点击，实际不能。
  建议改成无边框的文字加符号，例如 “✓ Activity · 2 Videos”。
- **时长格式**：`12m 5s` 与 Timeline 的 `12:05` 不一致。建议统一为
  `12:05`，搭配 `.monospacedDigit()`。
- **日期包含秒**：`time: .standard` 会显示到秒，第二行很容易被截断。
  建议使用 `.shortened`，完整时间放到 `.help` 里。
- **颜色写死为 hex**：与 Inspector 相同，`MediaBrowserColor` 应映射到语义色，
  这样 Increase Contrast 才能生效。
- **重命名**：只能从右键菜单进入。Finder 的惯例是选中后按 Return 进入重命名；
  但本面板的 Return 更适合用于预览，建议保留菜单入口，再增加 “双击名称重命名”。

## 附录：Overlay Pool 与 Templates

这两个模式不在本轮的重点范围内，只记录与上文同类的问题：

- **Templates 单击就替换全部 overlay**：行是 `.plain` 按钮
  （`TemplatePoolView.swift:263-292`），单击即弹确认框。`applyBuiltInOverlayTemplate`
  已经注册撤销点，按 `hig-patterns/undo-and-redo`，能撤销的操作不需要确认框。
  建议改为：单击选中，双击或 “Apply” 按钮应用；去掉确认框，改为
  “Applied Race · Undo” 的 toast。用户模板的 Delete / Update 修改的是项目之外的
  本地库，撤销覆盖不到，确认框应该保留。
- **Overlay Pool 的 segmented control 写死蓝色**：`.tint(EditorTheme.accentBlue)`
  （`OverlayPoolView.swift:34`），与 Inspector 评审的 P3 相同，去掉 tint。
- **Overlay 卡片只能点击添加**：建议支持拖到 Preview 的指定位置，这是
  `hig-patterns/drag-and-drop` 的推荐做法；同时支持 Return 添加当前焦点的卡片。

## 要不要做成 Finder / FCP 浏览器的样子

不需要照搬。值得借鉴的是 **FCP Browser 的列表视图** 和 **Finder 的列表视图**
共有的行为，这些恰好是 HIG 的 outline view：

| 借鉴 | 原因 |
| --- | --- |
| 单击选中，disclosure triangle 展开，双击打开 | 标准 outline view 行为 |
| ↑/↓、Shift+↑/↓、←/→、⌘A、⌘⌫ | 用户已有肌肉记忆 |
| 焦点不在列表时，选中行变灰 | 明确键盘命令的作用对象 |
| 搜索框在顶部，⌘F 聚焦 | 标准 search field |
| 状态使用符号加颜色 | FCP 的 “已使用” 橙线之外，还有图标区分 |

不必借鉴：FCP 的胶片条缩略图视图和 skimming。媒体数量通常不多，
`media-pool-ui.md` 已经把缩略图列为开放问题，这里不建议现在引入。

## 建议的落地顺序

1. 状态改用符号加颜色，合并两处 Workout type 菜单（P1 + P2，改动集中在少数组件）。
2. 媒体选择与项目选择互斥，⌫ 只作用于焦点区域（P1，先实测；涉及选择语义，需要人工评审）。
3. 列表改为 `List(selection:)` + `OutlineGroup`，一并解决键盘、文件夹选中、
   焦点选中态（P1 + P2，改动最大，需要人工评审选择语义）。
4. Header、搜索框、过滤条、右键菜单改用系统控件和标准结构（P2）。
5. 拖放的合法性反馈（P2）。
6. P3 打磨，以及附录中 Templates 的“撤销代替确认”（需要人工评审撤销语义）。
