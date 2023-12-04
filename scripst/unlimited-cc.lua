local SignalStorage = require "scripst.SignalStorage"
local BigConstant = {}

local MAIN_NAME = "ucc-constant-combinator"
local CONFIG_NAME = "ucc-config-storage"

local function find_entitys(entity, name)
  local pos = entity.position
  return entity.surface.find_entities_filtered{
    area = {{pos.x - 0.1, pos.y - 0.1}, {pos.x + 0.1, pos.y + 0.1}},
    name = name,
    force = entity.force,
  }
end

local function find_ghosts(entity, name)
  local pos = entity.position
  return entity.surface.find_entities_filtered{
    area = {{pos.x - 0.1, pos.y - 0.1}, {pos.x + 0.1, pos.y + 0.1}},
    ghost_name = name,
    force = entity.force,
  }
end

-- <<Events>>
function BigConstant.on_build(entity, event)
  --MAIN
  if entity.name == MAIN_NAME then
    local comb = SignalStorage:new(entity, event)
    global.combinators[entity.unit_number] = comb
    script.register_on_entity_destroyed(entity)

    --MAIN / instant build in editor or clone
    local configs = find_entitys(entity, CONFIG_NAME)
    for _, config_e in pairs(configs) do
      if not comb:is_have_this_config(config_e) then
        comb:add_signals_from_internal_entity(config_e)
        config_e.destroy()
      end
    end

    --MAIN / build on top of ghost
    configs = find_ghosts(entity, CONFIG_NAME)
    for _, config_e in pairs(configs) do
      if global.c_ghosts[config_e.unit_number] then
        global.c_ghosts[config_e.unit_number] = nil
      end
      comb:add_signals_from_internal_entity(config_e)
      config_e.destroy()
    end

  --CONFIG
  elseif entity.name == CONFIG_NAME then
    if event.stack and event.stack.name == CONFIG_NAME then
      entity.destroy() --unwanted manual build
    else
      --CONFIG / instant build in editor
      local main = find_entitys(entity, MAIN_NAME)
      if #main == 0 then return end
      local main_obj = global.combinators[main[1].unit_number]
      if main_obj then
        main_obj:add_signals_from_internal_entity(entity)
        entity.destroy()
      end
    end
  end
end

function BigConstant.on_ghost_build(entity, event)
  --MAIN
  if entity.ghost_name == MAIN_NAME then
    script.register_on_entity_destroyed(entity)
    global.c_ghosts[entity.unit_number] = {
      type = "main",
      surface = entity.surface,
      position = entity.position,
      force = entity.force,
      build_tick = event.tick,
    }

  --CONFIG
  elseif entity.ghost_name == CONFIG_NAME then
    --CONFIG / build on top of main entity
    local main = find_entitys(entity, MAIN_NAME)
    if #main > 0 then
      local main_obj = global.combinators[main[1].unit_number]
      if main_obj and (main_obj.build_tick < event.tick) then
        main_obj.build_tick = event.tick
        main_obj:clear_all_signals()
      end
      main_obj:add_signals_from_internal_entity(entity)
      entity.destroy()
      return
    end

    --CONFIG / build on top of main ghost
    main = find_ghosts(entity, MAIN_NAME)
    if #main > 0 then
      local main_g = global.c_ghosts[main[1].unit_number]
      local tick = event.tick
      if main_g and (main_g.build_tick < tick) then
        main_g.build_tick = tick
        --destroy old config ghosts
        local conf_g = find_ghosts(entity, CONFIG_NAME)
        for _, c in pairs(conf_g) do
          local c_record = global.c_ghosts[c.unit_number]
          if c_record and (c_record.build_tick ~= tick) then
            global.c_ghosts[c.unit_number] = nil
            c.destroy()
          end
        end
      end
    end

    --CONFIG / regular ghost build
    script.register_on_entity_destroyed(entity)
    local cb = entity.get_control_behavior() ---@cast cb LuaConstantCombinatorControlBehavior
    global.c_ghosts[entity.unit_number] = {
      type = "config",
      surface = entity.surface,
      position = entity.position,
      force = entity.force,
      build_tick = event.tick,
      state = #entity.circuit_connected_entities.red > 0,
      signals = {parameters = table.deepcopy(cb.parameters)},
    }
  end
end

