---@class SignalStorage.Store
---@field space_count table<integer, integer>
---@field behavior LuaConstantCombinatorControlBehavior
---@field u_id integer

---@class SignalStorage.Signal
---@field state boolean
---@field signal Signal
---@field store_pos table|false integer, integer, string

---@class SignalStorage.Signals
---@field item SignalStorage.Signal[]
---@field fluid SignalStorage.Signal[]
---@field virtual SignalStorage.Signal[]

---@class SignalStorage
---@field entity LuaEntity
---@field signals SignalStorage.Signals
---@field store SignalStorage.Store[]
---@field off_store SignalStorage.Store[]
---@field total_space table<integer, integer>
---@field build_tick integer
---@field label_backup table
local SignalStorage = {}
SignalStorage.__index = SignalStorage

---@param entity LuaEntity
---@param event EventData.on_built_entity
---@return SignalStorage
function SignalStorage:new(entity, event)
  --local cccb = entity.get_control_behavior() ---@cast cccb LuaConstantCombinatorControlBehavior
  --local count = cccb.signals_count
  --local store_slot = {space_count = {count, count}, behavior = cccb}
  local obj = {
    entity = entity,
    signals = {item = {}, fluid = {}, virtual = {}}, --[name]{state=boolean, signal={signal=LuaSignal, count=int}, store_pos={int, int, string}}
    store = {}, --[]{space_count = {free, total}, behavior=LuaConstantCombinatorControlBehavior, u_id = int}
    off_store = {},
    total_space = {0, 0}, --used, total
    build_tick = event.tick,
    label_backup = {},
  }
  setmetatable(obj, self)
  if event.tags and event.tags["ucc-settings"] then
    local src_settings = event.tags["ucc-settings"]
    if not src_settings.label_backup then src_settings.label_backup = {} end
    obj:copy_settings(src_settings)
  else
    obj:update_label_backup()
  end
  return obj
end

function SignalStorage:destroy()
  for _, store in pairs({"store", "off_store"}) do
    for _, c in pairs(self[store]) do ---@cast c SignalStorage.Store
      if c.behavior.valid then c.behavior.entity.destroy() end
    end
  end
end

function SignalStorage:serialize()
  return {
  ["ucc-settings"] =
    {
      signals = table.deepcopy(self.signals),
      label_backup = table.deepcopy(self.label_backup),
    }
  }
end

---@param val boolean
function SignalStorage:set_main_state(val)
  ---@diagnostic disable-next-line: inject-field
  self.entity.get_control_behavior().enabled = val
  for _, cb in pairs(self.store) do
    cb.behavior.enabled = val
  end
end

local function check_vlue_limits(value)
  if value > 2147483647 then
    return 2147483647
  elseif value < -2147483648 then
    return -2147483648
  end
  return value
end

---@param obj SignalStorage
---@param slot table|nil
local function free_storage_slot(obj, slot)
  if slot and slot.store_pos then
    local store_slot = obj[slot.store_pos[3]][slot.store_pos[1]] ---@type SignalStorage.Store
    store_slot.behavior.set_signal(slot.store_pos[2], nil)
    store_slot.space_count[1] = store_slot.space_count[1] + 1
    obj.total_space[1] = obj.total_space[1] - 1
  end
  slot.store_pos = false
end

