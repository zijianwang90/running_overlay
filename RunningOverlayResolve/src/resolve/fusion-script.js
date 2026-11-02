'use strict';
const path = require('node:path');
const { invariant } = require('../domain/validation');
const { METRICS, normalizeWidgets } = require('../domain/widgets');
const { templateById, resolvePlacements } = require('../domain/templates');
const { EXCLUDED_STYLE_KEYS } = require('../domain/user-templates');

function luaString(value) {
  let equals = '';
  while (value.includes(`]${equals}]`)) equals += '=';
  // Lua long strings discard an initial newline; a prefixed character avoids it.
  return `string.sub([${equals}[x${value}]${equals}], 2)`;
}

// Slot 1 predates the other fifteen and keeps its original color input names.
const WIDGET_PREFIXES = `local prefixes = {"", "Pace", "Distance", "Elapsed"}
for slot = 5, 16 do prefixes[slot] = "Widget" .. slot end
local first_slot_keys = {R = "Red", G = "Green", B = "Blue", A = "Alpha"}
local function style_key(prefix, suffix) return prefix == "" and first_slot_keys[suffix] or (prefix .. suffix) end`;

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

const seedValue = (value) => {
  if (typeof value === 'string') return luaString(value);
  return Array.isArray(value) ? `{${value[0]}, ${value[1]}}` : value;
};

