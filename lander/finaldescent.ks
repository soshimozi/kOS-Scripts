@lazyglobal off.

parameter DescentEngines.
parameter Readouts.
parameter targetPos.
parameter canAbort is false.

local enginesOn is Ship:Control:PilotMainThrottle > 0.
local needUllage is false.
local multiIgnition is true.

for eng in DescentEngines
{
    if not eng:Ignition
        set enginesOn to false.
    if eng:ullage
        set needUllage to true.
    if eng:Ignitions >= 0 and eng:Ignitions < 10
        set multiIgnition to false.
}

if needUllage
    set multiIgnition to false.

runoncepath("/lander/landerthrottle", DescentEngines, enginesOn).
if needUllage
    runpath("/flight/enginemgmt", Stage:Number).
    
local burnThrust is LanderMaxThrust().

print "Descent mode active".

set Ship:Type to "Lander".
local steerVec is SrfRetrograde:Vector.
lock steering to LookDirUp(steerVec, Facing:UpVector).

local shipBounds is Ship:Bounds.

// Touchdown speed
local vT is 0.8.
local abortMode is false.
local engFailTime is 0.
local radarHeight is shipBounds:BottomAltRadar.
local killThrott is false.
local cutThrott is 0.75.
local ignThrottle is 0.9 - DescentEngines:Length * 0.0125.

if LanderMinThrottle() < 0.9
{
    set cutThrott to LanderMinThrottle().
    set ignThrottle to 0.6 + LanderMinThrottle() * 0.4.
}

