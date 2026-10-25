---@meta
-- Type definitions for the parts of Cyber Engine Tweaks' Lua API and the game's script API that
-- our CET mods use. Hand-written and minimal: add what a mod needs. Read by lua-language-server.

---@class Vector4
---@field x number
---@field y number
---@field z number
---@field w number
Vector4 = {}
---@param x number
---@param y number
---@param z number
---@param w number
---@return Vector4
function Vector4.new(x, y, z, w) end

---@class Quaternion
---@field i number
---@field j number
---@field k number
---@field r number
Quaternion = {}
---@param i number
---@param j number
---@param k number
---@param r number
---@return Quaternion
function Quaternion.new(i, j, k, r) end

---@class SoundPlayEvent
---@field soundName string
SoundPlayEvent = {}
---@return SoundPlayEvent
function SoundPlayEvent.new() end

---@class PSMImpulse
---@field id string
---@field impulse Vector4
PSMImpulse = {}
---@return PSMImpulse
function PSMImpulse.new() end

---@class TraceResult
---@field position Vector4
---@field normal Vector4

---@class SpatialQueriesSystem
local SpatialQueriesSystem = {}
---@param from Vector4
---@param to Vector4
---@param group string collision group, e.g. "Static"
---@param static boolean static objects only
---@param dynamic boolean dynamic objects only
---@return boolean hit, TraceResult result
function SpatialQueriesSystem:SyncRaycastByCollisionGroup(from, to, group, static, dynamic) end

---@class EntityID

---@class PlayerPuppet
local PlayerPuppet = {}
---@return Vector4
function PlayerPuppet:GetWorldPosition() end
---@return Vector4
function PlayerPuppet:GetVelocity() end
---@return Vector4
function PlayerPuppet:GetWorldForward() end
---@param event PSMImpulse | SoundPlayEvent
function PlayerPuppet:QueueEvent(event) end
---@return number
function PlayerPuppet:GetWorldYaw() end
---@return boolean
function PlayerPuppet:IsAttached() end
---@return EntityID
function PlayerPuppet:GetEntityID() end
---@return FPPCameraComponent
function PlayerPuppet:GetFPPCameraComponent() end
---@param listener PlayerPuppet
function PlayerPuppet:RegisterInputListener(listener) end

---@class CName

---@class ListenerAction
local ListenerAction = {}
---@return CName
function ListenerAction:GetName() end
---@return number
function ListenerAction:GetValue() end
---@return InputActionType
function ListenerAction:GetType() end

---@class InputActionType
-- gameinputActionType values
---@type { BUTTON_PRESSED: InputActionType, BUTTON_RELEASED: InputActionType }
gameinputActionType = {}

---@class FPPCameraComponent
local FPPCameraComponent = {}
---@return Vector4
function FPPCameraComponent:GetLocalPosition() end
---@param rot Quaternion
function FPPCameraComponent:SetLocalOrientation(rot) end
---@param pos Vector4
function FPPCameraComponent:SetLocalPosition(pos) end

---@class CameraSystem
local CameraSystem = {}
---@return Vector4
function CameraSystem:GetActiveCameraForward() end
---@return Vector4
function CameraSystem:GetActiveCameraRight() end
---@return number
function CameraSystem:GetActiveCameraFOV() end
-- Out parameter in the game: depending on CET's handling it returns the transform or fills one.
---@param transform? Transform
---@return any, any
function CameraSystem:GetActiveCameraWorldTransform(transform) end

---@class Transform
---@field position Vector4
Transform = {}
---@return Transform
function Transform.new() end

---@class BlackboardID_Int

---@class IBlackboard
local IBlackboard = {}
---@param id BlackboardID_Int
---@return integer
function IBlackboard:GetInt(id) end
---@param id BlackboardID_Variant
---@param value Variant
---@param force boolean
function IBlackboard:SetVariant(id, value, force) end

---@class PlayerStateMachineDef
---@field Locomotion BlackboardID_Int
---@field HighLevel BlackboardID_Int