function BigConstant.on_destroyed(event)
  local unit_number = event.unit_number
  if not unit_number then return end

  --MAIN
  local comb = global.combinators[unit_number]
  if comb then
    for _, player in pairs(game.players) do
      -- Close gui
      if player.opened
      and player.opened.object_name == "LuaGuiElement"
      and player.opened.name == MAIN_NAME
      and player.opened.tags["ucc-id"] == unit_number then
        BigConstant.destroy_gui(player.opened)
      end
    end
    comb:destroy()
    global.combinators[unit_number] = nil
    return
  end

  --ghosts
  comb = global.c_ghosts[unit_number]
  if not comb then return end
  global.c_ghosts[unit_number] = nil

  --MAIN ghost
  if comb.type == "main" then
    local main = find_entitys(comb, MAIN_NAME)
    if #main ~= 0 then return end
    local configs = find_ghosts(comb, CONFIG_NAME)
    for _, c in pairs(configs) do
      if global.c_ghosts[c.unit_number] then
        global.c_ghosts[c.unit_number] = nil
      end
      c.destroy()
    end

  --CONFIG ghost
  else
    local main = find_entitys(comb, MAIN_NAME)
    if #main == 0 then return end
    local comb_obj = global.combinators[main[1].unit_number]
    if comb_obj then
      comb_obj:add_signals(comb.signals, comb.state)
    end
  end
end

---@param event EventData.on_entity_settings_pasted
function BigConstant.on_entity_settings_pasted(event)
  local dest = event.destination
  local src = event.source
  if (not dest) or (not dest.valid) then return end
  if dest.name ~= MAIN_NAME then return end
  local dest_cb = dest.get_control_behavior() ---@cast dest_cb LuaConstantCombinatorControlBehavior
  dest_cb.parameters = nil
  if (not src) or (not src.valid) then return end

  local dest_comb = global.combinators[dest.unit_number]
  if src.name == MAIN_NAME then
    src_comb = global.combinators[src.unit_number]
    dest_comb:copy_settings(src_comb)
  else
    local res = dest_comb:add_signals(src.get_control_behavior(), true)
    ---@diagnostic disable-next-line: missing-fields
    dest.surface.create_entity {name = "flying-text", position = dest.position, text = "Added: "..res[1].."; Updated: "..res[2], color = {1.0, 1.0, 1.0}}
  end
end

