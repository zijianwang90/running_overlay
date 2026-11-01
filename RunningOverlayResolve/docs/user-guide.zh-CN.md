# Running Overlay Resolve 使用指南（当前开发版）

本指南从导入活动与视频，到校时、添加数字控件和导出，说明当前 Workflow 面板的实际流程。插件在 DaVinci Resolve 内生成实时 Fusion 叠加层；不需要运行 Running Overlay Studio，也不先导出一条带数据的透明视频。目前面板支持心率、配速、平均配速、距离、运动计时、海拔、步频、功率、热量、垂直振幅、触地时间、步幅、垂直比、触地平衡、温度、坡度和真实时间共十七种数字控件，以及距离进度条和离线路线地图，尚未提供模板功能或 Studio 的完整控件目录。

## 图标、距离进度条与路线地图（v10 / v11）

- 数值组件的 **Show Icon** 控制图标；**Metric Default** 随指标选择默认图标，也可覆盖为其他原创矢量图标。位置、对齐、大小、间距、颜色与 Alpha 在 Fusion 中独立调整，阴影覆盖整个组件。图标与 Mac 的 SF Symbols 形状不同；字体和字号以视觉接近为目标。
- **Label / Unit Alignment** 为 Start / Center / End；左右附着时分别对应顶端、居中和底端行框对齐。Easy Run / Race 的右侧单位使用 End。
- 在 Widgets 中添加 **Dist. timeline**。Fusion 的 **Metric** 选择 Distance Timeline 后显示专属设置：宽高、内边距、当前/总距离、km/mi、轨道、刻度、进度颜色、当前位置的点/胶囊/三角标记、起终点标签和中间距离标签，以及进度发光、整体发光和阴影。默认位于顶部中央，位置为组件中心。
- 在 Widgets 中添加 **Route map**。先导入或重新导入含 GPS 的 FIT/GPX 并更新数据包；旧的无坐标包无法显示路线。默认位于右上方，位置为地图中心。Fusion 提供 **Map Size / Map Padding / Route Width / Route Color / Current Position / Position Size / Position Color / Start / Finish Markers**，以及共用阴影。
- 路线保持北向上和比例，透明背景，无需网络或 API。当前位置按活动真实经过时间及每段 Time Offset 更新；GPX 分段和缺失坐标不会连线或跨段插值。无足够 GPS 时显示 **NO GPS**，缺失当前位置时隐藏位置点。当前离线地图没有道路/地名底图，也没有地图供应商、缩放跟随、统计栏或模板一键应用。
- 所有组件共用最多 16 个独立实例槽位。每个实例的数值、进度条或地图设置由其 Metric 控制显示；切换类型不会修改其他实例。保存 Resolve 项目可保留样式。

## 心率区间条与海拔图（v12 / v13）

在 Widgets 中添加 **HR zone bar** 或 **Elevation chart**，更新后在 Fusion
对应实例中调整。两者仍共用最多 16 个独立组件槽位；数据重同步不重置样式。

### 心率区间条

- **Zone Count** 选择五段或六段；**Z1…Z6 Min/Max HR** 编辑 bpm 范围。
  默认取 Mac 的六段参考值：0–134、134–151、152–160、161–171、172–178、178–250。
  两端均包含，重叠值归入第一个匹配区间；Min 大于 Max 的区间不参与分类。
  五段模式使用前五段，隐藏的第六段配置保留；请按自己的区间修改范围。
- **Placement** 选择 Bottom / Top / Left / Right / Free；边缘模式居中贴边，
  **Edge Inset** 控制内缩，Free 使用实例 Position 和 **Free Orientation**。
  横向 Z1 在左、纵向 Z1 在下，标记朝画面内侧。
- **Bar Length / Thickness / Zone Gap / Corner Radius** 控制尺寸；
  **Active Width Share / Height Scale / Inactive Opacity** 控制当前区间强调。
