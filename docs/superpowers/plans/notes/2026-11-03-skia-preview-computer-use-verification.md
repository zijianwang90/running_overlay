# Skia 与 SwiftUI 预览渲染器 UI 实机验证

用途：交给 computer-use 代理在本机执行。目标不是像素级比对，而是确认两个预览渲染器在真实 UI 中可切换、可播放、可编辑、地图正常，且没有崩溃、空白、错位或明显闪烁。

分支/工作区：

```text
/Users/codywang/Documents/Projects/running_overlay_skia_gpu_spike
```

执行前请遵守：

- 只做 UI 操作和截图；不要修改仓库文件，不要 commit，不要删除项目或模板。
- 不要用 Export 按钮判断 Skia。当前生产导出仍然只走 SwiftUI，导出不在本次验证范围。
- 测试用合成 GPX，避免使用真实个人轨迹。
- 每一步都截图；失败时记录当前 playhead、模板、渲染器状态（闪电按钮空心/实心）和复现步骤。

## 1. 启动准备

在 Terminal 中执行：

```sh
cd /Users/codywang/Documents/Projects/running_overlay_skia_gpu_spike

export SKIA_DIR=/tmp/skia-prebuilts-m152/skia-m152-0873ec164a-r1-gpu-macos-arm64
export SKIA_GPU=1

# 确认 Skia 动态库存在
ls "$SKIA_DIR/lib/libskia.dylib"

swift run RunningOverlay \
  --activity Tests/RunningOverlayTests/Fixtures/Activities/synthetic-run.gpx
```

首次编译可能需要几分钟，等待应用窗口出现。

预期：

- 打开主编辑器窗口。
- 导入活动后自动应用内置 `Easy Run` 模板。如果这台机器之前应用过其他模板，可能恢复最近使用的模板；此时到左侧 `Templates` 手动点击 `Easy Run`。
- 预览区标题栏显示 `Preview`，右侧依次有 `bolt`/`bolt.fill`、`viewfinder`、背景色等按钮。
- `bolt` 空心 = SwiftUI；`bolt.fill` 实心 = Skia。
- 如果找不到闪电按钮，停止测试并报告：Skia 未编译进 Debug 包（通常是没有设置 `SKIA_DIR` / `SKIA_GPU`，或运行的是 Xcode/Release 构建）。

启动后先按一次 `Cmd+Q` 退出旧实例，确保测试的是刚启动的进程。

## 2. 建立 SwiftUI 基线

1. 确认闪电按钮为空心。
2. 把 playhead 停在 0 秒；截图，命名 `01-swiftui-t0.png`。
3. 点击播放，播放 5 秒后暂停；截图 `02-swiftui-playing.png`。
4. 拖动 playhead 到中段，再拖回开头；截图 `03-swiftui-scrub.png`。

检查并记录：

- `Easy Run` 模板元素是否齐全：pace、heart rate、cadence、圆形 route map、distance timeline、elapsed time、real time、power、weather widget。
- 数值是否随 playhead 更新。
- route map 是否显示 MapKit 底图；首次可能先显示网格，1–3 秒后出现地图快照。
- 是否有遮挡、裁切或明显错位。

## 3. 切换到 Skia

1. 点击闪电按钮。预期变为实心 `bolt.fill`。
2. 保持同一 playhead，截图 `04-skia-t0.png`，与 `01-swiftui-t0.png` 对比。
3. 播放 5 秒后暂停，截图 `05-skia-playing.png`。
4. 来回切换 SwiftUI / Skia 共 10 次，其中至少 3 次在播放中切换。
5. 在 Skia 模式下拖动 playhead、暂停、继续播放，并缩放窗口宽度。

预期：

- 切换后画面立即重绘，不出现长时间空白或卡死。
- 所有元素仍在，布局位置和尺寸与 SwiftUI 基本一致（允许字体抗锯齿、阴影边缘的轻微差异）。
- 数值、进度、当前跑者点随 playhead 更新。
- 播放中切换不崩溃，不出现按钮状态与画面不一致。
- 窗口缩放后不拉伸变形，预览仍按画布比例适配。

判定为失败的情况：

- 画面空白、只显示部分元素、元素跳到明显错误的位置。
- 切换后仍显示旧渲染器的像素，或闪电状态与实际渲染不一致。
- 播放/拖动后数值不更新。
- 崩溃、卡死、持续低于约 30 fps 的明显卡顿。

## 4. 模块逐项检查

保持同一 playhead，暂停后分别截图 SwiftUI 与 Skia，按模块记录。

| 模块 | 检查点 | 结果 |
|---|---|---|
| 数字/文本 | pace、heart rate、cadence、elapsed time、real time、power 的数值、单位、对齐、阴影 | |
| Distance Timeline | 轨道、进度、轴标签、当前值；与 SwiftUI 的位置一致 | |
| Route Map | 圆形裁切、MapKit 底图、路线形状、当前跑者点、描边/光晕 | |
| Weather Widget | 图标、温度、地点、布局；无数据时占位是否合理 | |
| 选择框 | 在预览中点击元素是否出现选择框；拖动是否移动；Inspector 是否同步 | |

说明：

- Skia 预览的选择框是通用矩形，可能与 SwiftUI 的精细选择样式不同，这是已知差异，不算失败。
- 如果 MapKit 无网络，route map 会退化为网格背景；记录为“环境限制”，不要判定为渲染失败，但必须确认没有卡死。

## 5. 模板覆盖

在左侧工具栏把 `Media / Overlays / Templates` 切到 `Templates`，逐个应用并重复第 3 步的切换与播放检查。

### 5.1 Easy Run