-- <<GUI events>
function BigConstant.on_gui_opened(event)
  ---if event.gui_type == defines.gui_type.entity
  local entity = event.entity
  if (not entity) or (not entity.valid) then return end
  if entity.name ~= MAIN_NAME then return end
  local player = game.players[event.player_index]
  local comb = global.combinators[entity.unit_number]
  if not comb then
    player.print('BigConstant.create_gui combinator data not found. Generating default.')
    BigConstant.on_built(entity, event)
    comb = global.combinators[entity.unit_number]
  end
  -- Destroy any old versions
  if player.gui.screen[MAIN_NAME] then
    player.gui.screen[MAIN_NAME].destroy()
  end

  local gui = player.gui.screen.add{
    type = "frame",
    name = MAIN_NAME,
    direction = "vertical",
    tags = {["ucc-id"] = entity.unit_number}
  }
  gui.auto_center = true

  -- Titelebar
  local titlebar_1 = gui.add{type = "flow"}
  titlebar_1.drag_target = gui
  titlebar_1.add{
    type = "label",
    style = "frame_title",
    caption = entity.localised_name,
    ignored_by_interaction = true,
  }
  local filler_1_1 = titlebar_1.add{
    type = "empty-widget",
    style = "draggable_space",
    ignored_by_interaction = true,
  }
  filler_1_1.style.height = 24
  filler_1_1.style.horizontally_stretchable = true
  titlebar_1.add{
    type = "sprite-button",
    name = "ucc-close",
    style = "frame_action_button",
    sprite = "utility/close_white",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    tooltip = {"gui.close-instruction"},
  }

  --Main gui frame
  local inner_frame_2 = gui.add{type = "frame", direction = "vertical", style = "entity_frame"}

  --Status gui
  local s_sfow_2_1 = inner_frame_2.add{type = "flow"}
  local main_control_2_1_1 = s_sfow_2_1.add{type = "flow", direction = "vertical"}
  main_control_2_1_1.add{type = "label", caption = {"gui-constant.output"}}
  local main_switch_stale = "left"
  local mcb = comb.entity.get_control_behavior() ---@cast mcb LuaConstantCombinatorControlBehavior
  if mcb.enabled then main_switch_stale = "right" end
  main_control_2_1_1.add{
    type = "switch",
    name = "ucc-main-switch",
    allow_none_state = false,
    left_label_caption = {"gui-constant.off"},
    right_label_caption = {"gui-constant.on"},
    switch_state = main_switch_stale,
  }
  main_control_2_1_1.add{
    type = "label",
    caption = {"ucc-gui.total-signals"},
    --visible = false,
  }
  main_control_2_1_1.add{
    type = "label",
    caption = tostring(comb.total_space[1]),
    --visible = false,
  }
  local indicator_2_1_2 = s_sfow_2_1.add{type = "flow", direction = "vertical"}
  local status_flow_2_1_2_1 = indicator_2_1_2.add{type = "flow", style = "status_flow"}
  status_flow_2_1_2_1.style.vertical_align = "center"
  status_flow_2_1_2_1.add{type = "sprite", style = "status_image", sprite = BigConstant.STATUS_SPRITE[entity.status] }
  status_flow_2_1_2_1.add{type = "label", caption = {BigConstant.STATUS_NAME[entity.status]}}
  local preview_frame_2_1_2_2 = indicator_2_1_2.add{type = "frame", style = "entity_button_frame"}
  local preview = preview_frame_2_1_2_2.add{type = "entity-preview"}
  preview.entity = entity
  preview.style.height = 148
  preview.style.horizontally_stretchable = true

  --Tabs
  local tabs_frame_3 = gui.add{type = "frame", style = "inside_shallow_frame", direction = "vertical"}
  -- Create tab bar, but don't add tabs until we know which one is selected
  local tab_scroll_pane_3_1 = tabs_frame_3.add{
    type = "scroll-pane",
    style = "ucc-scroll", --"tab_scroll_pane",
    direction = "vertical",
    horizontal_scroll_policy = "never",
    vertical_scroll_policy = "auto",
  }
  tab_scroll_pane_3_1.style.padding = 0
  tab_scroll_pane_3_1.style.width = 424
  -- Signals are stored in a tabbed pane
  local tabbed_pane_3_2 = tabs_frame_3.add{type = "tabbed-pane", style = "ucc-fake-tabbed-pane"}
  local g_index = 0
  for _, group in pairs(global.gui_signals_cache) do
    g_index = g_index + 1
    -- We can't display images in tabbed-pane tabs,
    -- so make them invisible and use fake image tabs instead.
    local tab = tabbed_pane_3_2.add{type = "tab", style = "ucc-invisible-tab"}
    -- Add scrollbars in case there are too many signals
    local scroll_pane = tabbed_pane_3_2.add{
      type = "scroll-pane",
      style = "ucc-scroll",
      direction = "vertical",
      horizontal_scroll_policy = "never",
      vertical_scroll_policy = "auto",
    }
    scroll_pane.style.height = 364
    scroll_pane.style.maximal_width = 424
    local scroll_frame = scroll_pane.add{
      type = "frame",
      style = "filter_scroll_pane_background_frame",
      direction = "vertical",
    }
    scroll_frame.style.width = 400
    scroll_frame.style.minimal_height = 40
    -- Add signals
    local r = 0
    for i = 1, #group.subgroups do
      for j = 1, #group.subgroups[i], 10 do
        r = r + 1
        local row = scroll_frame.add{type = "flow", style = "packed_horizontal_flow"}
        for k = 0, 9 do
          if j+k <= #group.subgroups[i] then
            local slot = group.subgroups[i][j+k]
            local style, number = comb:get_signal_style(slot.signal)
            row.add{
              type = "sprite-button",
              style = style,
              sprite = slot.sprite,
              number = number,
              tags = {["ucc-signal"] = slot, pos = {g_index, r, k+1}},
              tooltip = {"", "[font=default-bold][color=255,230,192]", slot.localised_name, "[/color][/font]"},
            }
          end
        end
      end
    end
    -- Add the invisible tabs and visible signal pages to the tabbed-pane
    tabbed_pane_3_2.add_tab(tab, scroll_pane)
  end
  -- Add fake tab buttons with images
  local tab_bar = tab_scroll_pane_3_1.add{type = "table", style = "filter_group_table", column_count = 6}
  tab_bar.style.width = 420
  for i = 1, #global.gui_signals_cache do BigConstant.add_tab_button(tab_bar, i, 1) end
  if #global.gui_signals_cache <= 1 then
    tab_scroll_pane_3_1.style.maximal_height = 0 -- No tab bar
  elseif #global.gui_signals_cache <= 6 then
    tab_scroll_pane_3_1.style.maximal_height = 64 -- Single row tab bar
  else
    tab_scroll_pane_3_1.style.maximal_height = 144 -- Multi row tab bar
    tabbed_pane_3_2.style = "ucc-fake-tabbed-pane-multiple"
  end
  -- <<-Tabs

  local select_frame_4 = gui.add{type = "frame", style = "entity_frame"}
  select_frame_4.style.top_margin = 8
  local select_flow_4_1 = select_frame_4.add{type = "flow"}
  select_flow_4_1.style.vertical_align = "center"
  local signal_button_4_1_1 = select_flow_4_1.add{
    type = "sprite-button",
    style = "slot_button",
    enabled = false,
  }
  local switch_4_1_2 = select_flow_4_1.add{
    type = "switch",
    name = "ucc-signal-switch",
    allow_none_state = false,
    left_label_caption = {"gui-constant.off"},
    right_label_caption = {"gui-constant.on"},
    switch_state = "right",
    enabled = false,
  }
  switch_4_1_2.style.vertical_align = "center"
  -- Slider
  local slider_4_1_3 = select_flow_4_1.add{type = "slider", name = "ucc-signal-slider", maximum_value = 28, enabled = false}
  slider_4_1_3.style.left_margin = 8
  slider_4_1_3.style.right_margin = 8
  -- Text field
  local textfield_4_1_4 = select_flow_4_1.add{
    type = "textfield",
    name = "ucc-signal-number",
    text = "0",
    numeric = true,
    allow_decimal = false,
    allow_negative = true,
    enabled = false,
    clear_and_focus_on_right_click = true,
  }
  textfield_4_1_4.style.width = 80
  textfield_4_1_4.style.horizontal_align = "center"

  player.opened = gui
