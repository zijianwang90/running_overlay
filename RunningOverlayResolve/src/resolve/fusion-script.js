'use strict';
const path = require('node:path');
const { invariant } = require('../domain/validation');
const { normalizeWidgets, normalizeLayout, positionFor } = require('../domain/widgets');

function luaString(value) {
  let equals = '';
  while (value.includes(`]${equals}]`)) equals += '=';
  // Lua long strings discard an initial newline; a prefixed character avoids it.
  return `string.sub([${equals}[x${value}]${equals}], 2)`;
}

function dataUpdateScript({ bundleDirectory, origin, token, initialize = false, widgets, layoutPreset }) {
  invariant(Number.isSafeInteger(origin), 'Invalid composition origin');
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
    const position = positionFor(layout, index);
    return `{id=${luaString(widget.id)}, metric=${luaString(widget.metric)}, x=${position.x}, y=${position.y}}`;
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
  local prefixes = {heartRate = "HeartRate", pace = "Pace", distance = "Distance", elapsed = "Elapsed"}
  local enabled = {}
  for _, widget in ipairs(desired) do enabled[widget.metric] = widget end
  if fresh or previous_layout ~= layout_signature then
    for metric, prefix in pairs(prefixes) do
      update(prefix .. "Enabled", enabled[metric] and 1 or 0)
    end
  end
  -- Keep each metric's existing style, modifiers, and position on an ordinary
  -- resync. Reposition only when the requested layout actually changes.
  if fresh or (previous_layout ~= layout_signature and (previous_layout or #desired > 1)) then
    for _, widget in ipairs(desired) do
      local prefix = widget.metric == "heartRate" and "" or prefixes[widget.metric]
      update(prefix .. "Position", {widget.x, widget.y})
    end
  end
  assert(output:ConnectInput("Input", node), "Could not connect the Numeric output.")
  node:SetData("RunningOverlay.ManagedNumeric", true)
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
end
if undo_started then comp:EndUndo(ok) end
comp:SetData(status_key, token .. (ok and "|ok" or "|error:" .. tostring(message)))
`;
}

module.exports = { luaString, dataUpdateScript };