- **Current HR Marker / Show HR Value** 控制当前位置及 bpm；
  **Threshold Marker / Threshold HR** 控制 `T` 阈值；可选区间文字、边框和高亮发光。
  缺失心率或不落在任一区间时，所有区间保持非活动样式，隐藏当前位置；阈值独立显示。
- 这一版只支持心率，未接入配速区间。范围与阈值保存在各实例的 Fusion 设置中，
  不与 Mac app 的全局设置同步，也不按最大心率自动计算。

### 海拔图

- 默认采用 Race 的底部紧凑全程面积图：白色轮廓、绿到蓝的渐变、蓝色位置点，
  默认不画外框、底板或阴影。Position 为组件中心。
- **Chart Width / Height / Padding X/Y** 控制范围；**Profile Line Width / Color**
  控制轮廓；**Area Fill / Top Color / Bottom Color / Opacity** 控制渐变。
  关闭 Area Fill 即为折线图；**Chart Opacity** 控制整体可见度。
- **Smooth Profile (0.85)** 开关模板平滑；**Current Elevation Marker / Marker Scale /
  Color / Marker Guide** 控制当前位置，可选 **Elevation Value (m)** 显示实时海拔。
- 与 Mac 的全程模式一致，有效海拔样本按记录索引等间隔展开，当前位置按活动真实
  经过时间占全程的比例选取最近样本，不按距离推进。长记录保留峰谷、端点并限制绘图量。
  完全缺失时显示 **NO ELEVATION**；当前帧缺失海拔时隐藏位置点，数值显示 `-- m`。
- 目前没有进度截取模式、其他预设、可调平滑强度、坐标轴或统计栏；渐变是近似绘制。

## 天气卡片（v14）

在 Widgets 中添加 **Weather**。若活动文件带有 GPS，面板的 Weather 区域可以按
**Fetch historical weather** 读取活动开始日期、开始时刻和首个 GPS 点的历史天气。
网络请求只在点击时由后台进程发出；结果保存在项目设置并写入不可变数据包，
因此 Resolve 预览和 Deliver 不再联网。活动没有 GPS 时显示占位内容。

- 卡片默认对应 Easy Run / Race 共用的 SimpleCard：左侧天气文字和图标，分隔线，
  右侧地点、星期、温度和湿度。默认蓝色玻璃渐变、圆角 7.5、白色半透明边框和
  阴影与模板近似，字体字号按 Fusion 近似匹配。
- Fusion 中可调整 **Card Width / Height / Padding / Corner Radius / Opacity**；
  **Temperature / Condition / Location / Secondary Text Size** 与图标大小控制排版。
- **Show Condition / Condition Icon / Location / Weekday / Humidity** 分项隐藏内容。
  **Temperature Units** 支持摄氏度/华氏度；**FIT Temperature Override** 在数据包存在
  天气且当前记录带 FIT 温度时，用记录温度替代缓存温度。
- **Card Top/Bottom Color** 近似模板的斜向渐变（以水平色带绘制），并可用
  **Card Border**、**Divider**、**Weather Text Color** 与 **Secondary Text Opacity** 调整。
- 数据缺失时保留 Mac 的占位行为：天气文字为 Sunny、温度/地点/湿度显示 `--`；
  不会被伪造的示例天气替代。面板中的 **Location label** 可改显示地名；
  目前没有自动反向地理编码、天气预报和其他卡片预设。
- 请求发送首个 GPS 坐标和活动日期到 Open-Meteo；不需要 API Key。更换活动会清除
  旧的天气缓存；修改地点文字或重新获取天气后需要 **Update overlay** 才会进入渲染。

## 日期与自定义数值（v15）

在 Widgets 中添加 **Date** 或 **Custom numeric**，更新后在 Fusion 对应实例中调整。

