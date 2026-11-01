'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const { METRICS } = require('../src/domain/widgets');
const FUSE_NAMES = { heartRate: 'Heart Rate', pace: 'Pace', distance: 'Distance', elapsed: 'Elapsed', elevation: 'Elevation',
  cadence: 'Cadence', power: 'Power', calories: 'Calories', avgPace: 'Avg Pace', verticalOscillation: 'Vertical Oscillation',
  groundContactTime: 'Ground Contact Time', strideLength: 'Stride Length', verticalRatio: 'Vertical Ratio',
  groundContactBalance: 'GCT Balance', temperature: 'Temperature', grade: 'Grade', realTime: 'Real Time' };
assert.deepEqual(Object.values(METRICS), Object.keys(METRICS).map((_, index) => index));
const source = fs.readFileSync(path.join(__dirname, '../fusion/Fuses/RunningOverlayNumeric.fuse'), 'utf8');
function run(code) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const status = lauxlib.luaL_dostring(L, to_luastring('FuRegisterClass = function() end\n' + source + '\n' + code));
  assert.equal(status, lua.LUA_OK, status ? to_jsstring(lua.lua_tostring(L, -1)) : undefined);
  lua.lua_close(L);
}

test('actual Fuse converts metric units and rounds elapsed across minute boundaries', () => run(`
local data = {pauses = {}}
local sample = {distance_m=1609.344, pace_spk=300, elevation_m=-30.48, heart_rate=0, cadence=0, power_w=0, calories=0}
local _, value, unit = metric_text(2, sample, 0, data, 1)
assert(value == '1.00' and unit == 'mi')
_, value, unit = metric_text(1, sample, 0, data, 1)
assert(value == [[8'03"]] and unit == '/ mi')
_, value, unit = metric_text(1, sample, 0, data, 2)
assert(value == [[2'30"]] and unit == '/ 500m')
_, value, unit = metric_text(4, sample, 0, data, 1)
assert(value == '-100' and unit == 'ft')
_, value = metric_text(3, sample, 59600000, data, 1)
assert(value == '01:00')
_, value = metric_text(3, sample, 3600000000, data, 1)
assert(value == '60:00')
_, value = metric_text(3, sample, 59600000, data, 2)
assert(value == '60')
for _, metric in ipairs({0,5,6,7}) do _, value = metric_text(metric,sample,0,data,0); assert(value=='0') end
for _, metric in ipairs({0,2,4,5,6,7}) do _, value = metric_text(metric,{},0,data,1); assert(value=='--') end
assert(format_pace(0) == "--'--\\\"")
assert(format_pace(0/0) == "--'--\\\"")
assert(format_pace(math.huge) == "--'--\\\"")
`));

