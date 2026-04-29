# Route Map Overlay Design

Last updated: 2026-04-28 (Stats Bar unified inspector)

> **Inspector / UI design has its own spec.** See
> [`docs/design/overlays/route-map/route-map-overlay-ui.md`](../design/overlays/route-map/route-map-overlay-ui.md) and
> [`docs/design/overlays/route-map/route-map-overlay-ui.spec.json`](../design/overlays/route-map/route-map-overlay-ui.spec.json)
> for header, sections, controls, density tokens, and per-control model
> mapping. This module doc owns rendering architecture, GPS data, map snapshot
> caching, animation behavior, privacy, costs, and phase planning.

## 1. Module Goal

运动轨迹图覆层是 Running Overlay 的重点视觉模块。它把 FIT 文件中的 GPS 轨迹渲染成可放置、可缩放、可调样式的路线图，支持透明 MOV/PNG 输出，并能和源视频一起展示“我在哪里跑、路线长什么样、当前进度到哪里”。

这个模块不只是一个普通数据图表。它需要同时解决 GPS 数据解析、地图底图、路线投影、样式系统、缓存、离线/导出稳定性和第三方地图服务成本。

## 2. User Value

核心用户价值：

- 让跑步、越野、骑行视频一眼能看出路线形状和地理位置。
- 在视频角落提供小地图，也可以在片头、转场或总结片段中作为主视觉。
- 通过进度点、起终点标记、配速/爬升渐变等方式，把普通运动数据变成更有故事性的画面。
- 给模板系统提供一个更有辨识度的高级图层，提升成片质感。

## 3. User-Facing Styles

首批样式建议：

- Minimal Route: 无底图或弱背景，只显示白色/品牌色轨迹、起点、终点和距离。
- Gradient Route: 轨迹颜色按配速、心率、海拔或时间渐变。
- Glow Route: 适合暗色视频或夜跑，路线带发光描边。
- Bold + Inner Glow: 粗线条加内发光，适合复杂树林、城市背景。
- Dashed Route: 虚线轨迹，作为轻量装饰图层。
- Map Style: 带地图底图，展示道路、水域、公园、地名和完整路线。

布局建议：

- 角落小地图：左上、右上、左下、右下。
- 居中路线徽章：适合片头或结尾总结。
- 全屏地图段落：适合独立导出一段路线介绍。
- Picture-in-picture：半透明地图卡片叠在视频上。

## 4. Controls

Inspector 控件需要覆盖这些维度：

- Route style: Minimal, Gradient, Glow, Dashed, Map。
- Route color: 固定色、渐变色、按指标映射。
- Route color mode: solid / gradient (3-stop configurable colors).
- Metric mapping: pace, heart rate, elevation, distance, elapsed time。
- Line width: 1 px 到 24 px，随项目分辨率缩放。
- Glow: 开关、强度、颜色、半径。
- Start/end markers: 起点与终点可独立设置（dot / pin / flag / hidden）。
- Marker style (v1): dot / pin / flag.
- Current position marker: 开关、样式、大小、尾迹长度。
- Legend (v2): hide / minimal / start+finish+distance / gradient band.
- Map background style (v1): none / dark / light / terrain / satellite.
- Map opacity and route opacity。
- Map shape: square, circle。
- Edge fade out: solid edge / gradient edge, with fade amount.
- Layout: normalized X/Y, scale, anchor position, aspect ratio lock。
- Crop/padding: route bounds padding，避免轨迹贴边。

首版可以先做 Minimal、Gradient、Glow、Map 四种，虚线和复杂 legend 后置。

## 5. Data Requirements

当前 `ActivityRecord` 已有 elapsed time、timestamp、distance、pace、elevation、heart rate、cadence、power、calories，但还没有 GPS 坐标。实现路线图前需要扩展 FIT 解析：

- 读取 record message 的 `position_lat` 和 `position_long`。
- 将 FIT semicircles 转成 WGS84 经纬度。
- 在 `ActivityRecord` 中保存可选 `latitude` / `longitude`。
- 在 `ActivityTimeline` 中提供 route samples、route bounds、当前 elapsed time 对应的位置插值。
- 保留缺失坐标的兼容路径：没有 GPS 时，路线图元素在 UI 中显示不可用原因，不影响其他覆层。

建议新增独立模型：

```swift
struct RoutePoint: Equatable, Codable {
    var elapsedTime: TimeInterval
    var latitude: Double
    var longitude: Double
    var distanceMeters: Double?
    var paceSecondsPerKilometer: Double?
    var heartRate: Int?
    var elevationMeters: Double?
}

struct RouteGeometry: Equatable {
    var points: [RoutePoint]
    var bounds: RouteBounds
    var distanceMeters: Double
}
```

## 6. Map API Options

地图底图优先考虑静态瓦片或静态图片，不建议导出时依赖实时交互式地图控件。

候选方案：