- **Date**：显示当前帧对应活动时刻的日期（活动开始时间加按真实时间计算的经过时间），
  再叠加该实例固定的 **Clock UTC Offset (h)**。**Date Format** 提供 `yyyy-MM-dd`、
  `yyyy/MM/dd`、`MM/dd/yyyy`、`MM-dd`、`MM/dd`、`MMM d`，与 Mac 的 en_US_POSIX
  格式一致；没有活动开始时间时显示 `--`。
- **Custom Numeric**：**Custom Source** 选择记录字段：Timestamp、Elapsed Time、
  Distance (m)、Heart Rate、Pace、Avg Pace、Elevation、Cadence、Power、Calories、
  Latitude、Longitude、Vert. Osc. (mm)、GCT、Stride、Vert. Ratio、GCT Balance、
  Temperature、Grade。**Custom Format** 支持 Number、Integer、Duration、Clock Time、
  Date、Pace、Percent、Coordinate；**Custom Precision** 为 0–4 位小数。
  **Custom Unit** 留空时沿用该字段的默认单位，填写后覆盖显示单位。
  平均配速按真实经过时间除以距离计算；Vert. Ratio 由振荡和步幅推导。
- 缺失字段保持 `--`，沿用全项目的缺失样本策略：只在前后相邻且都有值的记录之间插值，
  不跨任意缺口伪造数值。Date、Clock Time 使用与真实时间相同的活动时刻和 UTC 偏移。
- 这一版的自定义数值尚未提供 HR Zone、Lap Pace、Elevation Gain 与通用 FIT 字段；
  这些依赖区间/圈数据和共享生理设置的字段留待后续组件完成。

### 心率区间标签（v16）

**HR Zone** 与心率数值共用同一套数值样式，显示当前心率所在的 `Z1`…`Z6`。
区间范围来自该实例的 **Zone Count** 和 **Z1…Z6 Min/Max HR**（与 HR zone bar 相同），
按四舍五入后的 bpm 和“两端包含、第一个匹配优先”的规则分类。默认使用 Mac 的六段
参考范围；没有心率或没有匹配区间时显示 `--`。这一版不随区间改变文字颜色，
也不读取 Mac 的全局生理设置。

### 跑步仪表盘（v17）

在 Widgets 中添加 **Running gauge**。默认采用 Mac 的 minimalSport 圆盘：深色半透明底、
外圈、60 个刻度（每 5 个强调），中间显示距离、配速、时间和心率四个区域，
并带上下分隔线。**Gauge Size** 控制直径；**Dial / Outer Ring / Tick Marks /
Dividers** 分项开关，各自的颜色、透明度和线宽可调。

- **Progress Ring** 可选 None、Distance、Time、HR Zone、Power Zone、Pace Intensity
  或 Custom 50%。Distance 按当前距离占活动总距离的比例；Time 按当前经过时间占全程
  的比例；三个区间模式和 Mac 当前实现一样回退为时间进度；Custom 固定 50%。
- 四个区域的指标由 **Top/Middle Left/Middle Right/Bottom Metric** 选择，
  使用与数值组件相同的格式和缺失值规则；**Gauge Labels** 控制小标签，
  **Accent Color** 控制标签、单位和刻度之外的强调文字。
- 尚未实现 Mac 的其他布局预设、七套风格预设、玻璃/发光效果和逐区域字体字号；
  刻度与进度环是矢量近似。

### 装饰元素（v18）

面板的 **Solid color**、**Icon**、**Text** 是不依赖数值的装饰组件，与数值组件一样
占用独立槽位，可单独定位。它们在没有活动样本时仍会绘制。

- **Solid color**：**Shape** 可选矩形、圆角矩形、圆形；**Width / Height** 为画面宽度
  比例，**Corner Radius** 只作用于圆角矩形；**Fill** 颜色和 Alpha 控制填充。
- **Icon**：只能从本项目自带的原始矢量字形中选择（Heart、Calendar 等 17 个），
  **Icon Size** 和 **Icon Color** 控制大小与颜色。不使用 SF Symbols 或外部 SVG/PNG，
  以避免再分发 Apple 图形或引入未授权资源。