---@param obj SignalStorage
---@param slot SignalStorage.Signal
---@param inf_loop_protect boolean|nil
---@returns boolean
local function occupy_storage_slot(obj, slot, inf_loop_protect)
  if slot.store_pos then free_storage_slot(obj, slot) end
  local store_type = "off_store"
  slot.signal.count = check_vlue_limits(slot.signal.count)
  if slot.state then store_type = "store" end
  for i, store_slot in pairs(obj[store_type]) do
    if store_slot.space_count[1] > 0 then
      for j, signal_slot in pairs(store_slot.behavior.parameters) do
        if not signal_slot.signal.name then
          local  status, err = pcall(store_slot.behavior.set_signal, j, slot.signal)
          if status then
            store_slot.space_count[1] = store_slot.space_count[1] - 1
            obj.total_space[1] = obj.total_space[1] + 1
            slot.store_pos = {i, j, store_type}
          else
            store_slot.behavior.set_signal(j, nil)
            local signal = slot.signal.signal
            obj.signals[signal.type][signal.name] = nil
            return false
          end
          return true
        end
      end
    end
  end
  -- create storage
  if inf_loop_protect then return false end
  local main_entity = obj.entity
  ---@diagnostic disable-next-line: missing-fields
  local store_entity = main_entity.surface.create_entity{
    name = "ucc-config-storage",
    position = main_entity.position,
    force = main_entity.force,
    create_build_effect_smoke = false,
  }
  if not store_entity then return end
  local s_behavior = store_entity.get_control_behavior() ---@cast s_behavior LuaConstantCombinatorControlBehavior
  if store_type == "store" then
    local m_behavior = obj.entity.get_control_behavior() ---@cast m_behavior LuaConstantCombinatorControlBehavior
    s_behavior.enabled = m_behavior.enabled
    --connect new entity to grid
    ---@diagnostic disable: assign-type-mismatch
    store_entity.connect_neighbour({wire = defines.wire_type.red, target_entity = main_entity})
    store_entity.connect_neighbour({wire = defines.wire_type.green, target_entity = main_entity})
    ---@diagnostic enable: assign-type-mismatch
  end
  local s_count = s_behavior.signals_count
  table.insert(
    obj[store_type],
    {
      space_count = {s_count, s_count},
      behavior = store_entity.get_control_behavior(),
      u_id = store_entity.unit_number,
    }
  )
  obj.total_space[2] = obj.total_space[2] + s_count
  return occupy_storage_slot(obj, slot, true)
end

---@param signal SignalID
---@return SignalStorage.Signal|nil
function SignalStorage:get_signal_data(signal)
  return self.signals[signal.type][signal.name]
end

local BUTTON_STYLE = {[true] = "yellow_slot_button", [false] = "red_slot_button"}

---@param signal SignalID
function SignalStorage:get_signal_style(signal)
  local data = self.signals[signal.type][signal.name] ---@type SignalStorage.Signal
  local style = "slot_button"
  local number = nil
  if data then
    style = BUTTON_STYLE[data.state]
    number = data.signal.count ---@type int32
  end
  return style, number
end

---@param signal SignalID
---@param value number
---@param state boolean
function SignalStorage:change_or_add_signal(signal, value, state)
  local slot = self.signals[signal.type][signal.name]
  value = check_vlue_limits(value)
  if (value == 0) and state then
    if not slot then return end
    -- delete slot
    free_storage_slot(self, slot)
    self.signals[signal.type][signal.name] = nil
  elseif slot then
    -- modify slot value
    local old_state = slot.state
    slot.state = state
    slot.signal.count = value
    if slot.store_pos and (old_state == state) then
      self.store[slot.store_pos[1]].behavior.set_signal(slot.store_pos[2], slot.signal)
    else
      occupy_storage_slot(self, slot)
    end
  else
    -- create slot
    self.signals[signal.type][signal.name] =
    {
      state=state,
      signal={signal=signal, count = value},
      store_pos=false,
    }
    occupy_storage_slot(self, self.signals[signal.type][signal.name])
  end
end

---@param signal SignalID
---@param state boolean
function SignalStorage:change_slot_state(signal, state)
  local slot = self.signals[signal.type][signal.name]
  if slot then
    self:change_or_add_signal(signal, slot.signal.count, state)
  elseif not state then
    self:change_or_add_signal(signal, 0, false)
  end
end

---@param signal SignalID
---@param value number
function SignalStorage:change_slot_value(signal, value)
  local slot = self.signals[signal.type][signal.name]
  if slot then
    self:change_or_add_signal(signal, value, slot.state)
  else
    self:change_or_add_signal(signal, value, true)
  end
end

function SignalStorage:clear_all_signals()
  ---@diagnostic disable-next-line: undefined-field
  for _, store_name in pairs({"store", "off_store"}) do
    for _, store in pairs(self[store_name]) do ---@cast store SignalStorage.Store
      store.space_count[1] = store.space_count[2]
      store.behavior.parameters = nil
    end
  end
  self.total_space[1] = 0
  self.signals = {item = {}, fluid = {}, virtual = {}}
