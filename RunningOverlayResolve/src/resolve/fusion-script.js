'use strict';
const path = require('node:path');
const { invariant } = require('../domain/validation');
const { METRICS, normalizeWidgets, normalizeLayout, positionFor } = require('../domain/widgets');

function luaString(value) {
  let equals = '';
  while (value.includes(`]${equals}]`)) equals += '=';
  // Lua long strings discard an initial newline; a prefixed character avoids it.
  return `string.sub([${equals}[x${value}]${equals}], 2)`;
}

const MAXIMUM_OFFSET_SECONDS = 86_400;
// Real Time widgets display a fixed UTC offset; the Fuse has no timezone database.
function validClockOffsetHours(value) {
  invariant(typeof value === 'number' && Number.isFinite(value) && value >= -12 && value <= 14, 'Clock UTC offset must be between -12 and +14 hours.');
  return Math.round(value * 60) / 60;
}
function validOffsetSeconds(value) {
  invariant(typeof value === 'number' && Number.isFinite(value) && Math.abs(value) <= MAXIMUM_OFFSET_SECONDS, 'Data time offset must be within one day.');
  // Millisecond precision keeps the Fusion value readable and deterministic.
  return Math.round(value * 1000) / 1000;
}

function dataUpdateScript({ bundleDirectory, origin, token, initialize = false, widgets, layoutPreset, initialTimeOffsetSeconds = 0, clockUtcOffsetHours = 0 }) {
  invariant(Number.isSafeInteger(origin), 'Invalid composition origin');
  const initialOffset = validOffsetSeconds(initialTimeOffsetSeconds);
  const clockOffset = validClockOffsetHours(clockUtcOffsetHours);
  const selected = normalizeWidgets(widgets);
  const layout = normalizeLayout(layoutPreset);
  const fields = {
    ActivityFile: path.join(bundleDirectory, 'activity.roactivity'),
    SyncFile: path.join(bundleDirectory, 'sync.rosync'),
    TimelineOriginFrame: origin,
    AutomaticOrigin: 0,
  };
  const assignments = Object.entries(fields).map(([key, value]) =>
    `{${luaString(key)}, ${typeof value === 'number' ? value : luaString(value)}}`).join(',\n');
  const desired = selected.map((widget, index) => {
    const position = positionFor(layout, index, selected.length);
    return `{id=${luaString(widget.id)}, metric=${luaString(widget.metric)}, metric_index=${METRICS[widget.metric]}, x=${position.x}, y=${position.y}}`;
  }).join(',\n');
  const signature = JSON.stringify([layout, selected.map((widget) => [widget.id, widget.metric])]);
  return `
local status_key = "RunningOverlay.Operation"
local token = ${luaString(token)}
local fields = { ${assignments} }
local desired = { ${desired} }
local layout_signature = ${luaString(signature)}
local changes, created = {}, {}
local previous_layout = comp:GetData("RunningOverlay.LayoutSignature")
local previous_slots = comp:GetData("RunningOverlay.WidgetSlots")
local output = comp:FindTool("MediaOut1")
local previous_output = output and output:FindMainInput(1):GetConnectedOutput()
local undo_started = false
local ok, message = pcall(function()
  assert(output, "The managed composition needs MediaOut1.")
  comp:StartUndo("Update Running Overlay widgets")
  undo_started = true
  local node, obsolete = nil, {}
  for _, candidate in pairs(comp:GetToolList(false, "Fuse.RunningOverlayNumeric")) do
    if candidate:GetData("RunningOverlay.ManagedNumeric") or
       candidate:GetData("RunningOverlay.WidgetId") == "numeric-1" then
      assert(node == nil, "Multiple primary Numeric nodes need manual review.")
      node = candidate
    elseif candidate:GetData("RunningOverlay.WidgetId") then
      table.insert(obsolete, candidate)
    else
      assert(node == nil, "Unmanaged Numeric nodes need manual review.")
      node = candidate
    end
  end
  local fresh = node == nil
  if fresh then
    node = comp:AddTool("Fuse.RunningOverlayNumeric")
    assert(node, "Install the current Numeric Fuse and restart Resolve.")
    table.insert(created, node)
  end
  local function update(key, value)
    local previous = node:GetInput(key)
    assert(previous ~= nil, "Install the current Numeric Fuse: missing input " .. key)
    table.insert(changes, {node, key, previous})
    node:SetInput(key, value)
    if type(value) ~= "table" then
      assert(node:GetInput(key) == value, "Could not update " .. key)
    end
  end
  for _, field in ipairs(fields) do update(field[1], field[2]) end
  -- A new renderer starts from the panel's draft offset. An existing renderer
  -- owns its offset, including Fusion animation; resyncs never reset it.
  if fresh then update("TimeOffset", ${initialOffset}) end
  local prefixes = {"", "Pace", "Distance", "Elapsed"}
  for slot = 5, 16 do prefixes[slot] = "Widget" .. slot end
  local legacy_slots = {heartRate = 1, pace = 2, distance = 3, elapsed = 4}
  local slots = comp:GetData("RunningOverlay.WidgetSlots") or {}
  local used = {}
  -- On first upgrade, adopt legacy metric inputs instead of resetting their styles.
  for _, widget in ipairs(desired) do
    local slot = slots[widget.id]
    if slot then
      assert(type(slot) == "number" and slot >= 1 and slot <= 16 and slot % 1 == 0 and not used[slot], "Invalid widget slot ownership.")
      used[slot] = widget.id
    end
  end
  local assigned = {}
  for _, widget in ipairs(desired) do
    local slot = slots[widget.id]
    if not slot then
      local preferred = legacy_slots[widget.metric]
      if preferred and not used[preferred] then slot = preferred end
      if not slot then
        for available = 1, 16 do if not used[available] then slot = available break end end
      end
      assert(slot, "No numeric widget slot is available.")
      used[slot] = widget.id
    end
    assigned[widget.id] = slot
    local prefix = prefixes[slot]
    local metric_key = prefix .. "Metric"
    -- A newly assigned instance starts on the activity's local clock; an existing
    -- instance keeps the offset the user chose in Fusion.
    if fresh or not slots[widget.id] then
      if node:GetInput(prefix .. "ClockUtcOffset") ~= nil then update(prefix .. "ClockUtcOffset", ${clockOffset})
      else assert(widget.metric ~= "realTime", "Install the current Numeric Fuse and restart Resolve.") end
    end
    if fresh or previous_layout ~= layout_signature then
      if node:GetInput(metric_key) ~= nil then update(metric_key, widget.metric_index)
      else assert(widget.metric_index == (slot - 1), "Install the current Numeric Fuse and restart Resolve.") end
    end
    if fresh or (previous_layout ~= layout_signature and (previous_layout or #desired > 1)) then
      update(prefix .. "Position", {widget.x, widget.y})
    end
  end
  if fresh or previous_layout ~= layout_signature then
    for slot, prefix in ipairs(prefixes) do
      local key = slot == 1 and "HeartRateEnabled" or prefix .. "Enabled"
      if node:GetInput(key) ~= nil then update(key, used[slot] and 1 or 0)
      else assert(not used[slot], "Install the current Numeric Fuse and restart Resolve.") end
    end
  end
  assert(output:ConnectInput("Input", node), "Could not connect the Numeric output.")
  node:SetData("RunningOverlay.ManagedNumeric", true)
  comp:SetData("RunningOverlay.WidgetSlots", assigned)
  comp:SetData("RunningOverlay.LayoutSignature", layout_signature)
  for _, merge in pairs(comp:GetToolList(false, "Merge")) do
    if merge:GetData("RunningOverlay.ManagedMerge") then merge:Delete() end
  end
  for _, old in ipairs(obsolete) do old:Delete() end
end)
if not ok then
  if output then pcall(function() output:ConnectInput("Input", previous_output) end) end
  for i = #changes, 1, -1 do
    local change = changes[i]
    pcall(function() change[1]:SetInput(change[2], change[3]) end)
  end
  for i = #created, 1, -1 do pcall(function() created[i]:Delete() end) end
  pcall(function() comp:SetData("RunningOverlay.LayoutSignature", previous_layout) end)
  pcall(function() comp:SetData("RunningOverlay.WidgetSlots", previous_slots) end)
end
if undo_started then comp:EndUndo(ok) end
comp:SetData(status_key, token .. (ok and "|ok" or "|error:" .. tostring(message)))
`;
}

