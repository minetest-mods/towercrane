-- Maximum crane height in blocks (12..n)
towercrane.max_height = tonumber(minetest.setting_get("towercrane_max_height")) or 24

-- Maximum crane width in blocks (12..n)
towercrane.max_width = tonumber(minetest.setting_get("towercrane_max_width")) or 24

-- Crane rope lenght in block (max_height .. max_height+x)
towercrane.rope_length = tonumber(minetest.setting_get("towercrane_rope_length")) or 24

-- Gain factor for the crane sound (0.0 to 1)
towercrane.gain = tonumber(minetest.setting_get("towercrane_gain")) or 1

-- Recipe available (true/false)
towercrane.recipe = tonumber(minetest.setting_get("towercrane_recipe")) or true