已自动应用。重点：route map、distance timeline、数字文本、weather。

### 5.2 Race

点击 `Race`，确认替换现有 overlays。

重点新增：

- Zone Edge Bar：是否贴底、分区颜色、标记文字。
- Elevation Chart：图表区域、网格、渐变/面积、当前点。
- 与 route map / distance timeline 的叠加顺序。

截图：`06-race-swiftui.png`、`07-race-skia.png`。

### 5.3 Interval Workout

点击 `Interval Workout`，确认替换。

重点新增：

- Interval HUD Bar：分区、当前段、数值布局。
- Interval Timeline：分段、当前段高亮、当前段的 rep/distance/duration 文本是否溢出段高。

截图：`08-interval-swiftui.png`、`09-interval-skia.png`。

### 5.4 手动补充模块

如果时间允许，在左侧 `Overlays` 中添加并对比：

- `Running Gauge`
- `Interval Countdown`
- `Interval Work Summary`
- `Elevation Chart`（若 Race 模板未覆盖）
- `Zone Edge Bar`（若 Race 模板未覆盖）

每个模块至少完成一次 SwiftUI/Skia 同 playhead 截图对比。

## 6. Route Map 专项验证

1. 在左侧 `Overlays` 选择 `Route Map`，打开右侧 Inspector。
2. 展开 `Background Map`。
3. 确认 `Map Style` 依次切换 `Dark`、`Light`、`Terrain`、`Satellite`，每次等待地图快照更新。
4. 每个样式下分别截图 SwiftUI 和 Skia 同一 playhead。
5. 调整 `Map Opacity`，确认两个渲染器都变化。
6. 播放，观察当前跑者点是否沿路线前进，并在两个渲染器间切换确认位置一致。

预期：

- SwiftUI 与 Skia 使用同一张 MapKit 快照；路线几何和当前点位置一致。
- 切换地图样式后旧快照不应残留（允许短暂网格）。
- 无网络时显示网格，不崩溃。

注意：合成 GPX 只有很小的地理范围，地图可能是低细节/街道级；这是数据限制。若要验证真实地图效果，可改用测试机上的合法 GPX/FIT，但不得上传或提交私人轨迹。

## 7. 选择、拖动与 Inspector

在 Skia 模式下：

1. 点击一个数字 overlay；确认选择框出现。
2. 拖动到新位置；确认位置变化、Inspector 数值更新。
3. 按 `Cmd+Z` 撤销；确认恢复原位。
4. 切换回 SwiftUI；确认位置一致。
5. 再切回 Skia；确认位置保持。

记录任何选择框错位、点击命中错误元素、拖动跳变或撤销失效。

## 8. 稳定性与性能

Skia 模式下执行：

- 连续播放至少 30 秒。
- 快速拖动 playhead 10 次。
- 切换模板 3 次（Easy Run → Race → Interval Workout → Easy Run）。
- 窗口最大化、还原、拉窄各一次。
- 最后再切换渲染器 5 次。

预期：无崩溃、无转菊花、无持续黑屏；播放保持流畅。

## 9. 已知且可接受的差异

以下不是缺陷，但需要记录出现位置：

- 文本抗锯齿、字重边缘、阴影/光晕形状与 SwiftUI 有细微差异。
- Skia 预览选择框为通用矩形。
- 当前导出按钮仍走 SwiftUI；不要用它验证 Skia。
- 全局 `element.opacity` 在 SwiftUI 导出 oracle 中历史上未应用；预览中若发现透明度差异，记录但不作为本次阻塞项。

## 10. 最终报告格式

请按以下结构返回：

```text
环境：
- 分支/路径：
- 启动命令：
- macOS 版本：
- 是否有网络：
- MapKit 是否成功加载：

总体结论：PASS / FAIL

逐项结果：
| 用例 | 结果 | 证据截图 | 备注 |
|------|------|----------|------|
| 启动与 Easy Run 自动应用 | | | |
| SwiftUI 基线播放/拖动 | | | |
| 切换到 Skia | | | |
| Skia 播放/拖动/缩放 | | | |
| Easy Run 模块对比 | | | |
| Race 模块对比 | | | |
| Interval Workout 模块对比 | | | |
| Route Map 四种样式 | | | |
| 选择/拖动/撤销 | | | |
| 30 秒稳定性 | | | |

失败项详情：
- 复现步骤：
- 当前模板与 playhead：
- 渲染器状态：
- 期望：
- 实际：
- 截图：
- 是否可稳定复现：
```

如果出现崩溃，额外提供 Terminal 最后 50 行输出和崩溃时间点。

## 11. 常见问题排查

### 闪电按钮不存在

说明当前进程没有编译 Skia 预览。确认：

```sh
echo "$SKIA_DIR"
echo "$SKIA_GPU"
ls "$SKIA_DIR/lib/libskia.dylib"
```

三项都必须有效；然后用同一终端重新 `swift run`。用 Xcode 或 Release 构建通常没有 Skia 预览。

### 启动时报 libskia.dylib 找不到

确认 `SKIA_DIR` 路径存在，且应用二进制有指向该路径的 rpath：

```sh
otool -L .build/out/Products/Debug/RunningOverlay | grep libskia
```

### MapKit 一直显示网格

先确认机器能联网并访问 Apple 地图服务；这是环境/网络问题，不是渲染器崩溃。记录后继续测试其他模块。

### 想直接以 Skia 启动

```sh
RUNNING_OVERLAY_RENDERER=skia swift run RunningOverlay \
  --activity Tests/RunningOverlayTests/Fixtures/Activities/synthetic-run.gpx
```

启动后仍可用闪电按钮切回 SwiftUI。