- **Text**：**Text** 输入单行文字，**Text Size**、**Text Color** 和
  **Text Alignment**（Left / Center / Right）控制显示；字号使用宽度比例，位置以
  文本锚点计算。字体固定为 Open Sans，多行、描边、自动缩放和逐字间距尚未实现。
- 这三类组件都还没有 Mac 的边框、发光、混合模式等完整效果；Text 在 Mac 中本身仍是
  占位实现，因此这里先提供可用的基础文字。

## 数值文字样式（Fuse v7）

在 Fusion 中选中 Running Overlay Numeric 节点。每个实例分别提供数值字体、Value Size、颜色和 Alpha，以及以下设置：

- **Pace Units**：min/km、min/mi、min/500m；**Distance Units**：km、mi、m；**Elevation Units**：m、ft；**Elapsed Format**：hh:mm:ss、mm:ss、seconds。只有当前 Metric 对应的设置影响输出。
- **Oscillation Units**：cm、mm；**Temperature Units**：Celsius、Fahrenheit。平均配速沿用 Pace Units，按真实经过时间除以距离计算，不扣除暂停。
- **Temperature Source**：FIT、FIT（缺失时用手动值）、Manual；手动值在 **Manual Temperature (°C)** 中设置。跑步动态、温度和坡度来自 FIT 记录；GPX 只提供温度扩展字段，并在同一轨迹段、前后两点都有海拔时计算坡度。数据缺失时显示 `--`。
- **Custom Label**：自定义标签；空白恢复默认标签。Show Label、Show Unit 分别控制标签和单位显示。
- **Label / Unit Font、Style、Size、Color、Alpha**：标签和单位各有独立字体、字号、颜色和透明度。空字体使用 Open Sans Regular。字体须安装在渲染机器上，且包含自定义文字对应的字形。
- **Label / Unit Position、Spacing**：上、下、左、右及间距。先围绕数值放置单位，再围绕整体放置标签；侧边文字按 Alignment 选择顶部、居中或底部行框对齐。字号和间距使用画面宽度比例，与 Value Size 一致。

样式由 Fusion 保存，普通数据同步不重置这些参数。v10 已增加图标、阴影和距离进度条，v11 已增加离线路线地图；背景底图、模板和跨切段同步样式尚未完成。v7 已在独立 Resolve 测试项目验证参数保存重开及 1080p ProRes 4444 透明导出；实时查看器交互和非 ASCII 字形显示尚未验收。首版开发中的叠加层可重新创建，不承担中间开发版本的迁移保证。

## 真实时间与阴影（Fuse v9）

- **Real Time**（面板中为 Clock）：显示该帧数据对应的当地时刻。**Clock Format** 可选 24 小时（`18:47:03`）或 12 小时（`6:47:03 PM`），秒数截断不进位，与 Studio 一致。**Clock UTC Offset (h)** 是明确的 UTC 偏移；新加入的实例按面板中的录制时区在活动开始时的偏移自动填写，之后在 Fusion 中修改不会被同步覆盖。活动跨越夏令时切换时整段使用同一偏移。
- **Shadow**：每个实例的数值、单位和标签共用一组阴影，包括开关、颜色、**Shadow Opacity**、**Shadow Blur**、**Shadow Offset X/Y** 和 **Shadow Thickness**。默认与 Studio 相同：黑色、35%、模糊 4 pt、向下 2 pt。尺寸按画面宽度比例；在 1920 宽输出下，阴影模糊和偏移使用 Studio 值除以 1920（不乘元素缩放）；字号、间距等布局尺寸仍按参考宽 1280 换算，Offset Y 正值向上。

阴影的模糊宽度已在 Resolve 中按 SwiftUI 实测校准（1920×1080）；其他画幅尚未单独验证。每个开启阴影的实例在每帧多做一次全画面模糊，数量多时会影响播放速度。