test('Inspector inputs drive independent text parts in the actual Process path', () => run(`
Number = function(value) return {Value=value} end
local inputs = {}
self = {Comp={}, AddControlPage=function() end, AddInput=function(_,label,key,attrs)
 local input={value=attrs.INP_DefaultText or attrs.INP_Default or '', attrs=attrs}
 if attrs.LINKID_DataType=='Point' then input.value={X=attrs.INP_DefaultX,Y=attrs.INP_DefaultY} end
 function input:GetValue() if type(self.value)=='table' then return self.value end; return {Value=self.value} end
 function input:SetSource(source) self.value=source.Value end
 inputs[key]=input; return input
end}
Create()
assert(inputs.Widget16UnitPosition.value==3)
-- Combo order is the metric index contract shared with widgets.js.
local names = {}
for _, choice in ipairs(inputs.Widget16Metric.attrs) do table.insert(names, choice.CCS_AddString) end
assert(table.concat(names, ',') == ${JSON.stringify(Object.keys(METRICS).map((key) => FUSE_NAMES[key]).join(','))}, table.concat(names, ','))
assert(inputs.Widget16TemperatureSource and inputs.Widget16ManualTemperature and inputs.Widget16OscillationUnits)
assert(inputs.Widget16LabelSize and inputs.Widget16ElevationUnits and inputs.Widget16LabelA)
Width=1920; Height=1080; Scale=1; XAspect=1; YAspect=1; SourceDepth=0
local composited={}
Image=function(attrs) local image={Height=1080,Width=1920,XScale=1,YScale=1,Fill=function() end}
 function image:Blur(dest, tags) dest.blur=tags.BLUR_XSize end
 function image:Merge(fg) table.insert(composited, fg) end
 return image end
Pixel=function(value) return value end
OutImage={Set=function() end}
ensure_fonts=function() end
TextStyleFont=function() end; TextStyleFontMetrics=function() end; Shape=function() end
add_text_shape=function(_,_,text,size) return #text*size end
local drawn={}
draw_text=function(_,font,style,text,size,x,y,color) table.insert(drawn,{text=text,font=font,size=size,color=color,x=x,y=y}); return #text*size end
load_data=function() return {timeline_start_frame=0,pauses={}} end
activity_elapsed_at_frame=function() return 0 end
sample_activity=function() return {distance_m=1609.344} end
inputs.Metric.value=2; inputs.DistanceUnits.value=1
inputs.CustomLabel.value='  Miles  '; inputs.LabelFont.value='Arial'; inputs.LabelSize.value=0.03; inputs.LabelA.value=0.4
inputs.UnitFont.value='Courier'; inputs.UnitSize.value=0.012; inputs.UnitR.value=0.2
inputs.ShadowEnabled.value=0; inputs.Widget16ShadowEnabled.value=0
local req={Time=0,IsQuick=function() return false end,IsStampOnly=function() return false end}
Process(req)
assert(#drawn==3 and drawn[1].text=='1.00' and drawn[2].text=='mi' and drawn[3].text=='Miles')
assert(drawn[2].font=='Courier' and drawn[2].size==0.012 and drawn[2].color.R==0.2)
assert(drawn[3].font=='Arial' and drawn[3].size==0.03 and drawn[3].color.A==0.4)
inputs.ShowUnit.value=0; inputs.ShowLabel.value=0; drawn={}; Process(req)
assert(#drawn==1 and drawn[1].text=='1.00')
inputs.HeartRateEnabled.value=0; inputs.Widget16Enabled.value=1; inputs.Widget16Metric.value=2
inputs.Widget16DistanceUnits.value=0; inputs.Widget16CustomLabel.value='Other'; drawn={}; Process(req)
assert(#drawn==3 and drawn[1].text=='1.61' and drawn[3].text=='Other')
`));

test('attachments measure all four sides and expand around preceding text', () => run(`
for position=0,3 do
 local bounds={left=0,right=2,bottom=0,top=1}
 local x,y=attach_text(bounds,0.5,0.25,position,0.1)
 if position==0 then assert(y==1.1)
 elseif position==1 then assert(y==-0.35)
 elseif position==2 then assert(x==-0.6)
 else assert(x==2.1) end
end
local bounds={left=0,right=2,bottom=0,top=1}
attach_text(bounds,1,0.25,3,0.1)
local x=attach_text(bounds,1,0.25,3,0.1)
assert(x>3.1)
local points=codepoints('心率 é')
assert(#points==4 and points[1]==24515 and points[2]==29575 and points[4]==233)
`));