function dataUpdateScript({ bundleDirectory, origin, token, initialize = false, widgets, templateId, customTemplate = null, initialTimeOffsetSeconds = 0, clockUtcOffsetHours = 0, mapImage = null }) {
  invariant(Number.isSafeInteger(origin), 'Invalid composition origin');
  const initialOffset = validOffsetSeconds(initialTimeOffsetSeconds);
  const clockOffset = validClockOffsetHours(clockUtcOffsetHours);
  const selected = normalizeWidgets(widgets);
  const template = customTemplate ?? templateById(templateId);
  const fields = {
    ActivityFile: path.join(bundleDirectory, 'activity.roactivity'),
    SyncFile: path.join(bundleDirectory, 'sync.rosync'),
    TimelineOriginFrame: origin,
    AutomaticOrigin: 0,
  };
  const assignments = Object.entries(fields).map(([key, value]) =>
    `{${luaString(key)}, ${typeof value === 'number' ? value : luaString(value)}}`).join(',\n');
  const seeded = [];
  const desired = resolvePlacements(template, selected).map(({ widget, position, styles }) => {
    const seededStyles = Object.entries(styles)
      .map(([suffix, value]) => `{${luaString(suffix)}, ${seedValue(value)}}`).join(', ');
    seeded.push(`  [${luaString(widget.id)}] = { ${seededStyles} }`);
    return `{id=${luaString(widget.id)}, metric=${luaString(widget.metric)}, metric_index=${METRICS[widget.metric]}, x=${position.x}, y=${position.y}}`;
  }).join(',\n');
  const templateStyles = `{\n${seeded.join(',\n')}\n}`;
  const signature = JSON.stringify([template.id, selected.map((widget) => [widget.id, widget.metric])]);
  return `
local status_key = "RunningOverlay.Operation"
local token = ${luaString(token)}
local fields = { ${assignments} }
local map_image = ${mapImage == null ? 'nil' : luaString(mapImage)}
local desired = { ${desired} }
local template_styles = ${templateStyles}
local template_signature = ${luaString(signature)}
local changes, created = {}, {}
local previous_signature = comp:GetData("RunningOverlay.TemplateSignature")
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
  ${WIDGET_PREFIXES}
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
    -- A new instance adopts the template's starting style; later Fusion edits
    -- are never overwritten by a resync.
    if fresh or not slots[widget.id] then
      for _, style in ipairs(template_styles[widget.id]) do
        local key = style_key(prefix, style[1])
        -- A saved template may predate an input this Fuse no longer has.
        if ${customTemplate ? 'node:GetInput(key) ~= nil' : 'true'} then update(key, style[2]) end
      end
    end
    -- A newly assigned instance starts on the activity's local clock; an existing
    -- instance keeps the offset the user chose in Fusion.
    if fresh or not slots[widget.id] then
      if node:GetInput(prefix .. "ClockUtcOffset") ~= nil then update(prefix .. "ClockUtcOffset", ${clockOffset})
      else assert(widget.metric ~= "realTime", "Install the current Numeric Fuse and restart Resolve.") end
    end
    if widget.metric == "elevationChart" then
      assert(node:GetInput(prefix .. "ElevationWidth") ~= nil, "Install the current Numeric Fuse and restart Resolve.")
    end
    if widget.metric == "weatherWidget" then
      assert(node:GetInput(prefix .. "WeatherWidth") ~= nil, "Install the current Numeric Fuse and restart Resolve.")
    end
    if widget.metric == "zoneEdgeBar" then
      assert(node:GetInput(prefix .. "ZoneLength") ~= nil, "Install the current Numeric Fuse and restart Resolve.")
    end
    if widget.metric == "routeMap" then
      assert(node:GetInput(prefix .. "RouteSize") ~= nil, "Install the current Numeric Fuse and restart Resolve.")
      if fresh or not slots[widget.id] then update(prefix .. "RouteMapBackground", map_image ~= nil and 1 or 0) end
    end
    if widget.metric == "distanceTimeline" then
      assert(node:GetInput(prefix .. "TimelineWidth") ~= nil, "Install the current Numeric Fuse and restart Resolve.")
    end
    if fresh or previous_signature ~= template_signature then
      if node:GetInput(metric_key) ~= nil then update(metric_key, widget.metric_index)
      else assert(widget.metric_index == (slot - 1), "Install the current Numeric Fuse and restart Resolve.") end
    end
    if fresh or (previous_signature ~= template_signature and (previous_signature or #desired > 1)) then
      update(prefix .. "Position", {widget.x, widget.y})
    end
  end
  if fresh or previous_signature ~= template_signature then
    for slot, prefix in ipairs(prefixes) do
      local key = slot == 1 and "HeartRateEnabled" or prefix .. "Enabled"
      if node:GetInput(key) ~= nil then update(key, used[slot] and 1 or 0)
      else assert(not used[slot], "Install the current Numeric Fuse and restart Resolve.") end
    end
  end
  -- The map snapshot travels as a Loader so the Fuse reads real pixels; the
  -- Inspector's Map Background toggle decides whether it is drawn.
  local map_loader = nil
  for _, candidate in pairs(comp:GetToolList(false, "Loader")) do
    if candidate:GetData("RunningOverlay.ManagedMapLoader") then map_loader = candidate end
  end
  if map_image ~= nil then
    if map_loader == nil then
      map_loader = comp:AddTool("Loader")
      assert(map_loader, "Could not create the map background Loader.")
      map_loader:SetData("RunningOverlay.ManagedMapLoader", true)
      table.insert(created, map_loader)
    end
    map_loader:SetInput("Clip", map_image)
    assert(map_loader:GetInput("Clip") == map_image, "Could not set the map background image.")
    assert(node:ConnectInput("MapImage", map_loader), "Install the current Numeric Fuse: the map background input is missing.")
  elseif map_loader ~= nil then
    if node:GetInput("MapImage") ~= nil then pcall(function() node:ConnectInput("MapImage", nil) end) end
    map_loader:Delete()
  end
  assert(output:ConnectInput("Input", node), "Could not connect the Numeric output.")
  node:SetData("RunningOverlay.ManagedNumeric", true)
  comp:SetData("RunningOverlay.WidgetSlots", assigned)
  comp:SetData("RunningOverlay.TemplateSignature", template_signature)
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
  pcall(function() comp:SetData("RunningOverlay.TemplateSignature", previous_signature) end)
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

// Reads every style input of each active slot as JSON keyed by slot number. The
// control plane pairs slots with panel widgets by metric, so a cut overlay's
// pieces can be read without relying on composition data. Animated inputs
// contribute their value at the current composition time.
function templateCaptureScript({ token }) {
  const excluded = EXCLUDED_STYLE_KEYS.map((key) => `[${luaString(key)}] = true`).join(', ');
  return `
local status_key = "RunningOverlay.Operation"
local token = ${luaString(token)}
local excluded = { ${excluded} }
${WIDGET_PREFIXES}
local first_slot_suffixes = {Red = "R", Green = "G", Blue = "B", Alpha = "A"}
local function style_suffix(prefix, id)
  if prefix == "" and first_slot_suffixes[id] then return first_slot_suffixes[id] end
  return string.sub(id, #prefix + 1)
end
local escapes = {['"'] = '\\\\"', ['\\\\'] = '\\\\\\\\'}
local function json_string(value)
  return '"' .. string.gsub(value, '[%c"\\\\]', function(character)
    return escapes[character] or string.format("\\\\u%04x", string.byte(character))
  end) .. '"'
end
local function json_number(value)
  if value ~= value or value == math.huge or value == -math.huge then return nil end
  return string.format("%.17g", value)
end
local function json_point(value)
  if type(value) ~= "table" then return nil end
  local x, y = json_number(value[1] or value.X or 0/0), json_number(value[2] or value.Y or 0/0)
  return x and y and ("[" .. x .. "," .. y .. "]") or nil
end
local function json_value(value)
  if type(value) == "number" then return json_number(value) end
  if type(value) == "string" then return json_string(value) end
  if type(value) == "table" then return json_point(value) end
end
local ok, payload = pcall(function()
  local node
  for _, candidate in pairs(comp:GetToolList(false, "Fuse.RunningOverlayNumeric")) do
    if candidate:GetData("RunningOverlay.ManagedNumeric") then node = candidate end
  end
  assert(node, "The managed overlay has no Numeric node.")
  local suffixes = {}
  for _, input in pairs(node:GetInputList()) do
    local id = input:GetAttrs().INPS_ID
    local suffix = id and string.match(id, "^Widget16(.+)$")
    if suffix and not excluded[suffix] then table.insert(suffixes, suffix) end
  end
  -- Slot one predates the other fifteen and keeps its original input names.
  local function read(prefix, suffix) return node:GetInput(style_key(prefix, suffix)) end
  local slots = {}
  for slot, prefix in ipairs(prefixes) do
    local enabled = slot == 1 and node:GetInput("HeartRateEnabled") or read(prefix, "Enabled")
    if type(enabled) == "number" and enabled ~= 0 then
      local metric = node:GetInput(style_key(prefix, "Metric"))
      local point = json_point(node:GetInput(style_key(prefix, "Position")))
      assert(type(metric) == "number" and point, "Could not read widget slot " .. slot .. ".")
      local styles = {}
      for _, suffix in ipairs(suffixes) do
        local value = json_value(read(prefix, suffix))
        if value then table.insert(styles, json_string(suffix) .. ":" .. value) end
      end
      table.insert(slots, "\\"" .. slot .. "\\":{" .. "\\"metric\\":" .. metric .. ",\\"position\\":" .. point .. ",\\"styles\\":{" .. table.concat(styles, ",") .. "}}")
    end
  end
  return "{" .. table.concat(slots, ",") .. "}"
end)
comp:SetData(status_key, token .. (ok and ("|ok|" .. payload) or ("|error:" .. tostring(payload))))
`;
}

// Pairs captured slots with panel widgets by metric, in slot order. Duplicate
// metrics pair with successive slots, as the update assigns them.
function pairCapturedSlots(widgets, slots) {
  const byIndex = new Map(Object.entries(METRICS).map(([name, index]) => [index, name]));
  const entries = Object.entries(slots).map(([slot, value]) => ({ slot: Number(slot), metric: byIndex.get(value.metric), position: value.position, styles: value.styles }))
    .filter((entry) => entry.metric).sort((left, right) => left.slot - right.slot);
  const used = new Set();
  const captured = {};
  for (const widget of widgets) {
    const entry = entries.find((candidate) => !used.has(candidate.slot) && candidate.metric === widget.metric);
    if (!entry) continue;
    used.add(entry.slot);
    captured[widget.id] = { x: entry.position[0], y: entry.position[1], styles: entry.styles };
  }
  return captured;
}

module.exports = { luaString, dataUpdateScript, timeOffsetScript, validOffsetSeconds, validClockOffsetHours, templateCaptureScript, pairCapturedSlots };