end

---Replace all signals
---@param src_obj SignalStorage
function SignalStorage:copy_settings(src_obj)
  self:clear_all_signals()
  if src_obj.entity then
    ---@diagnostic disable-next-line: undefined-field
    self:set_main_state(src_obj.entity.get_control_behavior().enabled)
  end
  self.signals = util.table.deepcopy(src_obj.signals)
  --repopulate internal combs
  for _, t in pairs(self.signals) do
    for _, slot in pairs(t) do ---@cast slot SignalStorage.Signal
      slot.store_pos = false
      occupy_storage_slot(self, slot)
    end
  end
  for i, t in pairs(src_obj.label_backup) do
    self.label_backup[i] = t
  end
end

local function get_signal_sprite(signal)
  if not signal.name then return end
  if signal.type == "item" and game.item_prototypes[signal.name] then
    return "item/" .. signal.name
  elseif signal.type == "fluid" and game.fluid_prototypes[signal.name] then
    return "fluid/" .. signal.name
  elseif signal.type == "virtual" and game.virtual_signal_prototypes[signal.name] then
    return "virtual-signal/" .. signal.name
  end
end

function SignalStorage:update_label_backup()
  self.label_backup = {}
  local mcb = self.entity.get_control_behavior() ---@cast mcb LuaConstantCombinatorControlBehavior
  for i = 1, 4 do
    local signal = mcb.get_signal(i)
    if signal.signal and signal.signal.name then
      self.label_backup[i] = {signal = signal, sprite = get_signal_sprite(signal.signal)}
    end
  end
end

function SignalStorage:restore_labels()
  local mcb = self.entity.get_control_behavior() ---@cast mcb LuaConstantCombinatorControlBehavior
  for i = 1, 4 do
    if self.label_backup[i] then
      local status, err = pcall(mcb.set_signal, i, self.label_backup[i].signal)
      if not status then self.label_backup[i] = nil end
    end
  end
end

---Copy signals from control behavior
---@param control any
---@param state_for_new boolean
---@return table<integer, integer>
function SignalStorage:add_signals(control, state_for_new)
  local add = 0
  local upd = 0
  local signals ={item = {}, fluid = {}, virtual = {}}
  for _, s in pairs(control.parameters) do ---@cast s Signal
    if s.signal.name and (not state_for_new or s.count~=0) then
      if signals[s.signal.type][s.signal.name] then
        local src = signals[s.signal.type][s.signal.name]
        src.count = src.count + s.count
      else
        signals[s.signal.type][s.signal.name] = s
      end
    end
  end
  for type, t in pairs(signals) do
    for name, s in pairs(t) do
      local slot = self.signals[type][name]
      if slot then
        upd = upd + 1
        slot.signal.count = slot.signal.count + s.count
        occupy_storage_slot(self, slot)
      else
        add = add + 1
        self:change_or_add_signal(s.signal, s.count, state_for_new)
      end
    end
  end
  return {add, upd}
end

---@param entity LuaEntity
function SignalStorage:add_signals_from_internal_entity(entity)
  local cb = entity.get_control_behavior() ---@cast cb LuaConstantCombinatorControlBehavior
  if not cb or (not cb.parameters) then return end
  self:add_signals(cb, #entity.circuit_connected_entities.red > 0)
end

---@param entity LuaEntity
function SignalStorage:is_have_this_config(entity)
  local id = entity.unit_number
  for _, store_name in pairs({"store", "off_store"}) do
    for _, store in pairs(self[store_name]) do ---@cast store SignalStorage.Store
      if store.u_id == id then return true end
    end
  end
  return false
end

function SignalStorage:check_signals()
  local st = {[true] = "store", [false] = "off_store"}
  for _, t in pairs(self.signals) do
    for name, s in pairs(t) do ---@cast s SignalStorage.Signal
      local pos = s.store_pos
      if pos then
        store = self[pos[3]][pos[1]] ---@type SignalStorage.Store
        if not store.behavior.parameters[pos[2]].signal.name then
          store.space_count[1] = store.space_count[1] + 1
          t[name] = nil
        end
      end
    end
  end
end

return SignalStorage