test('actual Fuse formats running dynamics, temperature, grade and average pace like the Mac app', () => run(`
local data = {pauses = {{start_us=0, end_us=60000000}}}
local s = {distance_m=1000, oscillation_mm=85.35, contact_ms=244.5, stride_m=1.125, balance_left=49.6, temperature_c=-2.5, grade_pct=1.24}
local function text(metric, unit, manual, use_fit) local l, v, u = metric_text(metric, s, 300000000, data, unit, manual, use_fit); return l .. '|' .. v .. '|' .. u end
-- Average pace uses real elapsed time, not moving time, and follows pace units.
assert(text(8, 0) == [[AVG PACE|5'00"|/ km]])
assert(text(8, 1) == [[AVG PACE|8'03"|/ mi]])
assert(text(9, 0) == 'VERT. OSC.|8.5|cm' or text(9, 0) == 'VERT. OSC.|8.6|cm')
assert(text(9, 1) == 'VERT. OSC.|85|mm')
assert(text(10, 0) == 'GCT|245|ms')
assert(text(11, 0) == 'STRIDE|1.13|m' or text(11, 0) == 'STRIDE|1.12|m')
assert(text(12, 0) == 'VERT. RATIO|7.6|%')
assert(text(13, 0) == 'GCT BALANCE|49.6L / 50.4R|%')
-- Half values round away from zero for negative temperatures.
assert(text(14, 0) == 'TEMP|-3°|°C')
assert(text(14, 1) == 'TEMP|28°|°F')
assert(text(15, 0) == 'GRADE|+1.2|%')
s.grade_pct = -0.04; assert(text(15, 0) == 'GRADE|-0.0|%')
-- Temperature sources: FIT only, FIT then manual, manual only.
s.temperature_c = nil
assert(text(14, 0, nil, true) == 'TEMP|--|°C')
assert(text(14, 0, 21.5, true) == 'TEMP|22°|°C')
s.temperature_c = 10
assert(text(14, 0, 21.5, false) == 'TEMP|22°|°C')
-- Missing or zero denominators never divide.
local empty = {}
for metric = 9, 15 do local _, value = metric_text(metric, empty, 1, data, 0); assert(value == '--', metric) end
local _, value = metric_text(8, {distance_m=0}, 1000000, data, 0); assert(value == [[--'--"]])
_, value = metric_text(8, {distance_m=100}, 0, data, 0); assert(value == [[--'--"]])
_, value = metric_text(12, {oscillation_mm=80, stride_m=0}, 0, data, 0); assert(value == '--')
`));

const START_UTC_US = Date.UTC(2026, 6, 2, 22, 47, 3, 900) * 1000;
test('actual Fuse formats Real Time from the activity start with an explicit UTC offset', () => run(`
local data = {pauses = {}, start_utc_us = ${START_UTC_US}}
local function clock(elapsed_us, format, offset) local l, v, u = metric_text(16, {}, elapsed_us, data, format, nil, true, offset); return l .. '|' .. v .. '|' .. u end
-- Seconds truncate like DateFormatter: 22:47:03.9 UTC stays :03.
assert(clock(0, 0, 0) == 'REAL TIME|22:47:03|', clock(0, 0, 0))
assert(clock(0, 0, -4) == 'REAL TIME|18:47:03|')
assert(clock(0, 1, -4) == 'REAL TIME|6:47:03 PM|')
assert(clock(100000, 0, -4) == 'REAL TIME|18:47:04|')
-- Fractional offsets, midnight and noon in the 12-hour clock, and wrapping past midnight.
assert(clock(0, 0, 5.75) == 'REAL TIME|04:32:03|')
assert(clock((3600 - 47 * 60 - 3) * 1000000, 1, 1) == 'REAL TIME|12:00:00 AM|')
assert(clock((3600 - 47 * 60 - 3) * 1000000, 1, -11) == 'REAL TIME|12:00:00 PM|')
assert(clock(0, 1, 2) == 'REAL TIME|12:47:03 AM|')
assert(select(2, metric_text(16, {}, 0, {pauses = {}}, 0, nil, true, 0)) == '--')
`));

test('Real Time reads its start from the renderer activity file', () => run(`
-- Fengari has no io library; serve the renderer files from memory.
local files = {
 clock = 'ROACTIVITY\\t1\\nstartUtcUs\\t${START_UTC_US}\\nrecord\\t0\\t0',
 nostart = 'ROACTIVITY\\t1\\nrecord\\t0\\t0',
}
io = {open = function(name)
 local lines = {}
 for line in files[name]:gmatch('[^\\n]+') do table.insert(lines, line) end
 local index = 0
 local function next_line() index = index + 1; return lines[index] end
 return {read = next_line, lines = function() return next_line end, close = function() end}
end}
local records, _, start = read_activity('clock')
assert(#records == 1 and start == ${START_UTC_US})
local none, _, _, message = read_activity('nostart')
assert(none == nil and message == 'Activity data has no start time')
`));

