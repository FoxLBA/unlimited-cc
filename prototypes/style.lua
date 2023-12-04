-- Scroll pane
data.raw["gui-style"]["default"]["ucc-scroll"] = {
  type = "scroll_pane_style",
  padding = 2,
  minimal_height = 44,
  extra_padding_when_activated = 0,
  horizontally_stretchable = "off",
  background_graphical_set = {
    corner_size = 1,
    position = {41, 7},
  },
}

-- Tabbed pane
local tabbed_pane = {
  type = "tabbed_pane_style",
  tab_content_frame = {
    type = "frame_style",
    top_padding = 10,
    bottom_padding = 6,
    left_padding = 10,
    right_padding = 10,
    top_margin = 2,
    graphical_set = {
      base = table.deepcopy(data.raw["gui-style"]["default"]["filter_tabbed_pane"].tab_content_frame.graphical_set.base.center)
    },
  },
}
data.raw["gui-style"]["default"]["ucc-fake-tabbed-pane"] = tabbed_pane

-- Tabbed pane (multiple rows)
local multi_tabbed_pane = table.deepcopy(tabbed_pane)
multi_tabbed_pane.tab_content_frame.bottom_padding = 10
data.raw["gui-style"]["default"]["ucc-fake-tabbed-pane-multiple"] = multi_tabbed_pane

-- Real tab button
data.raw["gui-style"]["default"]["ucc-invisible-tab"] = {
  type = "tab_style",
  width = 0,
  padding = 0,
  font = "ucc-invisible-font",
}

-- Fake tab button
local group_tab = table.deepcopy(data.raw["gui-style"]["default"]["filter_group_tab"])
group_tab.default_graphical_set.base.left_bottom = {position = {102, 9}, size = {8, 8}}
group_tab.default_graphical_set.base.bottom = {position = {110, 9}, size = {1, 8}}
group_tab.default_graphical_set.base.right_bottom = {position = {111, 9}, size = {8, 8}}
local tab_button = {
  type = "button_style",
  width = 70,
  height = 64,
  default_graphical_set = group_tab.default_graphical_set,
  hovered_graphical_set = group_tab.hover_graphical_set,
  clicked_graphical_set = group_tab.pressed_graphical_set,
  left_click_sound = group_tab.left_click_sound,
  padding = 2,
  font = "default-game",
  default_font_color = {255, 255, 255},
  hovered_font_color = {255, 255, 255},
  clicked_font_color = {255, 255, 255},
}
data.raw["gui-style"]["default"]["ucc-fake-tab-button"] = tab_button

-- Fake tab button (selected)
local tab_button_selected = table.deepcopy(tab_button)
tab_button_selected.default_graphical_set = group_tab.selected_graphical_set
tab_button_selected.hovered_graphical_set = group_tab.selected_graphical_set
tab_button_selected.clicked_graphical_set = group_tab.selected_graphical_set
data.raw["gui-style"]["default"]["ucc-fake-tab-button-selected"] = tab_button_selected

-- Fake tab button (selected, left)
local tab_button_left = table.deepcopy(tab_button)
tab_button_left.default_graphical_set = group_tab.left_edge_selected_graphical_set
tab_button_left.hovered_graphical_set = group_tab.left_edge_selected_graphical_set
tab_button_left.clicked_graphical_set = group_tab.left_edge_selected_graphical_set
data.raw["gui-style"]["default"]["ucc-fake-tab-button-left"] = tab_button_left

-- Fake tab button (selected, right)
local tab_button_right = table.deepcopy(tab_button)
tab_button_right.default_graphical_set = group_tab.right_edge_selected_graphical_set
tab_button_right.hovered_graphical_set = group_tab.right_edge_selected_graphical_set
tab_button_right.clicked_graphical_set = group_tab.right_edge_selected_graphical_set
data.raw["gui-style"]["default"]["ucc-fake-tab-button-right"] = tab_button_right

-- Grid tab button (selected)
local grid_selected = table.deepcopy(data.raw["gui-style"]["default"]["filter_group_button_tab"].selected_graphical_set)
data.raw["gui-style"]["default"]["ucc-fake-tab-button-selected-grid"] = {
  type = "button_style",
  parent = "filter_group_button_tab",
  default_graphical_set = grid_selected,
  hovered_graphical_set = grid_selected,
  clicked_graphical_set = grid_selected,
}
