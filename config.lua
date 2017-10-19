-- Maximum crane height in blocks (12..n)
towercrane.max_height = tonumber(minetest.setting_get("towercrane_max_height")) or 32

-- Maximum crane width in blocks (12..n)
towercrane.max_width = tonumber(minetest.setting_get("towercrane_max_width")) or 32

-- Crane rope lenght in block (max_height .. max_height+x)
towercrane.rope_length = tonumber(minetest.setting_get("towercrane_rope_length")) or 40

-- Recipe available (true/false)
towercrane.recipe = tonumber(minetest.setting_get("towercrane_recipe")) or true