end

function BigConstant.on_gui_click(event)
  if not event.element.valid then return end
  if not event.element.name then return end
  local name = event.element.name
  if name == "ucc-close" then
    BigConstant.destroy_gui(event.element)
  elseif name == "" and event.element.tags then
    local tags = event.element.tags
    if tags["ucc-tab-index"] then
      BigConstant.select_tab_by_index(event.element, tags["ucc-tab-index"])
    elseif tags["ucc-signal"] then
      BigConstant.on_signal_click(event.element)
    end
  end
end

function BigConstant.on_gui_text_changed(event)
  local element = event.element
  if not element.valid then return end
  if not element.name then return end
  if element.name ~= "ucc-signal-number" then return end
  local value = tonumber(element.text) or 0
  element.parent.children[3].slider_value = BigConstant.number_to_slide_value(value)
  BigConstant.set_current_slot_value(element, "value", value)
end

function BigConstant.on_gui_value_changed(event)
  local element = event.element
  if not element.valid then return end
  if not element.name then return end
  if element.name ~= "ucc-signal-slider" then return end
  local value = 0
  -- 1-10(+1) 20-100(+10) 200-1000(+100)
  local slider_value = element.slider_value
  if slider_value < 11 then
    value = slider_value
  elseif slider_value < 20 then
    value = 10 * (slider_value - 9)
  elseif slider_value < 28 then
    value = 100 * (slider_value - 18)
  else
    value = 1000
  end
  element.parent.children[4].text = tostring(value)
  BigConstant.set_current_slot_value(element, "value", value)
end

function BigConstant.on_gui_switch_state_changed(event)
  local element = event.element
  if not element.valid then return end
  if not element.name then return end
  if element.name == "ucc-signal-switch" then
    local value = element.switch_state ~= "left"
    BigConstant.set_current_slot_value(element, "state", value)
  elseif element.name == "ucc-main-switch" then
    BigConstant.toggle_main_switch(element)
  end
end

