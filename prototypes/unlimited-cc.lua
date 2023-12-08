-- entity
local combinator = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
combinator.name = "ucc-constant-combinator"
combinator.item_slot_count = 20
combinator.minable = {mining_time = 0.1, result = "ucc-constant-combinator"}
combinator.max_health = 400
combinator.corpse = "ucc-constant-combinator-remnants"
combinator.collision_box = {{-0.7, -0.7}, {0.7, 0.7}}
combinator.selection_box = {{-1, -1}, {1, 1}}
combinator.drawing_box = {{-1, -1}, {1, 1}}
combinator.fast_replaceable_group = nil
combinator.activity_led_light_offsets =
{
  {0.296875*2, -0.40625*2},
  {0.25*2, -0.03125*2},
  {-0.296875*2, -0.078125*2},
  {-0.21875*2, -0.46875*2}
}
combinator.sprites = make_4way_animation_from_spritesheet({
  layers = {
      {
          filename = "__base__/graphics/entity/combinator/hr-constant-combinator.png",
          width = 114,
          height = 102,
          frame_count = 1,
          shift = util.by_pixel(0 * 2, 5 * 2)
      },
      {
          filename = "__base__/graphics/entity/combinator/hr-constant-combinator-shadow.png",
          width = 98,
          height = 66,
          frame_count = 1,
          shift = util.by_pixel(8.5 * 2, 5.5 * 2),
          draw_as_shadow = true
      }
  }
})
combinator.activity_led_sprites = {
  north = {
      filename = "__base__/graphics/entity/combinator/activity-leds/hr-constant-combinator-LED-N.png",
      width = 14,
      height = 12,
      frame_count = 1,
      shift = util.by_pixel(9 * 2, -11.5 * 2)
  },
  east = {
      filename = "__base__/graphics/entity/combinator/activity-leds/hr-constant-combinator-LED-E.png",
      width = 14,
      height = 14,
      frame_count = 1,
      shift = util.by_pixel(7.5 * 2, -0.5 * 2)
  },
  south = {
      filename = "__base__/graphics/entity/combinator/activity-leds/hr-constant-combinator-LED-S.png",
      width = 14,
      height = 16,
      frame_count = 1,
      shift = util.by_pixel(-9 * 2, 2.5 * 2)
  },
  west = {
      filename = "__base__/graphics/entity/combinator/activity-leds/hr-constant-combinator-LED-W.png",
      width = 14,
      height = 16,
      frame_count = 1,
      shift = util.by_pixel(-7 * 2, -15 * 2)
  }
}
combinator.circuit_wire_connection_points = {
  {
      shadow = {
          red = util.by_pixel(7 * 2, -6 * 2),
          green = util.by_pixel(23 * 2, -6 * 2)
      },
      wire = {
          red = util.by_pixel(-8.5 * 2, -17.5 * 2),
          green = util.by_pixel(7 * 2, -17.5 * 2)
      }
  },
  {
      shadow = {
          red = util.by_pixel(32 * 2, -5 * 2),
          green = util.by_pixel(32 * 2, 8 * 2)
      },
      wire = {
          red = util.by_pixel(16 * 2, -16.5 * 2),
          green = util.by_pixel(16 * 2, -3.5 * 2)
      }
  },
  {
      shadow = {
          red = util.by_pixel(25 * 2, 20 * 2),
          green = util.by_pixel(9 * 2, 20 * 2)
      },
      wire = {
          red = util.by_pixel(9 * 2, 7.5 * 2),
          green = util.by_pixel(-6.5 * 2, 7.5 * 2)
      }
  },
  {
      shadow = {
          red = util.by_pixel(1 * 2, 11 * 2),
          green = util.by_pixel(1 * 2, -2 * 2)
      },
      wire = {
          red = util.by_pixel(-15 * 2, -0.5 * 2),
          green = util.by_pixel(-15 * 2, -13.5 * 2)
      }
  }
}