- Apple MapKit / MKMapSnapshotter: macOS 原生，集成成本低，适合 Apple 平台应用；样式自定义较有限，授权和导出使用需要单独确认。
- Mapbox Static Images / Tiles: 样式能力强，适合深色运动视觉和品牌化地图；需要 token、计费、缓存策略。
- MapTiler / OpenMapTiles: 可自托管或云服务，适合降低长期供应商绑定。
- OpenStreetMap raster tiles: 上手简单，但需要遵守 tile usage policy，不适合无缓存的大批量导出。

建议路线：

1. 首版用无底图路线渲染完成核心视觉，保证不依赖网络也能导出。
2. Map Style 以可插拔 `MapSnapshotProvider` 接口实现，先接一个 provider。
3. 地图快照在预览和导出前缓存为本地 bitmap，导出帧只读取缓存，不逐帧请求 API。

## 7. Rendering Architecture

路线图应进入现有 shared preview/export rendering 路径，避免预览和导出效果不一致。

建议新增：

- `OverlayElementType.routeMap`
- `OverlayRouteMapPreset`
- `OverlayRouteMapStyle`
- `OverlayRouteMapRenderLayout`
- `RouteGeometryBuilder`
- `MapSnapshotProvider`
- `RouteMapRenderer`

渲染流程：

1. 从 `ActivityTimeline` 提取 GPS route points。
2. 清洗异常点：去掉无效坐标、明显跳点、重复点。
3. 计算 route bounds 和目标 aspect ratio。
4. 将经纬度投影到 2D overlay rect。Map Style 使用 Web Mercator；无底图样式可以用同一投影保证一致。
5. 按当前 elapsed time 拆分 completed route 和 remaining route。
6. 根据 preset 绘制底图、路线、进度点、起终点、legend。
7. 导出时在 `OverlayFrameRenderer` 中复用相同 layout 和 geometry cache。

## 8. Animation Behavior

支持三种时间表现：

- Static Full Route: 始终显示完整路线。
- Progress Reveal: 从起点按当前 elapsed time 逐步画出路线。
- Current Dot: 完整路线常驻，只移动当前点。

首版建议默认 `Current Dot`，因为它稳定、易懂、导出成本低。`Progress Reveal` 视觉更强，但需要处理路线段插值、渐变段裁剪和长路线性能。

## 9. Caching And Offline Behavior

地图相关缓存需要显式设计：

- Route geometry cache: 与 FIT 文件内容和清洗参数绑定。
- Map snapshot cache: 与 provider、style、bounds、zoom、scale、project resolution、padding 绑定。
- Export cache: 导出开始前冻结当前地图快照，避免中途网络失败或地图样式变化。

离线行为：

- 无底图样式必须完全离线可用。
- 已缓存地图底图离线可用。
- 未缓存地图底图离线时降级为无底图路线，并给出明确状态信息。

## 10. Privacy And Cost

路线图会暴露精确地理位置，产品上需要处理隐私：

- 提供隐藏地图底图、隐藏地名、只显示抽象路线的选项。
- 可选模糊起终点附近若干米。
- 项目文件和模板不应保存第三方 API token。
- 地图请求只发送必要 bounds，不上传完整 FIT 文件。

成本控制：

- 预览阶段节流请求，只在样式、bounds、尺寸稳定后请求快照。
- 导出前一次性准备快照，不按帧请求。
- 对同一路线和样式复用缓存。
- 对 Map Style 加入 API token 缺失、额度失败、网络失败的清晰错误状态。

## 11. Template Behavior

路线图模板应保存样式和布局，不保存具体 GPS route 或地图快照。

模板可保存：

- overlay type: routeMap
- normalized position
- scale
- route map preset
- line width, colors, marker style, legend style
- map provider style id 或内置 style enum
- opacity, glow, padding

模板不保存：

- FIT 路线坐标
- 第三方 API token
- 本地地图缓存路径
- 当前活动的地图 bounds

## 12. Implementation Phases

Phase A: GPS data foundation

- 扩展 FIT parser，读取 latitude/longitude。Completed.
- 扩展 `ActivityRecord` 和 `ActivityTimeline`。Completed.
- 增加 route bounds、route samples、current route point tests。Completed.

Phase B: No-map route overlay

- 新增 `routeMap` overlay type。Completed.
- 实现 Minimal、Gradient、Glow 的纯路线渲染。Completed.
- 预览和导出共用 render model。Completed.
- Inspector 暴露基础样式、位置、尺寸、透明度。Partially completed.

Phase C: Map snapshot abstraction

- 定义 `MapSnapshotProvider`。Completed.
- 接入首个地图 provider。MapKit preview snapshot loading completed.
- 实现缓存层和失败降级。Pending.
- 支持用户自定义地图 API/Mapbox endpoint。Pending.

Phase D: Advanced polish

- 起终点/当前位置 marker 样式。Completed (hidden / dot / pin / flag, 独立 start / end)。
- Legend 和指标色带。Partially completed (minimal / start+finish+distance / gradientBand 三种模式)。
- Progress reveal animation。Pending.
- 起终点隐私模糊。Pending.
- 模板 schema migration。Ongoing — 每次新增字段都通过 `decodeIfPresent` 默认值兜底，旧模板可直接加载。