// Reads, or sets and reads back, the managed renderer's data time offset. It is
// a small separate transaction so dragging the panel control stays responsive.
function timeOffsetScript({ token, offsetSeconds = null }) {
  const requested = offsetSeconds === null ? 'nil' : String(validOffsetSeconds(offsetSeconds));
  return `
local status_key = "RunningOverlay.Operation"
local token = ${luaString(token)}
local requested = ${requested}
local ok, result = pcall(function()
  local node = nil
  for _, candidate in pairs(comp:GetToolList(false, "Fuse.RunningOverlayNumeric")) do
    if candidate:GetData("RunningOverlay.ManagedNumeric") then
      assert(node == nil, "Multiple managed Numeric nodes need manual review.")
      node = candidate
    end
  end
  assert(node, "The managed Numeric node is missing. Update the overlay to repair it.")
  local current = node:GetInput("TimeOffset")
  assert(current ~= nil, "Install the current Numeric Fuse and restart Resolve.")
  local animated = node.TimeOffset:GetConnectedOutput() ~= nil
  if requested ~= nil then
    assert(not animated, "The data time offset is animated in Fusion. Adjust its keyframes there.")
    comp:StartUndo("Adjust Running Overlay timing")
    node:SetInput("TimeOffset", requested)
    comp:EndUndo(true)
    current = node:GetInput("TimeOffset")
  end
  return string.format("%.3f|%s", current, animated and "animated" or "static")
end)
comp:SetData(status_key, token .. (ok and ("|ok|" .. result) or ("|error:" .. tostring(result))))
`;
}

module.exports = { luaString, dataUpdateScript, timeOffsetScript, validOffsetSeconds, validClockOffsetHours };