## 对齐原理：每段素材各算各的

FIT 记录提供活动的绝对时间。视频素材需要确认**原始文件开始录制的绝对时间**，包括时区。Resolve 则提供这段素材放在时间线的哪一帧，以及片段从原文件的哪一帧开始使用。插件在每次同步时为每个普通速度片段计算：

```text
片段第一帧的相机时间 = 原文件录制开始时间 + 源入点帧数 ÷ 原文件帧率
片段第一帧的活动时间 = 校正后的相机时间 − FIT 活动开始时间
片段内后续帧的活动时间 = 第一帧的活动时间 + 片段已播放时长
```

在此基础上，叠加层再加上一个统一的**数据时间偏移**（秒）：正值表示同一画面取更晚的活动数据。偏移在查到片段映射之后才加上，所以空隙仍然透明，每段素材仍按自己的源入点计算。“校正”还可以来自可选的相机时钟标定：一个锚点修正固定快慢，两个相隔一段时间的锚点还可修正时钟漂移。实际计算使用整数微秒和有理数帧率，避免把 29.97 fps 简化成 30 fps。

例如，原文件在 `2026-09-29T10:00:00-04:00` 开始录制，FIT 在同一瞬间开始，而时间线片段从原文件第 12 秒开始使用，那么片段显示的第一帧对应活动第 12 秒。片段放在 Resolve 时间线的 `01:00:00:00`，不会使它对应活动一小时处。下一次剪切会根据下一片段自己的原文件录制时间和源入点重新计算；空隙没有映射，叠加层透明。映射超出活动记录范围时也透明。FIT 暂停不压缩对齐时间轴，但“运动计时”控件会扣除 FIT 的暂停时长。GPX 没有 FIT 计时器事件，不能据稀疏轨迹点推断暂停。

这是一种**基于时间戳和源入点的对齐**，不是画面、音频或 GPS 轨迹的自动匹配。你不需要知道每段素材精确到秒的开录时间：文件名或元数据给出大致位置，再用几秒的偏移，在 Resolve 里看着画面对准即可。插件不会在你确认之前使用任何推测出来的时间。

## 开始前