Phase E: Container presets, map dim controls, edge fade fix (current revision)

- 新增 `OverlayRouteMapContainerPreset` 枚举：`squareHardEdge` / `circleHardEdge` /
  `squareGradientEdge` / `circleGradientEdge`，每个预设对应一组 shape /
  edgeFade / fadeAmount / mapOpacity / shadow 默认值。
- 新增 `OverlayStyle.routeMapMapOpacity` (默认 0.72)，preview 与 export 共同消费。
- Inspector 用新的分组布局 (Preset / Layout / Container / Background Map /
  Route Line / Markers / Legend / Effects)，与
  `docs/design/overlays/route-map/route-map-overlay-ui.spec.json` 对齐。
- **Bug fix**: Edge Fade "Fade Out" 在 SwiftUI preview 中无效。根本原因：
  `RouteMapMaskRenderer` 输出的是灰度 CGImage（无 alpha 通道），
  SwiftUI `.mask()` 读 alpha 而非亮度，导致遮罩完全不透明。
  修复：在 `PreviewCanvasView.RouteMapOverlayView` 的 `.mask {}` 内
  对 `Image(nsImage: alphaMask)` 追加 `.luminanceToAlpha()`，将灰度
  亮度值转换为 alpha。Export 路径（`cgContext.clip(to:mask:)`）本身
  已按亮度解读灰度 mask，无需修改。
- **Bug fix**: Square 形状 Edge Fade 仅四角渐变，边缘中间不渐变。根本原因：
  原实现对方形也使用径向渐变，外半径为对角线一半，导致边缘中点接近内环
  边界而几乎不渐变，四角却完全变黑。修复：方形 shape 改用"最短边距"像素
  迭代算法——`gray = min(distance_to_each_edge) / fadeWidth`，保证四边
  均匀渐变且圆角自然剪切（像素值=0 的区域保持不变）。
- **新增**: Container 区域增加 Border 开关（`routeMapBorderVisible`）。
  默认开启（兼容旧项目）；关闭后 preview 和 export 均不绘制非选中态边框线；
  选中状态的 accent 选框不受影响。Preset 区域移除了无实际效果的 Distance 行。

Phase F: Stats Bar (current revision)

- 新增 `RouteMapStatsMetric` / `RouteMapStatsBarSlot` / `OverlayRouteMapStatsBarConfig` 数据模型。
- 替换左下角 Start/Finish legend 小卡片为横向 Stats Bar（附在地图容器正下方）。
- 支持 1~4 个可配置指标槽位，各自独立开关和 metric 选择。
- `OverlayRouteMapRenderLayout` 新增 `statsBarLayout?: OverlayRouteMapStatsBarLayout`。
- Preview（VStack）和 Export 渲染器均实现 Stats Bar 绘制。
- 旧字段 `routeMapLegendVisible` / `routeMapLegendMode` 保留在 OverlayStyle 中（向后兼容），但不再渲染或出现在 Inspector。
- Inspector 的 Stats Bar 区域改为复用统一组件：`CollapsibleStatsBarInspectorSection` + `StatsBarInspectorRows`。
- Enabled 开关位于 Stats Bar 标题行（箭头左侧），展开内容不再包含独立 Enabled 行。
- Route Map 与 Distance Timeline 使用相同 Stats Bar 图标（`tablecells`）和同一套完整控制：Placement / Inside / Layout / Size / Width / Offset / Item Gap / Background / Dividers / Radius / Slot 1-4。
- 当 Route Map Stats Bar 为 `Inside` 时，路线内容绘制区域自动为 bar 预留内边距，避免 bar 覆盖路线折线。
- `Inside` 模式下 Stats Bar 背景不再使用 bar 自身圆角，改为按外层容器形状/圆角裁切，实现与容器底边（或顶边）一体化视觉。
- Stats Bar 位于 Left/Right 时，渲染强制使用纵向堆叠（top-to-bottom），并将 `Item Gap` 作为纵向行间距。

Phase G: Route line richness, container border / glow

- 实现 `RouteMapLegendItemConfig` 列表，替换固定 `legendMode`（保留兼容）。
- 路线线宽 / 不透明度 / 虚线 / 发光 / 阴影模型字段，并在 Inspector 暴露。
- 容器 border / glow / blend mode 字段。
- 地图 contrast / saturation / brightness / blur 调节。
- 单独控制起终点 marker 颜色 / 大小 / 边框 / 标签文本。
- 用 `byPace` / `byHeartRate` / `byPower` / `byElevation` 等指标驱动渐变颜色。

## 13. Open Questions

- 首个地图 provider 选 MapKit、Mapbox 还是 MapTiler。
- 是否要求用户自己填 API token，还是产品内置受控 token。
- Map Style 是否进入首版，还是先发布无底图路线样式。
- 轨迹颜色映射默认使用配速、心率还是海拔。
- 长距离活动是否需要 route simplification 的可调精度。
- 是否支持 GPX/TCX 导入作为没有 FIT 坐标时的补充来源。
