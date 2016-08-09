/*
 * Author: Dslyecxi, Jonpas, SilentSpike
 * Handles drawing the currently selected or cooked throwable.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call ace_advancedthrowing_fnc_drawThrowable
 *
 * Public: No
 */
#include "script_component.hpp"

if (dialog || {!(ACE_player getVariable [QGVAR(inHand), false])} || {!([ACE_player] call FUNC(canPrepare))}) exitWith {
    [ACE_player, "In dialog or no throwable in hand or cannot prepare throwable"] call FUNC(exitThrowMode);
};

private _throwable = currentThrowable ACE_player;
private _throwableMag = _throwable select 0;
private _primed = ACE_player getVariable [QGVAR(primed), false];
private _activeThrowable = ACE_player getVariable [QGVAR(activeThrowable), objNull];

// Some throwables have different classname for magazine and ammo
// Primed magazine may be different, read speed before checking primed magazine!
private _throwSpeed = getNumber (configFile >> "CfgMagazines" >> _throwableMag >> "initSpeed");

// Reduce power of throw over shoulder and to sides
private _unitDirVisual = getDirVisual ACE_player;
private _cameraDir = getCameraViewDirection ACE_player;
_cameraDir = (_cameraDir select 0) atan2 (_cameraDir select 1);

private _phi = abs (_cameraDir - _unitDirVisual) % 360;
_phi = [_phi, 360 - _phi] select (_phi > 180);

private _power = linearConversion [0, 180, _phi - 30, 1, 0.3, true];
ACE_player setVariable [QGVAR(throwSpeed), _throwSpeed * _power];

#ifdef DEBUG_MODE_FULL
hintSilent format ["Heading: %1\nPower: %2\nSpeed: %3", _phi, _power, _throwSpeed * _power];
#endif

// Handle cooking last throwable in inventory
if (_primed) then {
    _throwableMag = typeOf _activeThrowable;
};

// Inventory check
if (_throwable isEqualTo [] && {!_primed}) exitWith {
    [ACE_player, "No valid throwables"] call FUNC(exitThrowMode);
};

private _throwableType = getText (configFile >> "CfgMagazines" >> _throwableMag >> "ammo");

if (!([ACE_player] call FUNC(canThrow)) && {!_primed}) exitWith {
    if (!isNull _activeThrowable) then {
        deleteVehicle _activeThrowable;
    };
};

if (isNull _activeThrowable || {(_throwableType != typeOf _activeThrowable) && {!_primed}}) then {
    if (!isNull _activeThrowable) then {
        deleteVehicle _activeThrowable;
    };
    _activeThrowable = _throwableType createVehicleLocal [0, 0, 0];
    _activeThrowable enableSimulation false;
    ACE_player setVariable [QGVAR(activeThrowable), _activeThrowable];
};

// Exit in case of explosion in hand
if (isNull _activeThrowable) exitWith {
    [ACE_player, "No active throwable (explosion in hand)"] call FUNC(exitThrowMode);
};

// Set position
private _posHeadRel = ACE_player selectionPosition "head";

private _leanCoef = (_posHeadRel select 0) - 0.15; // 0.15 counters the base offset
// Don't take leaning into account when weapon is lowered due to jiggling when walking side-ways (bandaid)
if (abs _leanCoef < 0.15 || {vehicle ACE_player != ACE_player} || {weaponLowered ACE_player}) then {
    _leanCoef = 0;
};

private _posCameraWorld = positionCameraToWorld [0, 0, 0];
_posHeadRel = _posHeadRel vectorAdd [-0.03, 0.01, 0.15]; // Bring closer to eyePos value
private _posFin = AGLToASL (ACE_player modelToWorldVisual _posHeadRel);

private _throwType = ACE_player getVariable [QGVAR(throwType), THROW_TYPE_DEFAULT];

// Orient it nicely, point towards player
_activeThrowable setDir (_unitDirVisual + 90);

private _pitch = [-30, -90] select (_throwType == "high");
[_activeThrowable, _pitch, 0] call BIS_fnc_setPitchBank;


if (ACE_player getVariable [QGVAR(dropMode), false]) then {
    _posFin = _posFin vectorAdd (positionCameraToWorld [_leanCoef, 0, ACE_player getVariable [QGVAR(dropDistance), DROP_DISTANCE_DEFAULT]]);

    // Even vanilla throwables go through glass, only "GEOM" LOD will stop it but that will also stop it when there is glass in a window
    if (lineIntersects [AGLtoASL _posCameraWorld, _posFin vectorDiff _posCameraWorld]) then {
        ACE_player setVariable [QGVAR(dropDistance), ((ACE_player getVariable [QGVAR(dropDistance), DROP_DISTANCE_DEFAULT]) - 0.1) max DROP_DISTANCE_DEFAULT];
    };
} else {
    private _xAdjustBonus = [0, -0.075] select (_throwType == "high");
    private _yAdjustBonus = [0, 0.1] select (_throwType == "high");
    private _cameraOffset = [_leanCoef, 0, 0.3] vectorAdd [-0.1, -0.15, -0.03] vectorAdd [_xAdjustBonus, _yAdjustBonus, 0];

    _posFin = _posFin vectorAdd (positionCameraToWorld _cameraOffset);

    if (vehicle ACE_player != ACE_player) then {
        // Counteract vehicle velocity including acceleration
        private _vectorDiff = (velocity (vehicle ACE_player)) vectorMultiply (time - (ACE_player getVariable [QGVAR(lastTick), time]) + 0.01);
        _posFin = _posFin vectorAdd _vectorDiff;
        ACE_player setVariable [QGVAR(lastTick), time];
    };
};

_activeThrowable setPosASL (_posFin vectorDiff _posCameraWorld);