1. 安装与当前开发版配套的 Workflow 插件和 `RunningOverlayNumeric.fuse`；更新 Fuse 后重启 Resolve。安装位置和构建方法见[子项目 README](../README.md#development)。
2. 在 Resolve 中创建或打开项目，把原始视频导入媒体池，按需要剪辑到一条明确的**参考视频轨道**上。片段之间可以有空隙和跳切。当前同步仅支持已验证的普通速度、外部视频源；变速、倒放、冻结、速度曲线、多机位、复合片段及未经验证的效果会被拒绝。
3. 准备同次活动的 FIT 文件，或带明确时区时间戳的 GPX 文件。相机文件名带日期时间（如 `PRO_VID_20260702_184703_00_009.mp4`）或带时区元数据时，通常不需要再准备其他时间信息。

## 从导入到叠加

面板是一屏完成的：从上到下依次是活动、视频轨道、时间对齐、控件，底部只有一个主按钮，按钮文字始终提示下一步要做什么（扫描、选择活动、使用文件时间、设置缺少的时间、创建叠加层、更新叠加层、已同步）。面板里的修改会自动保存；只有主按钮会改动 Resolve 时间线。

### 1. 打开面板并导入活动

在 Resolve 打开目标时间线后，选择 **Workspace > Workflow Integrations > Running Overlay Resolve**。面板会自动扫描当前时间线；右上角 `↻` 可以手动重新扫描。点击活动卡片里的 **Choose**，选择 `.fit` 或 `.gpx`，面板显示文件名、时长、记录数和开始时间。`.json` 选项供已规范化活动数据的开发测试使用。

面板使用与 Resolve 接近的深灰色外观，不显示 macOS 红绿灯标题栏。拖动顶部标题可移动窗口；右上角 `−` 最小化、`×` 关闭。

活动文件由插件在本机解析，FIT 的真实经过时间是对齐依据；时间线没有因为 FIT 暂停而自动跳过那段真实时间。缺失的心率、配速等值保持缺失，显示为不可用值，不会借用相邻记录伪造数据：只有前后相邻两条记录都有该字段时才插值，否则显示 `--`，哪怕只缺一秒。这一点与 Studio 有意不同，Studio 会跨越任意长的空缺补值。

### 2. 选择视频轨道

**Video track** 以按钮列出时间线的每条视频轨道和片段数，点击承载原始视频的轨道即可。新时间线若 V1 没有片段，面板会自动切换到第一条有片段的轨道（只尝试一次）。插件生成的 **Running Overlay** 轨道不能作为参考轨道。插件只读取选定轨道，不移动、修剪或重排源片段。缺少原文件帧率、源映射不一致或不支持的片段会在轨道下方显示诊断，并阻止同步。

参考轨道应保持启用。若片段被禁用，它不会产生同步区间；若参考轨道中存在无法确认的重叠或源映射，先在 Resolve 中处理，再重新扫描。

### 3. 用文件时间粗定位

**Time alignment** 卡片负责把素材大致放到活动上：

1. 插件读取原文件名中唯一且有效的 `YYYYMMDD_HHMMSS` 日期时间（分隔符也可以是连字符）。文件名不含时区，面板会根据活动推断**录制时区**：选择能让最多文件落进活动时间范围的时区，电脑当前时区优先，并提示“Detected from your activity”。如果相机时钟用的是别的时区，在 **Recording timezone** 下拉菜单里改掉。
2. 下方的条带显示活动（绿色）和各素材在活动中的位置（蓝色）；落在活动范围之外的素材显示为橙色，通常意味着时区或日期不对。
3. 核对无误后按主按钮 **Use file times**，所有文件的时间一次性被采用。这是你明确接受的粗定位，不是插件自动认定的精确时间。

文件名和元数据都没有时间的素材，以及想单独改某个文件时间时，展开 **Clip details**：每个文件有日期、时分秒和时区选择器，勾选 **Use this recording start** 生效。夏令时跳过的本地时间无法使用；重复的本地时间需要再选择一次 UTC 偏移。同一原文件在时间线出现多次，只需设置一次。**Camera clock drift (advanced)** 用于长录像前后偏差逐渐变化的情况：给出两组“相机读数—活动读数”的同一瞬间，可估算时钟漂移。

### 4. 选择控件并创建叠加层

在 **Widgets** 点按切换指标（至少保留一个）。列表中的 **Duplicate** 可添加同指标的独立实例，**Remove** 删除单个实例，最多保留 16 个。然后选择 **Stack**、**Row** 或 **Grid** 作为初始布局。控件按这个固定顺序排列；改变选择或布局后，下一次更新会重新设置起始位置。字号、字体、颜色和精确位置在 Fusion 中调整。

按主按钮 **Create overlay**。插件会再次扫描并检查时间线是否在扫描后改变，只有所有启用片段都有安全映射才会继续。成功后，插件在独立的视频轨道创建一个受管理的 Fusion 合成，将活动记录和逐段时间映射连接到一个 Numeric Fuse。插件不会修改参考视频片段。

### 5. 看着画面微调数据时间

文件时间通常只差几秒。在 Resolve 里把播放头停在一个容易判断的时刻（起跑、停下、过路口、明显加速），或直接播放，然后调整面板里的 **Data timing**：

- `−1 s` / `−0.1` / `+0.1` / `+1 s` 按钮和滑块（±30 秒），或在 **Exact offset** 输入精确值；
- 往右（正值）是**更晚的数据**，往左是**更早的数据**；直到数字的变化与画面里的动作同时发生。

偏移保存在叠加层自己的 Fusion 节点上，所以：

- 同一个值也能在 Fusion 里调：选中叠加片段进入 Fusion，Numeric 节点的 **Sync** 页有 **Data Time Offset (s)**、±0.1 s 与 ±1 s 按钮，以及 **Show Sync Readout**（在画面左上角显示当前活动时间和偏移，方便对时，导出前记得关闭）。
- 调整偏移不会让叠加层变成“需要更新”，也不会重建数据；它随 Resolve 项目保存，可以用 Resolve 的撤销。
- 创建叠加层之前设置的偏移会作为初始值写入新叠加层。
- 如果在 Fusion 里给偏移打了关键帧，面板会停止修改它，请在 Fusion 里编辑关键帧。

没有切开时，偏移作用于整条叠加层。个别文件时间明显不对时，到 **Clip details** 单独修改该文件。

### 剪辑阶段：单独微调某一段

对时完成后进入剪辑，可以把叠加层和素材一起切开、删除、前移。每一段都保留自己的数据和偏移，并跟着素材走，不需要更新。

如果某一段有轻微偏差，把播放头停在这一段上，再调 **Data timing**：面板会显示正在调第几段，其他段不受影响。播放头不在叠加层上时，或者叠加层上方还有其他片段挡住时，面板无法定位到这一段，调整会被停用。

切开后主按钮不再更新叠加层，因为更新会把它当成一整段处理。如果还要改活动数据、控件或布局，请先撤销切割，更新后再切。切开只用于微调，所以应在基本对时完成后进行。把叠加层复制到其他轨道不受支持，面板会停用调整。

### 6. 在 Fusion 中调整样式并保存项目

选中受管理的叠加片段，进入 Fusion，选择 Numeric 节点。可分别调整四种指标的位置、尺寸、标签、字体和颜色；位置输入提供 Fusion 原生位置控件。完成后保存 Resolve 项目。插件的面板设置和不可变数据包保存在本机的 **Running Overlay Resolve** 应用支持目录中；保存 Resolve 项目时请保留这些本机数据包，否则既有合成可能失去数据源。

## 剪辑修改后的更新

修改参考轨道的剪切、源入点、启用状态或长度后，面板会在下一次检查时提示，主按钮变为 **Update overlay**。按下后插件按当前时间线重新生成映射。普通更新沿用已有 Fusion 控件的样式、动画和数据时间偏移；如果参考范围变了，插件会替换自己的受管理叠加片段并导入原 Fusion 合成。切开或复制受管理片段后，更新会被阻止。

面板打开时会定期检查是否需要更新，但**不会自动改写时间线**；你在调整偏移时检查会暂停。Resolve 正在渲染时，扫描暂停，创建、更新和偏移调整都会被拒绝；渲染结束后再操作。更改叠加片段长度时，单独加在 Edit 页片段上的效果目前不能保证随替换保留。

## 导出

- **普通成片**：在原时间线中保留视频与上方的实时叠加层，按项目常规方式在 Deliver 导出，得到视频与数据合成画面。
- **仅导出透明叠加层**：复制时间线，只在副本中保留受管理叠加层，然后导出 QuickTime ProRes 4444，启用 **Export Alpha**，选择 **Straight** alpha。当前已在 1080p30 合成的独立导出中验证可见数字及空隙透明；四指标完整 Deliver、UHD 和色彩管理仍需进一步验证。不要通过仅关闭原时间线的视频轨道来推断透明导出是否正确。

本地配置和数据包尚未形成可直接跨电脑迁移的便携项目。跨机器交付、签名安装、更多相机元数据与完整控件目录属于后续开发范围。具体宿主验证范围见[测试记录](testing.md)。

新指标需要 Numeric Fuse 版本 6，更新后重启 Resolve。海拔使用米、步频使用 spm、功率使用 W、热量使用 kcal。热量目前只显示文件中的逐记录值，尚未根据圈段或整场总量估算；没有值时显示 `--`。同一指标的多个实例可在 Fusion 各自的控件页调整样式和位置。
