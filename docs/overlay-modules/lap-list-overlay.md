# Lap List Overlay

Last updated: 2026-04-27

## 1. Module Goal

Lap List 是一种 **课表型 teleprompter 图层**，把一堂训练课（间歇跑、配速跑、有氧课等）的完整圈次结构以纵向列表渲染在视频上。核心体验：

- 当前圈高亮居中，已完成圈在上方，未来圈在下方。
- 当前圈行背景有实时进度条（按距离或用时），从 0 到该圈总量随跑动更新。
- 上下行可 fade out，营造"传送带上滚过去"的视觉效果。
- 用户可自定义显示列、行数、锚点位置、进度模式、颜色等。

适用场景：间歇训练、分组配速、越野分段、马拉松配速策略展示。

## 2. User Value

- 观看者一眼看清"跑到第几圈、还剩几圈"，不需要暂停画面。
- 进度条让"400米快跑"这类短圈次变得可量化感知。
- 和 Route Map 配合可同时展示地理位置和课表进度。

## 3. Data Requirements

### FIT 来源

全部来自 FIT message type 19（lap messages），由 `FitFileParser` 解析为 `LapRecord` 数组存入 `ActivityTimeline.laps`。

每条 `LapRecord` 包含：

| 字段 | FIT field | 说明 |
|---|---|---|
| startElapsedTime | 由 start_time 减 session start_time 计算 | 圈开始相对时间 |
| endElapsedTime | startElapsedTime + totalElapsedTime | 圈结束时间 |
| startDistanceMeters | 累加计算 | 圈开始时的累计距离 |
| totalDistanceMeters | field 9 (total_distance) | 圈内距离 |
| totalElapsedTime | field 7 (total_elapsed_time) | 圈用时 |
| avgPaceSecondsPerKm | 由 avg_speed (field 13) 导出 | 平均配速 |
| avgHeartRate | field 15 | 平均心率 |
| maxHeartRate | field 16 | 最大心率 |
| avgCadenceSPM | field 17 × 2 | 平均步频（strides/min → SPM） |
| avgPowerWatts | field 19 | 平均功率 |
| totalAscent | field 21 | 累计爬升 |
| kind | 自动分类 | warmup / active / rest / cooldown / unknown |

### 圈次分类规则（`lapKind`）

```
speed = avgSpeedMS ?? 0
if index == 0 && speed < 3.5 → warmup
if index == last && speed < 3.5 → cooldown
speed >= 3.5 → active
else → rest
```

阈值 3.5 m/s ≈ 4'45"/km，区分快跑与慢跑恢复。

### 实时查询

`ActivityTimeline.currentLap(at:)` — 在 `elapsedTime` 时刻对应的 `LapRecord`（`startElapsedTime <= t` 的最后一条）。

`ActivityTimeline.lapElapsedTime(at:)` — 当前圈内已用时间。

`ActivityTimeline.lapProgress(at:byDistance:)` — 当前圈进度 0...1，支持按距离或按用时两种模式。

## 4. Style Model

`LapListStyle`（`OverlayElement.swift`）：

| 属性 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| visibleRowCount | Int | 5 | 同时可见行数（含当前圈） |
| currentRowAnchor | LapListAnchor | .center | 当前圈停在顶/中/底 |
| fadeEnabled | Bool | true | 非当前圈是否 fade out |
| fadeMinOpacity | Double | 0.25 | fade 最低透明度 |
| progressBarEnabled | Bool | true | 是否显示进度条 |
| progressMode | LapProgressMode | .distance | 按距离还是用时驱动 |
| progressColor | OverlayColor | .blue | 进度条颜色 |
| progressOpacity | Double | 0.35 | 进度条透明度 |
| showCompletedMark | Bool | false | （预留）已完成圈显示✓ |
| rowHeight | Double | 36 | 行高（设计单位 pt） |
| rowCornerRadius | Double | 4 | 行圆角 |
| rowSpacing | Double | 2 | 行间距 |
| backgroundOpacity | Double | 0.75 | 行背景透明度 |
| columns | [LapListColumn] | 见下 | 可见列配置 |

默认列（按顺序）：