data:extend{combinator}
data:extend{
  {
    type = "corpse",
    name = "ucc-constant-combinator-remnants",
    icons = {
      {
        icon = "__base__/graphics/icons/constant-combinator.png",
        icon_size = 32,
      },
    },
    flags = {"placeable-neutral", "not-on-map"},
    selection_box = {{-1, -1}, {1, 1}},
    tile_width = 2,
    tile_height = 2,
    selectable_in_game = false,
    subgroup = "remnants",
    order="d[remnants]-a[generic]-a[small]",
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = make_rotated_animation_variations_from_sheet(1, {
      filename = "__base__/graphics/entity/combinator/remnants/constant/hr-constant-combinator-remnants.png",
      line_length = 1,
      width = 118,
      height = 112,
      frame_count = 1,
      variation_count = 1,
      axially_symmetrical = false,
      direction_count = 4,
      shift = util.by_pixel(0, 0),
    })
  }
}

-- item & recipe
data:extend{
  {
    type = "item",
    name = "ucc-constant-combinator",
    icons = {
      {
        icon = "__base__/graphics/icons/constant-combinator.png",
        icon_size = 64,
        icon_mipmaps = 4,
      },
      {
        icon = "__unlimited-cc__/graphics/infinity.png",
        icon_size = 32,
        tint = {0, 1, 0},
      },
    },
    subgroup = "circuit-network",
    order = "c[combinators]-d[ucc-constant-combinator]",
    place_result = "ucc-constant-combinator",
    stack_size = 20,
  },
  {
    type = "recipe",
    name = "ucc-constant-combinator",
    result = "ucc-constant-combinator",
    enabled = false,
    energy_required = 3,
    ingredients = {
      {"constant-combinator", 4},
      {"electronic-circuit", 3},
    },
  }
}

-- technology
if data.raw.technology["circuit-network"]
and data.raw.technology["circuit-network"].effects then
  -- Circuit network unlocks big constant combinator
  table.insert(
    data.raw.technology["circuit-network"].effects,
    {type = "unlock-recipe", recipe = "ucc-constant-combinator"}
  )
else
  -- Unlock from the start
  data.raw.recipe["ucc-constant-combinator"].enabled = true
end


-- Config entity
local config_dummy = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
config_dummy.name = "ucc-config-storage"
config_dummy.item_slot_count = 20
config_dummy.minable = {mining_time = 0.1, results = {}}
config_dummy.order = "zzz"
config_dummy.collision_box = {{0,0}, {0,0}} --{{-0.5,-0.5}, {0.5,0.5}}
config_dummy.collision_mask = {"not-colliding-with-itself", "colliding-with-tiles-only", "water-tile"}
config_dummy.selection_box = {{0,0}, {0,0}}
config_dummy.flags =
{
  "placeable-neutral",
  "player-creation",
  "not-on-map",
  "placeable-off-grid",
  "not-repairable",
  "not-deconstructable",
  "not-flammable",
  "not-upgradable",
  "hide-alt-info",
  "hidden",
}
config_dummy.allow_copy_paste = false
config_dummy.sprites = { filename = "__unlimited-cc__/graphics/empty.png", size = 1 }
config_dummy.activity_led_sprites = { filename = "__unlimited-cc__/graphics/empty.png", size = 1 }
config_dummy.draw_circuit_wires = false
data:extend({config_dummy})

-- Config item (needed to be stored in blueprint)
local config_dummy_item = table.deepcopy(data.raw["item"]["constant-combinator"])
config_dummy_item.name = "ucc-config-storage"
config_dummy_item.flags = {"hidden"}
config_dummy_item.place_result = "ucc-config-storage"
config_dummy_item.subgroup = "other"
local icon1 = {icon = config_dummy_item.icon, icon_size = config_dummy_item.icon_size, icon_mipmaps = config_dummy_item.icon_mipmaps}
config_dummy_item.icon = nil
config_dummy_item.icon_size = nil
config_dummy_item.icon_mipmaps = nil
config_dummy_item.icons = {
  icon1,
  {
    icon = "__core__/graphics/icons/mip/info-blue-no-border.png",
    icon_size = 16,
    icon_mipmaps = 2,
    scale = 1,
    shift = {-8, 8},
  },
}
data:extend({config_dummy_item})