-- <<GUI functions>>
BigConstant.STATUS_NAME = {
  [defines.entity_status.working] = "entity-status.working",
  [defines.entity_status.disabled] = "entity-status.disabled",
  [defines.entity_status.marked_for_deconstruction] = "entity-status.marked-for-deconstruction",
}
BigConstant.STATUS_SPRITE = {
  [defines.entity_status.working] = "utility/status_working",
  [defines.entity_status.disabled] = "utility/status_not_working",
  [defines.entity_status.marked_for_deconstruction] = "utility/status_not_working",
}

function BigConstant.on_signal_click(element)
  local gui = element
  while gui.parent.name ~= "screen" do gui = gui.parent end
  BigConstant.update_signal_button_state(element)
  local comb = global.combinators[gui.tags["ucc-id"]]
  local signal = element.tags["ucc-signal"]
  local select_flow = gui.children[4].children[1]

  local sprite = select_flow.children[1]
  sprite.sprite = element.sprite
  sprite.tags = {["ucc-selected-signal"]=element.tags["ucc-signal"], pos=element.tags.pos}
  local switch = select_flow.children[2]
  local slider = select_flow.children[3]
  local text = select_flow.children[4]
  sprite.enabled = true
  slider.enabled = true
  switch.enabled = true
  text.enabled = true
  local data = comb:get_signal_data(signal.signal)
  if data then
    local st = "left"
    if data.state then st = "right" end
    switch.switch_state = st
    slider.slider_value = BigConstant.number_to_slide_value(data.signal.count)
    text.text = tostring(data.signal.count)
  else
    switch.switch_state = "right"
    slider.slider_value = 0
    text.text = "0"
  end
  text.focus()
  text.select_all()
end

function BigConstant.update_signal_button_state(element)
  local gui = element
  while gui.parent.name ~= "screen" do gui = gui.parent end
  local sprite_button = gui.children[4].children[1].children[1]
  if not sprite_button.enabled then return end
  local pos = sprite_button.tags.pos
  local button = gui.children[3].children[2].tabs[pos[1]].content.children[1].children[pos[2]].children[pos[3]]

  local comb = global.combinators[gui.tags["ucc-id"]] ---@type SignalStorage
  local signal = button.tags["ucc-signal"].signal
  button.style, button.number = comb:get_signal_style(signal)
  --update "total signals" label
  gui.children[2].children[1].children[1].children[4].caption = tostring(comb.total_space[1])
end

function BigConstant.reset_signal_config_elements(element)
  local gui = element
  while gui.parent.name ~= "screen" do gui = gui.parent end
  local select_flow = gui.children[4].children[1]
  select_flow.children[1].enabled = false
  select_flow.children[1].sprite = ""
  select_flow.children[2].enabled = false
  select_flow.children[2].switch_state = "right"
  select_flow.children[3].enabled = false
  select_flow.children[3].slider_value = 0
  select_flow.children[4].enabled = false
  select_flow.children[4].text = "0"
end

function BigConstant.set_current_slot_value(element, type, value)
  local gui = element
  while gui.parent.name ~= "screen" do gui = gui.parent end
  local sprite_button = gui.children[4].children[1].children[1]
  if not sprite_button.enabled then return end
  local comb = global.combinators[gui.tags["ucc-id"]]
  local signal = sprite_button.tags["ucc-selected-signal"].signal
  if type == "value" then
    comb:change_slot_value(signal, value)
  else
    comb:change_slot_state(signal, value)
  end
  BigConstant.update_signal_button_state(gui)
end

function BigConstant.toggle_main_switch(element)
  local gui = element
  while gui.parent.name ~= "screen" do gui = gui.parent end
  local comb_obj = global.combinators[gui.tags["ucc-id"]]
  local value = element.switch_state ~= "left"
  comb_obj:set_main_state(value)
  local e_status = comb_obj.entity.status
  local staus_flow = gui.children[2].children[1].children[2].children[1]
  staus_flow.children[1].sprite = BigConstant.STATUS_SPRITE[e_status]
  staus_flow.children[2].caption = {BigConstant.STATUS_NAME[e_status]}
end

function BigConstant.destroy_gui(element)
  local gui = element
  while gui.parent.name ~= "screen" do gui = gui.parent end
  gui.destroy()
end

