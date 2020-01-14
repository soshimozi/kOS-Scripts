@lazyglobal off.
global lock LAS_ShipPos to-Ship:Body:Position.
global function LAS_EngineIsUllage
{
parameter _p0.
return _p0:Title:Contains("Separation")or _p0:Title:Contains("Spin")or _p0:Tag:Contains("ullage").
}
global function LAS_GetStageEngines
{
parameter _p0 is Stage:Number.
parameter _p1 is false.
local _0 is list().
list engines in _0.
if Ship:Status="PreLaunch"
set _p0 to min(_p0,Stage:Number-1).
local _1 is list().
for e in _0
{
if e:Stage=_p0 and LAS_EngineIsUllage(e)=_p1
{
_1:Add(e).
}
}
return _1.
}
global function LAS_Avionics
{
parameter _p0.
set _p0 to _p0+" avionics".
for avionics in Ship:ModulesNamed("ModuleProceduralAvionics")
{
if avionics:HasEvent(_p0)
{
avionics:DoEvent(_p0).
}
}
if _p0:contains("shutdown")
set core:bootfilename to"".
}