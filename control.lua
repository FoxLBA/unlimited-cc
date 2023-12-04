require "util"
local BigConstant = require "scripst.unlimited-cc"
local SignalStorage = require "scripst.SignalStorage"

local function dolly_moved_entity(event)
  local entity = event.moved_entity ---@type LuaEntity
  local comb = global.combinators[entity.unit_number]
  local pos = entity.position
  if comb then
    for _, store in pairs({"store", "off_store"}) do
      for _, s in pairs(comb[store]) do
        s.behavior.entity.teleport(pos)
      end
    end
  end
  if (entity.name == "entity-ghost") and (entity.ghost_name == "ucc-constant-combinator") then
    local sp = event.start_pos
    local configs = entity.surface.find_entities_filtered{
      area = {{sp.x - 0.1, sp.y - 0.1}, {sp.x + 0.1, sp.y + 0.1}},
      ghost_name = "ucc-config-storage",
      force = entity.force,
    }
    for _, ce in pairs(configs) do
      ce.teleport(pos)
    end
  end
end

local function register_events()
  if remote.interfaces["PickerDollies"] and remote.interfaces["PickerDollies"]["dolly_moved_entity_id"] then
    script.on_event(remote.call("PickerDollies", "dolly_moved_entity_id"), dolly_moved_entity)
  end
end

local function on_init()
  global.combinators = {} ---@type SignalStorage[]
  global.c_ghosts = {}
  BigConstant.cache_signals()
  register_events()
end

local function on_load()
  register_events()
  for _, comb in pairs(global.combinators) do
    setmetatable(comb, SignalStorage)
  end
end

local function on_mods_changed(event)
  BigConstant.cache_signals()

  --Close ucc GUIs for all players
  for _, player in pairs(game.players) do
    if player.opened
    and player.opened.object_name == "LuaGuiElement"
    and player.opened.name == "ucc-constant-combinator" then
      BigConstant.destroy_gui(player.opened)
    end
  end

  for _, comb in pairs(global.combinators) do
    comb:check_signals()
  end
end

local function on_built(event)
  local entity = event.created_entity or event.entity or event.destination
  if not entity or not entity.valid then return end
  if entity.name == "entity-ghost" then
    BigConstant.on_ghost_build(entity, event)
  else
    BigConstant.on_build(entity, event)
  end
end

local function on_gui_closed(event)
  if event.gui_type == defines.gui_type.custom
  and event.element
  and event.element.valid
  and event.element.name == "ucc-constant-combinator"
  then
    BigConstant.destroy_gui(event.element)
  end
end

---@diagnostic disable: param-type-mismatch
script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_mods_changed)

script.on_event(defines.events.on_gui_opened, BigConstant.on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
script.on_event(defines.events.on_gui_click, BigConstant.on_gui_click)
script.on_event(defines.events.on_gui_text_changed, BigConstant.on_gui_text_changed)
script.on_event(defines.events.on_gui_value_changed, BigConstant.on_gui_value_changed)
script.on_event(defines.events.on_gui_switch_state_changed, BigConstant.on_gui_switch_state_changed)
script.on_event(defines.events.on_entity_settings_pasted, BigConstant.on_entity_settings_pasted)

script.on_event(defines.events.on_entity_destroyed, BigConstant.on_destroyed)
---@diagnostic disable: assign-type-mismatch
script.on_event({
  defines.events.on_built_entity,
  defines.events.on_entity_cloned,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}, on_built)