-- <<GUI functions/Tabs>>
function BigConstant.add_tab_button(row, i, selected)
  local name = global.gui_signals_cache[i].name
  local button = row.add{
    type = "sprite-button",
    style = "ucc-fake-tab-button",
    tooltip = {"item-group-name." .. name},
    tags = {["ucc-tab-index"] = i},
  }
  if #global.gui_signals_cache > 6 then
    button.style = "filter_group_button_tab"
  end
  if game.is_valid_sprite_path("item-group/" .. name) then
    button.sprite = "item-group/" .. name
  else
    button.caption = {"item-group-name." .. name}
  end

  -- Highlight selected tab
  if i == selected then
    BigConstant.highlight_tab_button(button, i)
    if i > 6 then
      button.parent.parent.scroll_to_element(button, "top-third")
    end
  end
end

function BigConstant.highlight_tab_button(button, index)
  local column = index % 6
  if #global.gui_signals_cache > 6 then
    button.style = "ucc-fake-tab-button-selected-grid"
  elseif column == 1 then
    button.style = "ucc-fake-tab-button-left"
  elseif column == 0 then
    button.style = "ucc-fake-tab-button-right"
  else
    button.style = "ucc-fake-tab-button-selected"
  end
end

function BigConstant.select_tab_by_index(element, index)
  local tab_bar = element.parent
  if tab_bar.parent.parent.children[2].selected_tab_index == index then return end
  -- Un-highlight old tab button
  for i = 1, #tab_bar.children do
    if #global.gui_signals_cache > 6 then
      tab_bar.children[i].style = "filter_group_button_tab"
    else
      tab_bar.children[i].style = "ucc-fake-tab-button"
    end
  end
  BigConstant.highlight_tab_button(element, index)
  BigConstant.update_signal_button_state(element)
  -- Show new tab content
  tab_bar.parent.parent.children[2].selected_tab_index = index
  BigConstant.reset_signal_config_elements(element)
end

-- <<Logic functions>>
function BigConstant.number_to_slide_value(num)
  local value = 0
  if num <= 10 then
    value = num
  elseif num <= 100 then
    value = math.floor(num / 10 + 9.5)
  elseif num < 1000 then
    value = math.floor(num / 100 + 18.5)
  else
    value = 28
  end
  return value
end

---@diagnostic disable: missing-fields
function BigConstant.cache_signals()
  local gui_groups = {}
  for _, group in pairs(game.item_group_prototypes) do
    for _, subgroup in pairs(group.subgroups) do
      if subgroup.name == "other" or subgroup.name == "virtual-signal-special" then
        -- Hide special signals
      else
        local signals = {}
        -- Item signals
        local items = game.get_filtered_item_prototypes{
          {filter = "subgroup", subgroup = subgroup.name},
          {filter = "flag", flag = "hidden", invert = true, mode = "and"},
        }
        for _, item in pairs(items) do
          if item.subgroup == subgroup then
            table.insert(signals,
            {
              signal = {type = "item", name = item.name},
              sprite = "item/" .. item.name,
              localised_name = item.localised_name,
            }
          )
          end
        end
        -- Fluid signals
        local fluids = game.get_filtered_fluid_prototypes{
          {filter = "subgroup", subgroup = subgroup.name},
          {filter = "hidden", invert = true, mode = "and"},
        }
        for _, fluid in pairs(fluids) do
          if fluid.subgroup == subgroup then
            table.insert(signals, {
              signal = {type = "fluid", name = fluid.name},
              sprite = "fluid/" .. fluid.name,
              localised_name = fluid.localised_name,
            }
          )
          end
        end
        -- Virtual signals
        for _, signal in pairs(game.virtual_signal_prototypes) do
          if signal.subgroup == subgroup then
            table.insert(signals, {
              signal = {type = "virtual", name = signal.name},
              sprite = "virtual-signal/" .. signal.name,
              localised_name = signal.localised_name,
            }
          )
          end
        end
        -- Cache the visible signals
        if #signals > 0 then
          if #gui_groups == 0 or gui_groups[#gui_groups].name ~= group.name then
            table.insert(gui_groups, {name = group.name, subgroups = {}})
          end
          table.insert(gui_groups[#gui_groups].subgroups, signals)
        end
      end
    end
  end
  global.gui_signals_cache = gui_groups
end
---@diagnostic enable: missing-fields

return BigConstant
