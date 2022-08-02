// Lander direct descent system, for safe(!) landings
// Two phase landing system, braking burn attempts to slow the craft to targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

// Setup functions
runpath("/flight/enginemgmt", Stage:Number).
runpath("/flight/tunesteering").

if Ship:Status = "Flying" or Ship:Status = "Sub_Orbital" or Ship:Status = "Escaping"
{
    print "Martian descent system online.".

	local debugGui is GUI(400, 80).
    set debugGui:X to 160.
    set debugGui:Y to debugGui:Y + 240.
    local mainBox is debugGui:AddVBox().

    local debugStat is mainBox:AddLabel("Awaiting atmospheric interface").
	debugGui:Show().
    
    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.

    wait until Ship:Altitude < Ship:Body:Atm:Height.
	set Ship:Type to "Lander".

	set navmode to "surface".
    
    set debugStat:Text to "Waiting for dynamic pressure".
    
    wait until Ship:Q > 1e-6.
   
    // Switch on all tanks
    for p in Ship:Parts
    {
        for r in p:resources
        {
            set r:enabled to true.
        }
    }
    
    for a in Ship:ModulesNamed("ModuleProceduralAvionics")
    {
        if a:HasEvent("activate avionics")
            a:DoEvent("activate avionics").
    }

    if Ship:ModulesNamed("ProceduralFairingDecoupler"):Empty
    {
        set debugStat:Text to "Aligning retrograde".
        
        for rc in Ship:ModulesNamed("RealChuteModule")
        {
            if rc:HasEvent("disarm chute")
            {
                rc:DoEvent("disarm chute").
                set chutesArmed to true.
            }
        }

        rcs on.
        lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).

        wait until vdot(SrfRetrograde:Vector, Facing:Vector) > 0.9995 or Ship:Altitude < 50000.
        wait 1.

        unlock steering.
        set Ship:Control:Neutralize to true.
        rcs off.
    }
    else
    {
        set debugStat:Text to "Waiting for aeroshell deployment".

        wait until Ship:Airspeed <= 1000.
        
        for fairing in Ship:ModulesNamed("ProceduralFairingDecoupler")
        {
            if fairing:HasEvent("jettison fairing")
                fairing:DoEvent("jettison fairing").
        }
    }

    set debugStat:Text to "Waiting for chute altitude".

    wait until Ship:Altitude - Ship:GeoPosition:TerrainHeight < 15000.

    local chutesArmed is false.
    for rc in Ship:ModulesNamed("RealChuteModule")
    {
        if rc:HasEvent("arm parachute")
        {
            rc:DoEvent("arm parachute").
            set chutesArmed to true.
        }
        else if rc:HasEvent("deploy chute")
        {
            rc:DoEvent("deploy chute").
            set chutesArmed to true.
        }
    }

    if not chutesArmed
        chutes on.

    local curSpeed is Ship:Velocity:Surface:Mag.
    local curTime is Time:Seconds.
    local curAccel is -10.

    until curAccel > -4
    {
        wait 0.05.
        set curAccel to (Ship:Velocity:Surface:Mag - curSpeed) / (Time:Seconds - curTime).
        set curSpeed to Ship:Velocity:Surface:Mag.
        set curTime to Time:Seconds.

        set debugStat:Text to "Acceleration: " + round(curAccel, 2) + " m/s²".
    }
        
    // Drop all payload bases and heatshields
    for hs in Ship:ModulesNamed("ModuleDecouple")
    {
        if hs:HasEvent("decouple")
            hs:DoEvent("decouple").
        else if hs:HasEvent("decouple top node")
            hs:DoEvent("decouple top node").
        else if hs:HasEvent("decoupler staging")
            hs:DoEvent("decoupler staging").
    }
    for hs in Ship:ModulesNamed("ModuleAnchoredDecoupler")
    {
        if hs:HasEvent("decouple")
            hs:DoEvent("decouple").
        else if hs:HasEvent("decouple top node")
            hs:DoEvent("decouple top node").
        else if hs:HasEvent("decoupler staging")
            hs:DoEvent("decoupler staging").
    }
    wait 0.
    for hs in Ship:ModulesNamed("ModuleDecouple")
    {
        if hs:HasEvent("jettison heat shield")
        {
            hs:DoEvent("jettison heat shield").
        }
    }
    
    until stage:number = 0
    {
        wait until stage:ready.
        stage.
    }
    
    wait 0.1.
    
    rcs on.
    local DescentEngines is list().
	list engines in DescentEngines.

    runpath("/lander/finaldescent", DescentEngines, debugStat, 0).
}
