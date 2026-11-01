'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
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
 local input={value=attrs.INP_DefaultText or attrs.INP_Default or ''}
 if attrs.LINKID_DataType=='Point' then input.value={X=attrs.INP_DefaultX,Y=attrs.INP_DefaultY} end
 function input:GetValue() if type(self.value)=='table' then return self.value end; return {Value=self.value} end
 function input:SetSource(source) self.value=source.Value end
 inputs[key]=input; return input
end}
Create()
assert(inputs.Widget16UnitPosition.value==3)
assert(inputs.Widget16LabelSize and inputs.Widget16ElevationUnits and inputs.Widget16LabelA)
Width=1920; Height=1080; Scale=1; XAspect=1; YAspect=1; SourceDepth=0
Image=function(attrs) return {Height=1080,Width=1920,XScale=1,YScale=1,Fill=function() end} end
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
