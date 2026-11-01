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
  groundContactBalance: 'GCT Balance', temperature: 'Temperature', grade: 'Grade', realTime: 'Real Time', distanceTimeline: 'Distance Timeline', routeMap: 'Route Map', zoneEdgeBar: 'HR Zone Bar', elevationChart: 'Elevation Chart', weatherWidget: 'Weather', date: 'Date', customNumeric: 'Custom Numeric', heartRateZone: 'HR Zone', runningGauge: 'Running Gauge', decoSolidColor: 'Solid Color', decorIcon: 'Decor Icon', decorText: 'Decor Text', lapPace: 'Lap Pace', intervalHUDBar: 'Interval HUD Bar', intervalTimeline: 'Interval Timeline', intervalCountdown: 'Interval Countdown', intervalWorkSummary: 'Interval Work Summary' };
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
assert(value == [[8'03"]] and unit == '/mi')
_, value, unit = metric_text(1, sample, 0, data, 2)
assert(value == [[2'30"]] and unit == '/500m')
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
 function input:SetAttrs(attrs) self.visible=attrs.IC_Visible end
 inputs[key]=input; return input
end}
Create()
assert(inputs.Widget16UnitPosition.value==3)
-- Combo order is the metric index contract shared with widgets.js.
local names = {}
for _, choice in ipairs(inputs.Widget16Metric.attrs) do table.insert(names, choice.CCS_AddString) end
assert(table.concat(names, ',') == ${JSON.stringify(Object.keys(METRICS).map((key) => FUSE_NAMES[key]).join(','))}, table.concat(names, ','))
assert(inputs.Widget16TemperatureSource and inputs.Widget16ManualTemperature and inputs.Widget16OscillationUnits)
local function combo_names(input) local out={}; for _, choice in ipairs(input.attrs) do table.insert(out, choice.CCS_AddString) end; return table.concat(out, ',') end
assert(combo_names(inputs.Widget16DateFormat) == 'yyyy-MM-dd,yyyy/MM/dd,MM/dd/yyyy,MM-dd,MM/dd,MMM d')
assert(combo_names(inputs.Widget16CustomFormat) == 'Number,Integer,Duration,Clock Time,Date,Pace,Percent,Coordinate')
assert(#inputs.Widget16CustomField.attrs == 19)
assert(inputs.Widget16CustomField.attrs[1].CCS_AddString == 'Timestamp' and inputs.Widget16CustomField.attrs[19].CCS_AddString == 'Grade (%)')
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
icon_shapes=function() return {} end
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

test('Lap Pace restarts from the latest lap boundary and stays missing before one', () => run(`
local data = {pauses = {}, laps = {
  {start_us = 0, start_distance_m = 0},
  {start_us = 300000000, start_distance_m = 1000},
}}
local function lap(value, distance) return metric_text(29, {distance_m = distance}, value, data, 0) end
local label, value, unit = lap(600000000, 2000)
assert(label == 'LAP PACE' and value == [[5'00"]] and unit == '/km')
_, value = lap(300000000, 1000)
assert(value == [[--'--"]], value)
_, value = lap(450000000, 1500)
assert(value == [[5'00"]], value)
local later = {pauses = {}, laps = {{start_us = 400000000, start_distance_m = 0}}}
_, value = metric_text(29, {distance_m = 999}, 399000000, later, 0)
assert(value == [[--'--"]], value)
_, value = metric_text(29, {distance_m = 2000}, 600000000, {pauses = {}}, 0)
assert(value == [[--'--"]], value)
`));


test('interval HUD, timeline, countdown and summary read lap phase data', () => run(HOST + `
local base_capsule=capsule
capsule=function(...) local s=base_capsule(...);function s:OutlineOfShape() return s end;return s end
local laps={
 {start_us=0,end_us=300000000,start_distance_m=0,total_distance_m=1000,total_elapsed_s=300,avg_pace_spk=300,kind='warmup'},
 {start_us=300000000,end_us=600000000,start_distance_m=1000,total_distance_m=1000,total_elapsed_s=300,avg_pace_spk=300,avg_hr=160,avg_power=250,avg_cadence=180,kind='active'},
 {start_us=600000000,end_us=900000000,start_distance_m=2000,total_distance_m=700,total_elapsed_s=300,avg_pace_spk=420,kind='rest'},
 {start_us=900000000,end_us=1200000000,start_distance_m=2700,total_distance_m=1000,total_elapsed_s=300,avg_pace_spk=300,avg_hr=170,kind='active'},
 {start_us=1200000000,end_us=1500000000,start_distance_m=3700,total_distance_m=1000,total_elapsed_s=300,avg_pace_spk=330,kind='cooldown'},
}
load_data=function() return {timeline_start_frame=0,pauses={},total_distance_m=4700,duration_us=1500000000,laps=laps} end
sample_activity=function() return {distance_m=1500,heart_rate=160,pace_spk=300} end
local at=450000000
activity_elapsed_at_frame=function() return at end
inputs.ShadowEnabled.value=0;inputs.Widget16ShadowEnabled.value=0
local function has(text)
 for _,entry in ipairs(of('text')) do if entry.text==text then return true end end
 return false
end
inputs.Metric.value=INTERVAL_HUD_METRIC
Process(req)
assert(has('WORK') and has('1 / 2') and has('2:30') and has('LEFT'))
inputs.Metric.value=INTERVAL_TIMELINE_METRIC
events={};Process(req)
assert(#of('shape')>=6)
assert(has('5:00'))
inputs.Metric.value=INTERVAL_COUNTDOWN_METRIC
events={};Process(req)
assert(has('CURRENT SET') and has('WORK') and has('1 / 2') and has('2:30') and has('remaining'))
inputs.CountdownCenterMetric.value=1;inputs.CountdownCenterDirection.value=1;events={};Process(req)
assert(has('500 m'))
at=601000000;events={};Process(req)
assert(has('0 m'))
at=601000000
inputs.Metric.value=INTERVAL_SUMMARY_METRIC
events={};Process(req)
assert(has('WORK SUMMARY') and has('5:00') and has('LAP TIME'))
assert(has([[5'00" /km]]) and has('PACE'))
assert(has('1.00 km') and has('DIST'))
assert(has('160 bpm') and has('HR'))
inputs.SummarySecondary3.value=5;events={};Process(req)
assert(has('250 W') and has('POWER'))
inputs.SummarySecondary3.value=3
at=700000000;events={};Process(req)
assert(#of('text')==0)
NotifyChanged(inputs.Metric,{Value=INTERVAL_SUMMARY_METRIC})
assert(inputs.SummaryWidth.visible==true and inputs.CountdownSize.visible==false and inputs.HudWidth.visible==false)
NotifyChanged(inputs.Metric,{Value=INTERVAL_HUD_METRIC})
assert(inputs.HudWidth.visible==true and inputs.IntervalTimelineWidth.visible==false)
NotifyChanged(inputs.Metric,{Value=INTERVAL_TIMELINE_METRIC})
assert(inputs.IntervalTimelineWidth.visible==true and inputs.SummaryWidth.visible==false)
NotifyChanged(inputs.Metric,{Value=INTERVAL_COUNTDOWN_METRIC})
assert(inputs.CountdownSize.visible==true and inputs.HudWidth.visible==false)
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
assert(text(8, 0) == [[AVG PACE|5'00"|/km]])
assert(text(8, 1) == [[AVG PACE|8'03"|/mi]])
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
 function input:SetAttrs(attrs) self.visible=attrs.IC_Visible end
 inputs[key]=input; return input
end}
Create()
-- Defaults are the Mac element defaults; shadow radius and offset are 1920-wide output pixels.
assert(inputs.ShadowEnabled.value == 1 and inputs.ShadowOpacity.value == 0.35 and inputs.ShadowR.value == 0)
assert(inputs.ShadowBlur.value == 4 / 1920 and inputs.ShadowOffsetY.value == -2 / 1920 and inputs.Widget16ShadowThickness.value == 1)
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
icon_shapes=function() return {} end
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

// Host mocks shared by the icon and timeline tests: font metrics with ascent
// 0.8 and descent 0.2 of the size, and recorded text, shape fills and blurs.
const HOST = `
Number = function(value) return {Value=value} end
inputs = {}
self = {Comp={}, AddControlPage=function() end, AddInput=function(_,label,key,attrs)
 local input={value=attrs.INP_DefaultText or attrs.INP_Default or '', attrs=attrs}
 if attrs.LINKID_DataType=='Point' then input.value={X=attrs.INP_DefaultX,Y=attrs.INP_DefaultY} end
 function input:GetValue() if type(self.value)=='table' then return self.value end; return {Value=self.value} end
 function input:SetSource(source) self.value=source.Value end
 function input:SetAttrs(attrs) self.visible=attrs.IC_Visible end
 inputs[key]=input; return input
end}
Create()
Width=1920; Height=1080; Scale=1; XAspect=1; YAspect=1; SourceDepth=0
events = {}
Image=function() local image={Height=1080,Width=1920,XScale=1,YScale=1,Fill=function() end}
 function image:Blur(dest, tags) table.insert(events, {kind='blur', size=tags.BLUR_XSize}) end
 function image:Merge() table.insert(events, {kind='merge'}) end
 return image end
Pixel=function(value) return value end
OutImage={Set=function() end}
ensure_fonts=function() end
TextStyleFont=function() end
TextStyleFontMetrics=function() return {TextAscent=0.08, TextDescent=0.02, TextExternalLeading=0} end
add_text_shape=function(_,_,text,size) return #text*size end
draw_text=function(_,_,_,text,size,x,y,color) table.insert(events,{kind='text',text=text,size=size,x=x,y=y,color=color}) return #text*size end
fill_shape=function(_,shape,color) table.insert(events,{kind='shape',shape=shape,color=color}) end
local function moved(shape) return shape end
Matrix4=function() return {Move=function() end} end
capsule=function(l,b,w,h) return {kind='capsule',l=l,b=b,w=w,h=h,TransformOfShape=moved} end
Shape=function() local s={rects={},TransformOfShape=moved}
 function s:AddRectangle(l,r,t,b) table.insert(self.rects,{l,r,t,b}) end
 function s:MoveTo(x,y) self.start={x,y} end; function s:LineTo() end; function s:Close() end
 return s end
activity_elapsed_at_frame=function() return 0 end
req={Time=0,IsQuick=function() return false end,IsStampOnly=function() return false end}
function near(a, b) return math.abs(a - b) < 1e-9 end
function of(kind) local r={} for _,e in ipairs(events) do if e.kind==kind then table.insert(r,e) end end return r end
`;

test('numeric icons default per metric, attach like the Mac layout and join the shadow', () => run(HOST + `
local icons = {}
local glyph = {TransformOfShape=function(self) return self end}
icon_shapes=function(name,left,top,size) table.insert(icons,{name=name,left=left,top=top,size=size}); return {glyph} end
load_data=function() return {timeline_start_frame=0,pauses={},start_utc_us=0} end
sample_activity=function() return {heart_rate=150} end
inputs.ShadowEnabled.value=0; inputs.ShowLabel.value=0; inputs.ShowUnit.value=0
inputs.ValueSize.value=0.05; inputs.Position.value={X=0.1,Y=0.5}
Process(req)
local y = 0.5 * 1080 / 1920
-- Leading, centered on the value line box from y - descent to y + size.
assert(#icons==1 and icons[1].name=='Heart' and near(icons[1].size, 22/1280))
assert(near(icons[1].left, 0.1 - 8/1280 - 22/1280), icons[1].left)
assert(near(icons[1].top, (y - 0.01 + y + 0.04) / 2 + 11/1280), icons[1].top)
assert(#of('shape')==1 and of('shape')[1].shape==glyph and of('shape')[1].color.A==1)
-- Every metric has a default glyph; the Inspector glyph overrides it.
for metric = 0, 16 do assert(ICON_GLYPHS[DEFAULT_ICONS[metric]], metric) end
assert(DEFAULT_ICONS[22] == 'Calendar')
for index = 2, #ICON_NAMES do assert(ICON_GLYPHS[ICON_NAMES[index]], ICON_NAMES[index]) end
inputs.Metric.value=16; icons={}; Process(req); assert(icons[1].name=='Watch')
inputs.Metric.value=22; icons={}; Process(req); assert(icons[1].name=='Calendar')
inputs.IconGlyph.value=7; icons={}; Process(req); assert(icons[1].name=='Runner')
-- Top placement aligned to the start sits one spacing above the block.
inputs.IconPosition.value=0; inputs.IconAlignment.value=0; icons={}; Process(req)
assert(near(icons[1].left, 0.1) and near(icons[1].top, y + 0.04 + 8/1280 + 22/1280))
-- The icon silhouette is drawn in the shadow pass with the icon opacity.
inputs.IconA.value=0.5; inputs.ShadowEnabled.value=1; events={}; Process(req)
local shapes = of('shape')
assert(#shapes==2 and near(shapes[1].color.A, 0.35*0.5) and shapes[1].color.R==0 and shapes[2].color.A==0.5)
inputs.IconEnabled.value=0; icons={}; Process(req); assert(#icons==0)
`));

test('icon glyphs stay inside their box and arcs keep their radius', () => run(`
local points = {}
Matrix4=function() return {} end
Shape=function() local s={}
 function s:MoveTo(x,y) table.insert(points,{x,y}) end
 function s:LineTo(x,y) table.insert(points,{x,y}) end
 function s:BezierTo(_,_,_,_,x,y) table.insert(points,{x,y}) end
 function s:Close() end
 function s:OutlineOfShape(width) self.width=width; return self end
 return s end
for name in pairs(ICON_GLYPHS) do
 points = {}
 local shapes = icon_shapes(name, 1, 2, 0.24)
 assert(#shapes >= 1 and shapes[1].width > 0, name)
 for _, p in ipairs(points) do
  assert(p[1] >= 1 - 1e-9 and p[1] <= 1.24 + 1e-9 and p[2] <= 2 + 1e-9 and p[2] >= 1.76 - 1e-9, name)
 end
end
points = {}
glyph_shape('O12 12 10', 0, 24, 24)
assert(#points == 5)
for _, p in ipairs(points) do assert(math.abs(math.sqrt((p[1]-12)^2 + (p[2]-12)^2) - 10) < 1e-9) end
points = {}
glyph_shape('M0 0 A12 12 6 180 270', 0, 24, 24)
assert(math.abs(points[2][1] - 6) < 1e-9 and math.abs(points[#points][2] - 18) < 1e-9)
`));

test('distance timeline lays out the Mac minimal template from the activity total', () => run(HOST + `
load_data=function() return {timeline_start_frame=0,pauses={},total_distance_m=20000,duration_us=7200000000} end
local distance = 5000
sample_activity=function() return {distance_m=distance} end
inputs.HeartRateEnabled.value=0; inputs.Widget16Enabled.value=1; inputs.Widget16Metric.value=TIMELINE_METRIC
inputs.Widget16Position.value={X=0.5,Y=0.5}; inputs.Widget16ShadowEnabled.value=0
inputs.Widget16TimelineGlow.value=0; inputs.Widget16TimelineElementGlow.value=0
Process(req)
local w, h, px, py = 522.08/1280, 68/1280, 14/1280, 10/1280
local left, content_top = 0.5 - w/2 + px, 0.5*1080/1920 + h/2 - py
local cw = w - 2*px
local track_top = content_top - (19/1280*1.35 + 8/1280)
local track_bottom = track_top - 6/1280
local shapes, texts = of('shape'), of('text')
-- Track, fill to 25%, 13 ticks, then a dot marker of 2.2 track heights.
assert(#shapes == 4, #shapes)
local track, fill, ticks, marker = shapes[1], shapes[2], shapes[3], shapes[4]
assert(near(track.shape.l, left) and near(track.shape.w, cw) and near(track.shape.b, track_bottom))
assert(near(track.color.A, 0.62945) and track.color.R == 1)
assert(near(fill.shape.w, cw * 0.25) and fill.color.G == 0.82)
assert(#ticks.shape.rects == 13 and near(ticks.color.A, 0.64*0.52))
assert(near(ticks.shape.rects[13][1] + 0.5/1920, left + cw) and near(ticks.shape.rects[1][3], track_top + 2.7/1280))
assert(near(marker.shape.w, 13.2/1280) and near(marker.shape.l + marker.shape.w/2, left + cw*0.25))
assert(near(marker.shape.b + marker.shape.h/2, track_bottom + 3/1280))
-- Value top-aligned in its line box; axis labels centered in their bands below the track.
assert(texts[1].text == '5.00 / 20.00 km' and near(texts[1].x, left) and near(texts[1].y, content_top - 0.8*19/1280))
local axis = 10/1280
local baseline = track_bottom - 14.123/1280 - axis*1.3/2 - 0.3*axis
assert(texts[2].text == 'START' and near(texts[2].x, left) and near(texts[2].y, baseline))
assert(texts[3].text == 'FINISH' and near(texts[3].x, left + cw - 6*axis))
assert(texts[4].text == '5.00 km' and texts[5].text == '10.0 km' and texts[6].text == '15.0 km')
assert(near(texts[5].x, left + cw/2 - 7*axis/2))
-- A sample without distance keeps the track but shows no progress.
distance = nil; events = {}; Process(req)
assert(#of('shape') == 2 and of('text')[1].text == '-- / 20.00 km')
-- Miles, current-only value, distance axis labels.
distance = 5000; inputs.Widget16TimelineUnits.value=1; inputs.Widget16TimelineShowTotal.value=0; inputs.Widget16TimelineAxisMode.value=1
events = {}; Process(req)
texts = of('text')
assert(texts[1].text == '3.11 mi' and texts[2].text == '0 mi' and texts[3].text == '12.43 mi' and texts[4].text == '3.11 mi')
-- Without distance data, progress follows time like the Mac app.
load_data=function() return {timeline_start_frame=0,pauses={},total_distance_m=0,duration_us=7200000000} end
activity_elapsed_at_frame=function() return 3600000000 end
distance = nil; events = {}; Process(req)
assert(near(of('shape')[2].shape.w, cw * 0.5))
`));

test('distance timeline glows and shadows the whole widget beneath its parts', () => run(HOST + `
load_data=function() return {timeline_start_frame=0,pauses={},total_distance_m=20000,duration_us=7200000000} end
sample_activity=function() return {distance_m=10000} end
inputs.HeartRateEnabled.value=0; inputs.Widget16Enabled.value=1; inputs.Widget16Metric.value=TIMELINE_METRIC
inputs.Widget16ShadowThickness.value=3
Process(req)
-- Element glow (2 layers), shadow (3 layers), then fill and marker accent glows.
local blurs = of('blur')
assert(#blurs == 7, #blurs)
assert(near(blurs[1].size, 0.1*18/1920*SHADOW_BLUR_SCALE) and near(blurs[2].size, 0.1*34/1920*SHADOW_BLUR_SCALE))
assert(near(blurs[3].size, 4/1920*SHADOW_BLUR_SCALE))
assert(near(blurs[6].size, 6/1280*2.8*SHADOW_BLUR_SCALE) and near(blurs[7].size, 6/1280*2.3*SHADOW_BLUR_SCALE))
-- The first glow silhouette carries the glow color at 0.072 of each part's alpha.
local first = of('shape')[1]
assert(first.color.G == 0.82 and near(first.color.A, 0.072 * 0.62945))
`));

test('slot pages show number or timeline controls for the chosen metric', () => run(HOST + `
assert(inputs.Widget16TimelineWidth.visible == false and inputs.TimelineWidth.visible == false)
NotifyChanged(inputs.Widget16Metric, {Value=TIMELINE_METRIC})
assert(inputs.Widget16TimelineWidth.visible == true and inputs.Widget16TimelineAxisFont.visible == true)
assert(inputs.Widget16IconEnabled.visible == false and inputs.Widget16ValueSize.visible == false and inputs.Widget16UnitR.visible == false)
assert(inputs.Widget16ShadowEnabled.visible == nil and inputs.Widget15TimelineWidth.visible == false)
NotifyChanged(inputs.Widget16Metric, {Value=2})
assert(inputs.Widget16TimelineWidth.visible == false and inputs.Widget16IconEnabled.visible == true)
NotifyChanged(inputs.Metric, {Value=TIMELINE_METRIC})
assert(inputs.ValueSize.visible == false and inputs.ShowLabel.visible == false and inputs.TimelineWidth.visible == true)
`));

test('the activity snapshot records the furthest distance and the duration', () => run(`
read_activity=function() return {{elapsed_us=0,distance_m=0},{elapsed_us=10,distance_m=900},{elapsed_us=20}}, {}, 1, nil end
read_sync=function() return {{start_frame=0}}, 0, nil end
local snapshot = load_data('a.roactivity', 'b.rosync')
assert(snapshot.total_distance_m == 900 and snapshot.duration_us == 20)
`));

test('known template fonts use em sizing without guessing other font units', () => run(`
assert(em_size({Scale=3200}, 0.02, 'Monaco') == 0.03125)
assert(math.abs(em_size({Scale=1400}, 0.02, 'PT Mono') - 0.028) < 1e-12)
assert(em_size({Scale=1400}, 0.02, 'Other') == 0.02)
`));

test('route geometry preserves north, aspect, gaps, dateline and stationary samples', () => run(`
local records = {
 {elapsed_us=0, latitude_deg=0, longitude_deg=179.99, route_segment=0},
 {elapsed_us=10, latitude_deg=0.01, longitude_deg=-179.99, route_segment=0},
 {elapsed_us=20},
 {elapsed_us=30, latitude_deg=0.02, longitude_deg=-179.98, route_segment=1},
 {elapsed_us=40, latitude_deg=0.03, longitude_deg=-179.97, route_segment=2},
}
local route = prepare_route(records)
assert(route.count==4 and #route.paths==3 and #route.paths[1]==2)
assert(records[2].route_x > records[1].route_x and records[2].route_y > records[1].route_y)
assert(math.abs(records[2].route_x-records[1].route_x) < 0.6)
for _,path in ipairs(route.paths) do for _,p in ipairs(path) do assert(math.abs(p.x)<=0.5 and math.abs(p.y)<=0.5) end end
local sample = sample_activity({records=records}, 5)
assert(math.abs(sample.route_x-(records[1].route_x+records[2].route_x)/2)<1e-9)
assert(sample_activity({records=records}, 15).route_x==nil)
assert(sample_activity({records=records}, 35).route_x==nil)
local still={{elapsed_us=0,latitude_deg=90,longitude_deg=0},{elapsed_us=10,latitude_deg=90,longitude_deg=0}}
local stationary=prepare_route(still)
assert(stationary.count==2 and still[1].route_x==0 and still[1].route_y==0)
assert(prepare_route({{latitude_deg=100,longitude_deg=0}}).count==0)
`));

test('route map renders separate strokes, moving cursor, no GPS and independent slots', () => run(HOST + `
local function shape()
 local s={points={},TransformOfShape=function(self) return self end}
 function s:MoveTo(x,y) table.insert(self.points,{x,y}) end
 function s:LineTo(x,y) table.insert(self.points,{x,y}) end
 function s:OutlineOfShape(w) self.width=w; return self end
 return s
end
Shape=shape
local records={{elapsed_us=0,latitude_deg=0,longitude_deg=0},{elapsed_us=10,latitude_deg=1,longitude_deg=1}}
local route=prepare_route(records)
load_data=function() return {route=route,records=records} end
sample_activity=function() return {route_x=0,route_y=0} end
inputs.Metric.value=ROUTE_METRIC;inputs.ShadowEnabled.value=0
Process(req)
local shapes=of('shape')
assert(#shapes==3 and #shapes[1].shape.points==2 and #of('text')==0)
assert(near(shapes[1].shape.width,3/1280))
inputs.RouteMarker.value=0; events={}; Process(req); assert(#of('shape')==1)
inputs.RouteEndpoints.value=1; events={}; Process(req); assert(#of('shape')==3)
load_data=function() return {route={paths={},count=0}} end
events={};Process(req);assert(of('text')[1].text=='NO GPS')
inputs.HeartRateEnabled.value=0;inputs.Widget16Enabled.value=1;inputs.Widget16Metric.value=ROUTE_METRIC
events={};Process(req);assert(of('text')[1].text=='NO GPS')
NotifyChanged(inputs.Widget16Metric,{Value=ROUTE_METRIC})
assert(inputs.Widget16RouteSize.visible==true and inputs.Widget16TimelineWidth.visible==false and inputs.Widget16IconEnabled.visible==false)
NotifyChanged(inputs.Widget16Metric,{Value=1})
assert(inputs.Widget16RouteSize.visible==false and inputs.Widget16IconEnabled.visible==true)
`));

test('unit line boxes follow start, center and end alignment independently of icons', () => run(HOST + `
load_data=function() return {} end
sample_activity=function() return {distance_m=1000} end
inputs.Metric.value=2;inputs.ShowLabel.value=0;inputs.IconEnabled.value=0;inputs.ShadowEnabled.value=0
inputs.ValueSize.value=0.05;inputs.UnitSize.value=0.02;inputs.UnitPosition.value=3
for alignment=0,2 do
 inputs.UnitAlignment.value=alignment;events={};Process(req)
 local texts=of('text');assert(#texts==2)
 local expected = alignment==0 and 0.024 or (alignment==1 and 0.009 or -0.006)
 assert(near(texts[2].y-texts[1].y, expected))
end
`));

test('heart-rate zones classify rounded bpm with inclusive first-match boundaries', () => run(`
local ranges={{0,134},{134,151},{152,160},{161,171},{172,178},{178,250}}
assert(heart_rate_zone(134,ranges)==1)
assert(heart_rate_zone(151.49,ranges)==2)
assert(heart_rate_zone(151.5,ranges)==3)
assert(heart_rate_zone(178,ranges)==5)
assert(heart_rate_zone(nil,ranges)==nil and heart_rate_zone(300,ranges)==nil)
assert(heart_rate_zone(150,{{160,140}})==nil)
local index,f=heart_rate_zone(160,{{160,160}});assert(index==1 and f==0.5)
local frames=zone_frames(6,2,0.4)
assert(math.abs(frames[2].width-0.4)<1e-9 and math.abs(frames[6].start+frames[6].width-1)<1e-9)
assert(zone_frames(6,nil,0.4)[1].width==1/6)
`));

test('HR Zone metric labels rounded bpm using the instance ranges', () => run(HOST + `
load_data=function() return {} end
local hr=155
sample_activity=function() return {heart_rate=hr} end
inputs.Metric.value=HR_ZONE_METRIC;inputs.ShowLabel.value=0;inputs.ShowUnit.value=0;inputs.IconEnabled.value=0;inputs.ShadowEnabled.value=0
Process(req)
assert(of('text')[1].text=='Z3')
hr=161.5;events={};Process(req);assert(of('text')[1].text=='Z4')
hr=nil;events={};Process(req);assert(of('text')[1].text=='--')
hr=140;inputs.ZoneCount.value=0;inputs.Zone1Max.value=0;inputs.Zone2Min.value=200;events={};Process(req)
assert(of('text')[1].text=='--')
NotifyChanged(inputs.Metric,{Value=HR_ZONE_METRIC})
assert(inputs.ZoneCount.visible==true and inputs.Zone1Min.visible==true and inputs.TimelineWidth.visible==false)
`));

test('decor solid color, icon and text render without an activity sample', () => run(HOST + `
local icon_call
icon_shapes=function(name,left,top,size) icon_call={name=name,left=left,top=top,size=size}; return {capsule(left,top-size,size,size,0)} end
load_data=function() return {} end
sample_activity=function() return nil end
inputs.ShadowEnabled.value=0
inputs.Metric.value=DECOR_SOLID_METRIC;inputs.DecorShape.value=0;inputs.DecorFillR.value=0.2
Process(req)
local shapes=of('shape');assert(#shapes==1 and #shapes[1].shape.rects==1 and near(shapes[1].shape.rects[1][1],0.08-0.1))
assert(shapes[1].color.R==0.2)
inputs.Metric.value=DECOR_ICON_METRIC;events={};Process(req)
assert(icon_call.name=='Heart' and near(icon_call.size,64/1280) and #of('shape')==1)
inputs.Metric.value=DECOR_TEXT_METRIC;inputs.DecorText.value='GO';inputs.DecorAlignment.value=0;events={};Process(req)
assert(#of('text')==1 and of('text')[1].text=='GO' and near(of('text')[1].x,0.08))
inputs.DecorAlignment.value=2;events={};Process(req)
assert(of('text')[1].x<0.08)
NotifyChanged(inputs.Metric,{Value=DECOR_TEXT_METRIC})
assert(inputs.DecorText.visible==true and inputs.DecorTextColorR.visible==true and inputs.TimelineWidth.visible==false)
`));

test('running gauge draws dial, regions and the distance progress ring', () => run(HOST + `
local base_capsule=capsule
capsule=function(...) local s=base_capsule(...);function s:OutlineOfShape() return s end;return s end
load_data=function() return {timeline_start_frame=0,pauses={},total_distance_m=2000,duration_us=600000000} end
sample_activity=function() return {distance_m=1000,heart_rate=150,pace_spk=300} end
inputs.Metric.value=GAUGE_METRIC;inputs.GaugeTicks.value=0;inputs.GaugeProgress.value=1;inputs.ShadowEnabled.value=0
Process(req)
local function has(text)
 for _, entry in ipairs(of('text')) do if entry.text==text then return true end end
 return false
end
assert(has('1.00') and has('DIST') and has('km'))
assert(has([[5'00"]]) and has('PACE') and has('/km'))
assert(has('00:00') and has('TIME') and has('HR') and has('bpm'))
assert(#of('shape')>=4)
inputs.GaugeDial.value=0;inputs.GaugeRing.value=0;inputs.GaugeProgress.value=0;inputs.GaugeDividers.value=0
events={};Process(req);assert(#of('shape')==0)
`));

test('zone bar draws active segments, threshold and inward markers on all four edges', () => run(HOST + `
local base_capsule=capsule
capsule=function(...) local s=base_capsule(...);function s:OutlineOfShape() return self end;return s end
local hr=150
load_data=function() return {} end
sample_activity=function() return {heart_rate=hr} end
inputs.Metric.value=ZONE_METRIC;inputs.ShadowEnabled.value=0
Process(req)
assert(#of('shape')==9 and #of('text')==1 and of('text')[1].text=='T')
assert(of('shape')[1].color.A==0.55 and of('shape')[2].color.A==1)
local bottom_tip=of('shape')[9].shape.start
assert(bottom_tip[2]>10/1280)
for placement=1,3 do
 inputs.ZonePlacement.value=placement;events={};Process(req)
 local tip=of('shape')[9].shape.start
 if placement==1 then assert(tip[2]<1080/1920-10/1280)
 elseif placement==2 then assert(tip[1]>10/1280)
 else assert(tip[1]<1-10/1280) end
end
hr=nil;events={};Process(req)
assert(#of('shape')==8 and of('shape')[2].color.A==0.55)
inputs.ZoneThresholdEnabled.value=0;events={};Process(req)
assert(#of('shape')==7 and #of('text')==0)
inputs.ZoneCount.value=0;events={};Process(req);assert(#of('shape')==6)
inputs.HeartRateEnabled.value=0;inputs.Widget16Enabled.value=1;inputs.Widget16Metric.value=ZONE_METRIC
inputs.Widget16ShadowEnabled.value=0;events={};Process(req);assert(of('text')[1].text=='T')
NotifyChanged(inputs.Widget16Metric,{Value=ZONE_METRIC})
assert(inputs.Widget16ZoneLength.visible==true and inputs.Widget16RouteSize.visible==false and inputs.Widget16IconEnabled.visible==false)
`));

test('elevation profile caches full sample-index geometry and endpoint-preserving smoothing', () => run(`
local records={{elapsed_us=0,elevation_m=-10,distance_m=0},{elapsed_us=5,elevation_m=90,distance_m=1},{elapsed_us=999},{elapsed_us=1000,elevation_m=10,distance_m=5000}}
local p=prepare_elevation(records)
assert(#p.values==3 and #p.raw.points==3 and p.raw.points[2].x==0.5)
assert(p.smoothed[1]==-10 and p.smoothed[3]==10 and p.smoothed[2]<90)
assert(#p.smooth.points==13 and #p.smooth.bands==24)
local x,y=elevation_marker(p.values,500000,1000000);assert(x==0.5 and y==1)
-- Distance and irregular timestamps do not drive the Mac full-profile cursor.
assert(select(1,elevation_marker(p.values,1000000,1000000))==1)
assert(select(1,elevation_marker(p.values,-1,1000000))==0)
assert(select(1,elevation_marker(p.values,2000000,1000000))==1)
local flat=prepare_elevation({{elevation_m=4},{elevation_m=4}})
assert(flat.raw.points[1].y==0 and flat.raw.points[2].y==0)
assert(#prepare_elevation({{}}).values==0)
for _,band in ipairs(p.smooth.bands) do for _,point in ipairs(band) do assert(point.x>=0 and point.x<=1 and point.y>=0 and point.y<=1) end end
`));

test('elevation chart renders gradient bands, profile, cursor and explicit missing-data states', () => run(HOST + `
local base_capsule=capsule
capsule=function(...) local s=base_capsule(...);function s:OutlineOfShape() return self end;return s end
Shape=function() local s={points={},rects={},TransformOfShape=function(self) return self end}
 function s:MoveTo(x,y) table.insert(self.points,{x,y}) end
 function s:LineTo(x,y) table.insert(self.points,{x,y}) end
 function s:Close() end
 function s:AddRectangle(...) table.insert(self.rects,{...}) end
 function s:OutlineOfShape(w) self.width=w;return self end
 return s end
local profile=prepare_elevation({{elevation_m=0},{elevation_m=20},{elevation_m=10}})
load_data=function() return {elevation=profile,duration_us=1000000} end
local current=10
sample_activity=function() return {elevation_m=current} end
inputs.Metric.value=ELEVATION_METRIC;inputs.ShadowEnabled.value=0
Process(req)
local shapes=of('shape');assert(#shapes>3 and #of('text')==0)
assert(shapes[1].color.A<0.34 and shapes[1].color.B>shapes[1].color.R)
assert(shapes[#shapes-1].shape.kind=='capsule')
inputs.ElevationFill.value=0;events={};Process(req);assert(#of('shape')==3)
current=nil;events={};Process(req);assert(#of('shape')==1)
inputs.ElevationShowValue.value=1;events={};Process(req);assert(of('text')[1].text=='-- m')
profile=prepare_elevation({{}});events={};Process(req);assert(of('text')[1].text=='NO ELEVATION')
inputs.HeartRateEnabled.value=0;inputs.Widget16Enabled.value=1;inputs.Widget16Metric.value=ELEVATION_METRIC
inputs.Widget16ShadowEnabled.value=0;events={};Process(req);assert(of('text')[1].text=='NO ELEVATION')
NotifyChanged(inputs.Widget16Metric,{Value=ELEVATION_METRIC})
assert(inputs.Widget16ElevationWidth.visible==true and inputs.Widget16ZoneLength.visible==false and inputs.Widget16ValueSize.visible==false)
NotifyChanged(inputs.Widget16Metric,{Value=ZONE_METRIC})
assert(inputs.Widget16ElevationWidth.visible==false and inputs.Widget16ZoneLength.visible==true)
`));

test('long elevation geometry is bounded while retaining endpoints and peaks', () => run(`
local values={} for i=1,10000 do values[i]=0 end
values[4999]=100
local points=elevation_points(values,false)
assert(#points<=512 and points[1].x==0 and points[#points].x==1)
local peak=false for _,p in ipairs(points) do if p.y==1 then peak=true end end
assert(peak)
assert(#elevation_points(values,true)<=3067)
`));

test('weather card renders cached conditions, temperature units, placeholders and FIT override', () => run(HOST + `
local base_capsule=capsule
capsule=function(...) local shape=base_capsule(...); function shape:OutlineOfShape() return self end; return shape end
local icons={}
icon_shapes=function(name,left,top,size) table.insert(icons,{name=name,left=left,top=top,size=size}); return {} end
local cached={condition='rain',temperatureC=20,humidity=68,location='Toronto',weekday='Thursday',highC=23,lowC=19,windKph=9.5,feelsLikeC=18}
load_data=function() return {timeline_start_frame=0,pauses={},start_utc_us=0,weather=cached} end
sample_activity=function() return {temperature_c=5} end
inputs.Metric.value=WEATHER_METRIC;inputs.ShadowEnabled.value=0
Process(req)
local texts={} for _,t in ipairs(of('text')) do texts[t.text]=t end
assert(texts['Rain'] and texts['Toronto'] and texts['Thursday'] and texts['20\\194\\176'] and texts['68% RH'])
assert(#icons==1 and icons[1].name=='Rain')
local shapes=of('shape')
-- 16 gradient bands, a border and a divider precede the icon silhouette.
assert(#shapes==18 and near(shapes[1].color.A, 0.92) and shapes[1].color.B>shapes[1].color.R)
assert(shapes[#shapes].shape.kind=='capsule' or type(shapes[#shapes].shape)=='table')
-- Fahrenheit conversion is rounded from Celsius.
inputs.WeatherUnits.value=1;events={};Process(req)
texts={} for _,t in ipairs(of('text')) do texts[t.text]=t end
assert(texts['68\\194\\176'])
-- The optional FIT reading replaces the cached value only when present.
inputs.WeatherUnits.value=0;inputs.WeatherFitOverride.value=1;events={};Process(req)
texts={} for _,t in ipairs(of('text')) do texts[t.text]=t end
assert(texts['5\\194\\176'])
sample_activity=function() return {} end;events={};Process(req)
texts={} for _,t in ipairs(of('text')) do texts[t.text]=t end
assert(texts['20\\194\\176'])
-- Without a cache the card keeps placeholders and never invents weather values.
cached=nil;icons={};events={};Process(req)
texts={} for _,t in ipairs(of('text')) do texts[t.text]=t end
local count=0 for _ in pairs(texts) do count=count+1 end
assert(texts['Sunny'] and texts['--'] and texts['-- RH'] and count==3)
assert(#icons==1 and icons[1].name=='Sunny')
-- Hidden content rows drop out of the card.
cached={condition='clearNight',temperatureC=2,humidity=nil,location='Ottawa',weekday='Friday'}
inputs.WeatherShowLocation.value=0;inputs.WeatherShowWeekday.value=0;inputs.WeatherShowHumidity.value=0;icons={};events={};Process(req)
local rows=of('text')
assert(#rows==2 and rows[1].text=='Clear night' and rows[2].text=='2\\194\\176' and icons[1].name=='Clear night')
-- Every weather group toggles with the metric, including slot 16.
inputs.HeartRateEnabled.value=0
inputs.Widget16Enabled.value=1;inputs.Widget16Metric.value=WEATHER_METRIC;inputs.Widget16ShadowEnabled.value=0
NotifyChanged(inputs.Widget16Metric,{Value=WEATHER_METRIC})
assert(inputs.Widget16WeatherWidth.visible==true and inputs.Widget16ElevationWidth.visible==false and inputs.Widget16ValueSize.visible==false)
events={};Process(req)
assert(#of('text')==5)
`));

test('weather metadata survives the activity TSV round trip', () => {
  const { serializeActivityRenderData, parseWeatherRenderData } = require('../src/io/render-data');
  const activity = { schemaVersion: 1, activityId: 'weather-round-trip', startUtcUs: 1_783_016_700_000_000,
    endUtcUs: 1_783_019_700_000_000, records: [{ elapsedUs: 0 }], annotations: [] };
  const text = serializeActivityRenderData(activity, { condition: 'snow', temperatureC: -3.5, humidity: 80, highC: 0, lowC: -6,
    windKph: 12, feelsLikeC: -8, location: 'Oslo', weekday: 'Thursday', sourceUtcUs: activity.startUtcUs });
  assert.deepEqual(parseWeatherRenderData(text), { condition: 'snow', temperatureC: -3.5, humidity: 80, highC: 0, lowC: -6,
    windKph: 12, feelsLikeC: -8, location: 'Oslo', weekday: 'Thursday', sourceUtcUs: activity.startUtcUs });
  assert.equal(parseWeatherRenderData(serializeActivityRenderData(activity)), null);
  const lines = JSON.stringify(text);
  run(`
    local content = ${lines}
    local lines = {}
    for line in (content .. "\\n"):gmatch("([^\\n]*)\\n") do table.insert(lines, line) end
    local index = 0
    io = {open = function()
      local file = {}
      function file:read() index = index + 1; return lines[index] end
      function file:lines() return function() index = index + 1; return lines[index] end end
      function file:close() end
      return file
    end}
    local records, _, start, err, weather = read_activity('synthetic.roactivity')
    assert(records and weather, err)
    assert(weather.condition == 'snow' and weather.temperatureC == -3.5 and weather.humidity == 80)
    assert(weather.highC == 0 and weather.lowC == -6 and weather.windKph == 12 and weather.feelsLikeC == -8)
    assert(weather.location == 'Oslo' and weather.weekday == 'Thursday' and weather.sourceUtcUs == 1783016700000000)
  `);
});

test('Date and Custom Numeric use the activity instant and existing record fields', () => run(`
local data = {start_utc_us = 1767254400000000}
local sample = {distance_m = 1609.344, heart_rate = 148, pace_spk = 300, cadence = 174, elevation_m = 100,
  power_w = 251, calories = 320, oscillation_mm = 88, contact_ms = 252, stride_m = 1.06, balance_left = 49.6,
  temperature_c = 12, grade_pct = 1.5, latitude_deg = 43.653226, longitude_deg = -79.383184}
local label, value, unit = metric_text(DATE_METRIC, sample, 0, data, 0)
assert(label == 'DATE' and value == '2026-01-01' and unit == '')
for mode, expected in ipairs({'2026/01/01', '01/01/2026', '01-01', '01/01', 'Jan 1'}) do
  _, value = metric_text(DATE_METRIC, sample, 0, data, mode)
  assert(value == expected, mode .. ' ' .. value)
end
_, value = metric_text(DATE_METRIC, sample, 16 * 3600000000, data, 0)
assert(value == '2026-01-02')
_, value = metric_text(DATE_METRIC, sample, 16 * 3600000000, data, 0, nil, nil, -8)
assert(value == '2026-01-01')
_, value = metric_text(DATE_METRIC, sample, 0, {}, 0)
assert(value == '--')
-- Distance, heart rate, pace, precision, custom unit and formats.
_, value, unit = metric_text(CUSTOM_METRIC, sample, 0, data, 0, nil, nil, 0, 2, 0, 2)
assert(value == '1609.34' and unit == 'm')
_, value, unit = metric_text(CUSTOM_METRIC, sample, 0, data, 0, nil, nil, 0, 3, 1, 2)
assert(value == '148' and unit == 'bpm')
_, value, unit = metric_text(CUSTOM_METRIC, sample, 0, data, 0, nil, nil, 0, 4, 5, 2)
assert(value == [[5'00"]] and unit == '/km')
_, value, unit = metric_text(CUSTOM_METRIC, sample, 600000000, data, 0, nil, nil, 0, 5, 5, 0)
assert(value == [[6'13"]] and unit == '/km')
_, value, unit = metric_text(CUSTOM_METRIC, sample, 0, data, 0, nil, nil, 0, 15, 6, 1)
assert(value == '8.3' and unit == '%')
_, value, unit = metric_text(CUSTOM_METRIC, sample, 0, data, 0, nil, nil, 0, 1, 2, 0)
assert(value == '00:00:00' and unit == '')
_, value, unit = metric_text(CUSTOM_METRIC, sample, 125000000, data, 0, nil, nil, 0, 1, 2, 0)
assert(value == '00:02:05')
_, value, unit = metric_text(CUSTOM_METRIC, sample, 0, data, 0, nil, nil, 0, 10, 7, 4)
assert(value == '43.6532' and unit == '')
_, value, unit = metric_text(CUSTOM_METRIC, sample, 0, data, 0, nil, nil, 0, 2, 0, 2, 'metres')
assert(value == '1609.34' and unit == 'metres')
_, value, unit = metric_text(CUSTOM_METRIC, {}, 0, data, 0, nil, nil, 0, 3, 1, 2)
assert(value == '--' and unit == 'bpm')
_, value, unit = metric_text(CUSTOM_METRIC, sample, 0, data, 0, nil, nil, 0, 0, 4, 0)
assert(value == '2026-01-01')
_, value, unit = metric_text(CUSTOM_METRIC, sample, 0, data, 0, nil, nil, 8, 1, 3, 0, '')
assert(value == '16:00:00')
`));
