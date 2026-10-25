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
---@param event PSMImpulse
function PlayerPuppet:QueueEvent(event) end
---@return number
function PlayerPuppet:GetWorldYaw() end
---@return boolean
function PlayerPuppet:IsAttached() end
---@return EntityID
function PlayerPuppet:GetEntityID() end
---@return FPPCameraComponent
function PlayerPuppet:GetFPPCameraComponent() end

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

---@class PlayerStateMachineDef
---@field Locomotion BlackboardID_Int
---@field HighLevel BlackboardID_Int

---@class AllBlackboardDefinitions
---@field PlayerStateMachine PlayerStateMachineDef

---@class BlackboardSystem
local BlackboardSystem = {}
---@param entity EntityID
---@param definition PlayerStateMachineDef
---@return IBlackboard
function BlackboardSystem:GetLocalInstanced(entity, definition) end

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