until radarHeight < 2
{
    // Prevent too much tip over in final descent
    set steerVec to Up:Vector * max(0, 2 * (0.8 - vdot(SrfRetrograde:Vector, Up:Vector))) + SrfRetrograde:Vector.

    local maxAccel is burnThrust / Ship:Mass.
    local localGrav is Ship:Body:Mu / LAS_ShipPos():SqrMagnitude.

    // Use minimal height directly below and projected forwards
    set radarHeight to shipBounds:BottomAltRadar.
    local h is min(radarHeight, Ship:Altitude - Body:GeopositionOf(SrfPrograde:Vector * radarHeight):TerrainHeight) - 1.
    set h to max(h, 0.1).

    // Commanded vertical acceleration is accel needed to reach vT in the height available
    local acgx is -(vT^2 - Ship:VerticalSpeed^2) / (2 * h).
    local fr is (acgx + localGrav) / maxAccel.

    if fr > ignThrottle * 0.8
        set killThrott to false.
    else if Ship:VerticalSpeed > -(vT * (vdot(SrfRetrograde:Vector, Up:Vector) + 0.5))
        set killThrott to true.
    if killThrott
        set fr to 0.

    local f is fr / vdot(Facing:Vector, Up:Vector).
    local reqThrottle is max(0, min(f, 1)).
    if not enginesOn and reqThrottle >= ignThrottle and vdot(Facing:Vector, SrfRetrograde:Vector) > 0.8 and (Ship:VerticalSpeed < -10 or h < 50)
    {
        if needUllage
            EM_Ignition().
        LanderEnginesOn().
        set enginesOn to true.
    }
    else if multiIgnition and enginesOn and reqThrottle < cutThrott
    {
        LanderEnginesOff().
        set enginesOn to false.
    }
    LanderSetThrottle(reqThrottle).

    ReadoutGUI_SetText(Readouts:height, round(h, 1) + " m", ReadoutGUI_ColourNormal).
    ReadoutGUI_SetText(Readouts:acgx, round(acgx, 3), ReadoutGUI_ColourNormal).
    ReadoutGUI_SetText(Readouts:fr, round(fr, 3), ReadoutGUI_ColourNormal).
    
    if targetPos:IsType("GeoCoordinates")
    {
        local wpBearing is vang(vxcl(up:vector, TargetPos:Position), vxcl(up:vector, Ship:Velocity:Surface)).
        ReadoutGUI_SetText(Readouts:dist, round(targetPos:Distance) + " m", ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(Readouts:bearing, round(wpBearing, 3) + "°", ReadoutGUI_ColourNormal).
    }

    if Readouts:HasKey("fuel")
    {
        local fuelStatus is CurrentFuelStatus(DescentEngines).
        ReadoutGUI_SetText(Readouts:Δv, round(fuelStatus[1], 1) + " m/s", ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(Readouts:margin, round(fuelStatus[1]  - Ship:Velocity:Surface:Mag, 3) + " m/s", ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(Readouts:fuel, round(fuelStatus[0] * 100, 1) + "%", ReadoutGUI_ColourGood).
    }
    
    ReadoutGUI_SetText(Readouts:throt, round(100 * reqThrottle, 1) + "%", ReadoutGUI_ColourNormal).

    local nomThrust is Ship:AvailableThrust * (LanderMinThrottle() + Ship:Control:PilotMainThrottle * (1 - LanderMinThrottle())).
    ReadoutGUI_SetText(Readouts:thrust, round(100 * min(Ship:Thrust / max(Ship:AvailableThrust, 0.001), 2), 2) + "%", 
        choose ReadoutGUI_ColourGood if Ship:Thrust > nomThrust * 0.75 else (choose ReadoutGUI_ColourNormal if Ship:Thrust > nomThrust * 0.25 else ReadoutGUI_ColourFault)).

    if canAbort and Ship:VerticalSpeed < -8
    {
        if enginesOn and Ship:Thrust < nomThrust * 0.25
        {
            if Time:Seconds - engFailTime > 1
            {
                set abortMode to true.
                print "Detected engine failure, aborting!".
                break.
            }
        }
        else
        {
            set engFailTime to Time:Seconds.
        }
    }

    if not legs and radarHeight <= 100
    {
        legs on.
        gear on.
        brakes on.
        local checkBounds is time:seconds + 3.
        when checkBounds >= time:seconds then
        {
            set shipBounds to Ship:Bounds.
        }
    }

    wait 0.
}

if not abortMode
{
    lock steering to LookDirUp(Up:Vector, Facing:UpVector).
    set shipBounds to Ship:Bounds.

    until Ship:Status = "Landed" or Ship:Status = "Splashed"
    {
        LanderSetThrottle(-vT - Ship:VerticalSpeed).
        
        ReadoutGUI_SetText(Readouts:throt, round(100 * (-vT - Ship:VerticalSpeed), 1) + "%", ReadoutGUI_ColourNormal).
        
        ReadoutGUI_SetText(Readouts:height, round(shipBounds:BottomAltRadar, 1) + " m", ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(Readouts:fr, round(-vT - Ship:VerticalSpeed, 3), ReadoutGUI_ColourNormal).
        
        if targetPos:IsType("GeoCoordinates")
            ReadoutGUI_SetText(Readouts:dist, round(targetPos:Distance) + " m", ReadoutGUI_ColourNormal).

        wait 0.
    }

    print "Touchdown speed: " + round(-Ship:VerticalSpeed, 2) + " m/s".
    if targetPos:IsType("GeoCoordinates")
    {
        if targetPos:Distance >= 1000
            print "Waypoint distance: " + round((targetPos:Position - Ship:GeoPosition:Position):Mag * 0.001, 2) + " km".
        else
            print "Waypoint distance: " + round((targetPos:Position - Ship:GeoPosition:Position):Mag, 1) + " m".
    }

    set Ship:Control:PilotMainThrottle to 0.
    LanderEnginesOff().

    local starVec is Body:GeoPositionOf(shipBounds:Extents:Mag * Facing:StarVector):Position - Body:GeoPositionOf(-shipBounds:Extents:Mag * Facing:StarVector):Position.
    local foreVec is Body:GeoPositionOf(shipBounds:Extents:Mag * Facing:ForeVector):Position - Body:GeoPositionOf(-shipBounds:Extents:Mag * Facing:ForeVector):Position.
    local slopeVec is vcrs(foreVec, starVec):Normalized.
    if vdot(slopeVec, Up:Vector) < 0
        set slopeVec to -slopeVec.

    lock steering to LookDirUp(slopeVec, Facing:UpVector).
    wait 0.5.

    // Maintain attitude control until ship settles to prevent roll overs.
    wait until Ship:Velocity:Surface:Mag < 0.1 and Ship:AngularVel:Mag < 0.01.

    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.

    LAS_Avionics("shutdown").
    ClearGUIs().
    
    for panel in Ship:ModulesNamed("ModuleROSolar")
        if panel:HasAction("extend solar panel")
            panel:DoAction("extend solar panel", true).

    for panel in Ship:ModulesNamed("ModuleDeployableSolarPanel")
        if panel:HasAction("extend solar panel")
            panel:DoAction("extend solar panel", true).

    for antenna in Ship:ModulesNamed("ModuleDeployableAntenna")
        if antenna:HasEvent("extend antenna")
            antenna:DoEvent("extend antenna").

    //runpath("/lander/setstability").

    print "Landing completed".
}