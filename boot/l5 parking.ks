@lazyglobal off.

global LAS_TargetPe is 200.
global LAS_TargetAp is 200.

// Calc required inclination
runpath("0:/launch/lunarl4l5launch", false).

runpath("0:/launch/launchascentsystem.ks", -1, 0).