---@class BlackboardID_Variant

---@class UINotificationsDef
---@field OnscreenMessage BlackboardID_Variant

---@class AllBlackboardDefinitions
---@field PlayerStateMachine PlayerStateMachineDef
---@field UI_Notifications UINotificationsDef

---@class Variant

---@param value any
---@return Variant
function ToVariant(value) end

---@class SimpleScreenMessage
---@field isShown boolean
---@field duration number
---@field message string
SimpleScreenMessage = {}
---@return SimpleScreenMessage
function SimpleScreenMessage.new() end

---@class BlackboardSystem
local BlackboardSystem = {}
---@param entity EntityID
---@param definition PlayerStateMachineDef
---@return IBlackboard
function BlackboardSystem:GetLocalInstanced(entity, definition) end
---@param definition UINotificationsDef
---@return IBlackboard
function BlackboardSystem:Get(definition) end

---@class Game
Game = {}
---@return PlayerPuppet?
function Game.GetPlayer() end
---@return BlackboardSystem
function Game.GetBlackboardSystem() end
---@return CameraSystem
function Game.GetCameraSystem() end
---@return SpatialQueriesSystem
function Game.GetSpatialQueriesSystem() end
---@return StatsSystem
function Game.GetStatsSystem() end
---@param name CName
---@return string
function Game.NameToString(name) end

---@class StatType

-- gamedataStatType values (the game enum; CET exposes it as a table)
---@type { MaxSpeed: StatType, Acceleration: StatType, Deceleration: StatType }
gamedataStatType = {}

---@class StatModifierType
-- gameStatModifierType values
---@type { Additive: StatModifierType, Multiplier: StatModifierType }
gameStatModifierType = {}

---@class gameStatModifierData

RPGManager = {}
---@param stat StatType
---@param kind StatModifierType
---@param value number
---@return gameStatModifierData
function RPGManager.CreateStatModifier(stat, kind, value) end

-- Takes a StatsObjectID in the game; CET converts an EntityID.
---@class StatsSystem
local StatsSystem = {}
---@param id EntityID
---@param stat StatType
---@return number
function StatsSystem:GetStatValue(id, stat) end
---@param id EntityID
---@param modifier gameStatModifierData
---@return boolean
function StatsSystem:AddModifier(id, modifier) end
---@param id EntityID
---@param modifier gameStatModifierData
---@return boolean
function StatsSystem:RemoveModifier(id, modifier) end

---@return AllBlackboardDefinitions
function GetAllBlackboardDefs() end

---@alias CetEvent "onInit" | "onUpdate" | "onDraw" | "onOverlayOpen" | "onOverlayClose" | "onShutdown"

---@param event CetEvent
---@param callback fun(delta?: number)
function registerForEvent(event, callback) end

---@param id string
---@param label string
---@param callback fun()
function registerHotkey(id, label, callback) end

---@param id string
---@param label string
---@param callback fun(down: boolean)
function registerInput(id, label, callback) end

---@param name string
---@return any
function GetMod(name) end

-- Runs callback(self, ...args) after the game calls class.method.
---@param class string
---@param method string
---@param callback fun(self: any, ...: any)
function Observe(class, method, callback) end

-- CET's Dear ImGui bindings (only what our mods use).
ImGui = {}
---@param name string
---@return boolean visible
function ImGui.Begin(name) end
function ImGui.End() end
---@param label string
---@param value number
---@param min number
---@param max number
---@param format? string
---@return number value, boolean changed
function ImGui.SliderFloat(label, value, min, max, format) end
---@param label string
---@return boolean open
function ImGui.CollapsingHeader(label) end
---@param label string
---@return boolean pressed
function ImGui.Button(label) end

---@class TweakDBClass
local TweakDBClass = {}
---@param path string
---@return any
function TweakDBClass:GetFlat(path) end
---@param path string
---@param value any
---@return boolean
function TweakDBClass:SetFlat(path, value) end
---@type TweakDBClass
TweakDB = {}
