---@meta
-- Type definitions for the parts of Cyber Engine Tweaks' Lua API and the game's script API that
-- our CET mods use. Hand-written and minimal: add what a mod needs. Read by lua-language-server.

---@class Vector4
---@field x number
---@field y number
---@field z number
---@field w number

---@class EntityID

---@class PlayerPuppet
local PlayerPuppet = {}
---@return Vector4
function PlayerPuppet:GetWorldPosition() end
---@return Vector4
function PlayerPuppet:GetVelocity() end
---@return number
function PlayerPuppet:GetWorldYaw() end
---@return boolean
function PlayerPuppet:IsAttached() end
---@return EntityID
function PlayerPuppet:GetEntityID() end

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

---@return AllBlackboardDefinitions
function GetAllBlackboardDefs() end

---@alias CetEvent "onInit" | "onUpdate" | "onDraw" | "onOverlayOpen" | "onOverlayClose" | "onShutdown"

---@param event CetEvent
---@param callback fun(delta?: number)
function registerForEvent(event, callback) end