| LapColumnMetric | 默认可见 | 说明 |
|---|---|---|
| lapNumber | ✓ | #1, #2, … |
| lapKind | ✓ | WU / RUN / REST / CD / LAP |
| distance | ✓ | 0.40 km / 400 m |
| elapsedTime | ✓ | 当前圈内已用时（当前圈）或总圈时 |
| pace | ✓ | 平均配速 |
| heartRate | — | 平均心率 |
| cadence | — | 平均步频 |
| power | — | 平均功率 |
| ascent | — | 累计爬升 |

## 5. Rendering Architecture

### Preview（SwiftUI）

`LapListOverlayView` in `PreviewCanvasView.swift`：

- 外层 `VStack(spacing: layout.rowSpacing)`，每行一个 `lapRow`。
- `lapRow` 是一个 `ZStack`：
  1. `RoundedRectangle` 背景（黑色，`backgroundOpacity × rowOpacity`）
  2. `GeometryReader` 内嵌进度条（`progressFraction × width`，`progressColor`）
  3. 当前圈 border stroke（前景色 55% 不透明度）
  4. `HStack` 等分列 `Text`，第一列左对齐，其余居中

### Export（CoreGraphics）

`OverlayFrameRenderer.renderLapList(_:renderContext:)`：

- 顺序遍历 `layout.rows`
- 每行：`NSBezierPath(roundedRect:)` fill 背景 → 可选进度条 fill → 可选 border stroke → 文字 `NSAttributedString` draw
- 字体使用 `element.style.fontName` / `element.style.fontWeight`，大小由 `layout.fontSize`（rowHeight × 0.38 × scale）

### Layout 计算（OverlayRenderModel）

`lapListLayout(for:in:)` 步骤：

1. 根据 `currentRowAnchor` 确定 `anchorRow`（顶=0, 中=count/2, 底=count-1）
2. `firstVisibleIndex = currentLapIndex - anchorRow`
3. 遍历 0...visibleRowCount：计算 `distanceFromCurrent`，线性插值 opacity（仅当 fadeEnabled）
4. 进度：已完成=1.0，当前圈=`lapProgress(at:byDistance:)`，未来=0.0
5. 列文字由 `lapColumnText(_:lap:activity:elapsedTime:isCurrent:)` 格式化

总宽固定为 `scaled(280 × element.scale)`；总高 = rowHeight × count + spacing × (count-1)；以 `element.position` 为中心。

## 6. Inspector UI

`LapListOverlayDetailView.swift`，四个可折叠区块：

- **Layout** — 行数（stepper 1-10）、当前圈锚点（segmented）、行高/间距/背景透明度（slider）、淡出开关 + 最低透明度
- **Progress Bar** — 开关、模式（distance/time segmented）、颜色（swatch strip）、透明度
- **Columns** — 9 列逐一开关
- **Position** — 缩放 slider

## 7. Known Limitations & Future Work

- **Lap kind threshold hardcoded**: 3.5 m/s 是经验值，不同运动（骑行、越野）需要可配置。
- **最多 10 行显示**: 当前 stepper 上限 10，超大间歇训练（20+ 圈）时上限可能需要放开。
- **列宽固定等分**: 数字列宽差异大（"#1" vs "5'23\"/km"），未来可按内容自适应或支持手动设宽度。
- **showCompletedMark 未实现**: 已完成圈的 ✓ 标记预留了字段，渲染层尚未实现。
- **已完成圈用时显示 totalElapsedTime**: 已完成圈的 elapsedTime 列固定显示 lap 总时，不显示当时实测时（FIT 精度足够，可按需切换）。
- **动画过渡**: 当圈次切换时列表"跳"到新位置，无平滑滚动动画（export 帧级精度不适合加缓动，preview 可扩展 `.animation`）。

## 8. Implementation Phases

### Phase 1 — 完成 ✓

- FIT lap 解析（message 19）
- `LapRecord` / `LapKind` 数据模型
- `ActivityTimeline` lap 查询方法
- `LapListStyle` 样式模型
- `OverlayRenderModel.lapListLayout()`
- CoreGraphics 渲染 (`renderLapList`)
- SwiftUI 预览 (`LapListOverlayView`)
- Inspector (`LapListOverlayDetailView`)
- 完整 build + test 验证

### Phase 2 — 待实现

- 可配置 lap kind 阈值（Inspector 高级选项）
- `showCompletedMark` 渲染（已完成圈 ✓ 图标）
- 列宽自适应或手动宽度
- 更丰富的颜色主题（按 lapKind 自动着色行背景）
- 间距和字体的 preset 快捷方式