test('shadow layers follow the Mac thickness model and draw beneath every text part', () => run(`
local layers = shadow_layers(0.7, 0.01, 1)
assert(layers[1].opacity == 0.7 and layers[2].opacity == 0 and layers[3].opacity == 0)
layers = shadow_layers(0.5, 0.01, 3)
assert(math.abs(layers[2].opacity - 0.32) < 1e-9 and math.abs(layers[2].radius - 0.0072) < 1e-12)
assert(math.abs(layers[3].opacity - 0.11) < 1e-9 and math.abs(layers[3].radius - 0.0048) < 1e-12)
assert(shadow_layers(1, 1, 9)[3].opacity == shadow_layers(1, 1, 4)[3].opacity)
Number = function(value) return {Value=value} end
local inputs = {}
self = {Comp={}, AddControlPage=function() end, AddInput=function(_,label,key,attrs)
 local input={value=attrs.INP_DefaultText or attrs.INP_Default or '', attrs=attrs}
 if attrs.LINKID_DataType=='Point' then input.value={X=attrs.INP_DefaultX,Y=attrs.INP_DefaultY} end
 function input:GetValue() if type(self.value)=='table' then return self.value end; return {Value=self.value} end
 inputs[key]=input; return input
end}
Create()
-- Defaults are the Mac element defaults at the 1280-point reference.
assert(inputs.ShadowEnabled.value == 1 and inputs.ShadowOpacity.value == 0.35 and inputs.ShadowR.value == 0)
assert(inputs.ShadowBlur.value == 4 / 1280 and inputs.ShadowOffsetY.value == -2 / 1280 and inputs.Widget16ShadowThickness.value == 1)
assert(inputs.Widget16ClockFormat and inputs.Widget16ClockUtcOffset.value == 0)
Width=1920; Height=1080; Scale=1; XAspect=1; YAspect=1; SourceDepth=0
local events = {}
Image=function() local image={Height=1080,Width=1920,XScale=1,YScale=1,Fill=function() end}
 function image:Blur(dest, tags) table.insert(events, 'blur ' .. tags.BLUR_XSize); dest.blurred = true end
 function image:Merge(fg) table.insert(events, fg.blurred and 'merge blurred' or 'merge sharp') end
 return image end
Pixel=function(value) return value end
OutImage={Set=function() end}
ensure_fonts=function() end
TextStyleFont=function() end; TextStyleFontMetrics=function() end; Shape=function() end
add_text_shape=function(_,_,text,size) return #text*size end
draw_text=function(_,_,_,text,_,x,y,color) table.insert(events, string.format('text %s %.4f %.4f %.3f', text, x, y, color.A)) return 0 end
load_data=function() return {timeline_start_frame=0,pauses={}} end
activity_elapsed_at_frame=function() return 0 end
sample_activity=function() return {distance_m=1000} end
inputs.Metric.value=2; inputs.ShowLabel.value=0; inputs.Position.value={X=0.1,Y=0.5}
inputs.ShadowOpacity.value=0.7; inputs.ShadowOffsetX.value=0.003; inputs.ShadowOffsetY.value=-0.003; inputs.ShadowBlur.value=0.002
local req={Time=0,IsQuick=function() return false end,IsStampOnly=function() return false end}
Process(req)
local y = 0.5 * 1080 / 1920
local expected = {
 string.format('text 1.00 %.4f %.4f 0.700', 0.103, y - 0.003),
 'text km', 'blur ' .. 0.002 * SHADOW_BLUR_SCALE, 'merge blurred',
 string.format('text 1.00 %.4f %.4f 1.000', 0.1, y), 'text km',
}
assert(#events == #expected, table.concat(events, ' | '))
for index, value in ipairs(expected) do assert(events[index]:sub(1, #value) == value, events[index]) end
-- Thickness adds tighter layers; zero blur merges the sharp silhouette; disabled draws no shadow.
inputs.ShadowThickness.value=3; events={}; Process(req)
local blurs = 0; for _, event in ipairs(events) do if event:sub(1, 4) == 'blur' then blurs = blurs + 1 end end
assert(blurs == 3, table.concat(events, ' | '))
inputs.ShadowThickness.value=1; inputs.ShadowBlur.value=0; events={}; Process(req)
assert(events[3] == 'merge sharp', table.concat(events, ' | '))
inputs.ShadowEnabled.value=0; events={}; Process(req)
assert(#events == 2, table.concat(events, ' | '))
`));
