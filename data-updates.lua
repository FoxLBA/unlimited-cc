if mods["nullius"] then
  data.raw.item["ucc-constant-combinator"].subgroup = "circuit-network"
  data.raw.item["ucc-constant-combinator"].order = "nullius-ga"
  table.insert(
    data.raw.technology["nullius-computation"].effects,
    {type = "unlock-recipe", recipe = "nullius-ucc-constant-combinator"}
  )
  data:extend{
    {
      type = "recipe",
      name = "nullius-ucc-constant-combinator",
      category = "large-crafting",
      result = "ucc-constant-combinator",
      enabled = false,
      always_show_made_in = true,
      energy_required = 3,
      ingredients = {
        {"constant-combinator", 4},
        {"decider-combinator", 3},
      },
    }
  }
end