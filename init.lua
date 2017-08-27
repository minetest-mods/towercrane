--[[

	Tower Crane Mod
	===============

	v0.10 by JoSt

	Copyright (C) 2017 Joachim Stolberg
	LGPLv2.1+
	See LICENSE.txt for more information

	History:
	2017-06-04  v0.01  first version
	2017-06-06  v0.02  Hook bugfix
	2017-06-07  v0.03  fixed 2 bugs, added config.lua and sound
	2017-06-08  v0.04  recipe and rope length now configurable
	2017-06-10  v0.05  resizing bugfix, area protection added
	2017-07-11  v0.06  fixed the space check bug, settingtypes added
	2017-07-16  v0.07  crane remove bug fix
	2017-07-16  v0.08  player times out bugfix
	2017-08-19  v0.09  crane protection area to prevent crane clusters
	2017-08-27  v0.10  hook instance and sound switch off bug fixes

]]--

-- crane minimum size
MIN_SIZE = 8		

towercrane = {}
towercrane.hook = {}

dofile(minetest.get_modpath("towercrane") .. "/config.lua")

local function chat(owner, text)
	if owner ~= nil then
		minetest.chat_send_player(owner, "[Tower Crane] "..text)
	end
end


--##################################################################################################
--##  Construction Area
--##################################################################################################

-- Areas = {
--     pos_key = {owner="...", pos1=pos, pos2=pos},
-- }
local storage = minetest.get_mod_storage()
local Areas = minetest.deserialize(storage:get_string("Areas")) or {}

local function update_mod_storage()
	storage:set_string("Areas", minetest.serialize(Areas))
end

minetest.register_on_shutdown(function()
	update_mod_storage()
end)

----------------------------------------------------------------------------------------------------
-- The same player can't place a crane within another protection area
----------------------------------------------------------------------------------------------------
local function no_area_violation(owner, pos)
	local res = true
	local px, py, pz = pos.x, pos.y, pos.z
	for key, area in pairs(Areas) do
		if owner == area.owner then
			local pos1, pos2 = area.pos1, area.pos2
			if (px >= pos1.x and px <= pos2.x) and (py >= pos1.y and py <= pos2.y) and
					(pz >= pos1.z and pz <= pos2.z) then
				res = false
				break
			end
		end
	end
	return res
end


local function store_crane_data(owner, pos, pos1, pos2)
	-- normalize x/z so that pos2 > pos1
	if pos2.x < pos1.x then
		pos2.x, pos1.x = pos1.x, pos2.x
	end
	if pos2.z < pos1.z then
		pos2.z, pos1.z = pos1.z, pos2.z
	end
	-- store data
	local key = minetest.pos_to_string(pos)
	Areas[key] = {owner=owner, pos1=pos1, pos2=pos2}
	update_mod_storage()
end
	
local function remove_crane_data(pos)
	local key = minetest.pos_to_string(pos)
	Areas[key] = nil
	update_mod_storage()
end

--##################################################################################################
--##  Tower Crane Hook
--##################################################################################################
local hook = {
	physical = true,
	collisionbox = {-0.2, -0.2, -0.2, 0.2, 0.2, 0.2},
	collide_with_objects = false,
	visual = "cube",
	visual_size = {x=0.6, y=0.6},
	textures = {
		"towercrane_hook.png",
		"towercrane_hook.png",
		"towercrane_hook.png",
		"towercrane_hook.png",
		"towercrane_hook.png",
		"towercrane_hook.png",
	},
	groups = {cracky=1},
	-- local variabels
	driver = nil,
	speed_forward=0,
	speed_right=0,
	speed_up=0,
	sound=nil,
}

----------------------------------------------------------------------------------------------------
-- Enter/leave the Hook
----------------------------------------------------------------------------------------------------
function hook:on_rightclick(clicker)
	local name = clicker:get_player_name()
	if self.driver and clicker == self.driver then  -- leave?
		clicker:set_detach()
		default.player_attached[name] = false
		default.player_set_animation(clicker, "stand" , 10)
		self.driver = nil
		if self.sound ~= nil then
			minetest.sound_stop(self.sound)
			self.sound = nil
		end
	elseif not self.driver then                     -- enter?
		self.driver = clicker
		clicker:set_attach(self.object, "", {x=0,y=15,z=-3}, {x=0,y=0,z=0})
		default.player_attached[name] = true
		default.player_set_animation(clicker, "sit" , 10)
	end
end

----------------------------------------------------------------------------------------------------
-- Hook control
----------------------------------------------------------------------------------------------------
function hook:on_step(dtime)
	-- remove hook from  last visit
	if self.pos1 == nil or self.pos2 == nil then
		self.object:remove()
		return
	end
	if self.driver then
		local ctrl = self.driver:get_player_control()
		local yaw = self.driver:get_look_horizontal()
		local pos = self.driver:getpos()
		local max_speed = 5
		local velocity = 0.5

		if yaw == nil or pos == nil or ctrl == nil then
			return
		end
		if ctrl.up then             -- forward
			self.speed_forward = math.min(self.speed_forward + velocity, max_speed)
		elseif ctrl.down then       -- backward
			self.speed_forward = math.max(self.speed_forward - velocity, -max_speed)
		elseif self.speed_forward > 0 then
			self.speed_forward = self.speed_forward - velocity
		elseif self.speed_forward < 0 then
			self.speed_forward = self.speed_forward + velocity
		end

		if ctrl.right then          -- right
			self.speed_right = math.min(self.speed_right + velocity, max_speed)
		elseif ctrl.left then       -- left
			self.speed_right = math.max(self.speed_right - velocity, -max_speed)
		elseif self.speed_right > 0 then
			self.speed_right = self.speed_right - velocity
		elseif self.speed_right < 0 then
			self.speed_right = self.speed_right + velocity
		end

		if ctrl.jump then           -- up
			self.speed_up = math.min(self.speed_up + velocity, 5)
		elseif ctrl.sneak then      -- down
			self.speed_up = math.max(self.speed_up - velocity, -5)
		elseif self.speed_up > 0 then
			self.speed_up = self.speed_up - velocity
		elseif self.speed_up < 0 then
			self.speed_up = self.speed_up + velocity
		end

		-- calculate the direction vector
		local vx = math.cos(yaw+math.pi/2) * self.speed_forward + math.cos(yaw) * self.speed_right
		local vz = math.sin(yaw+math.pi/2) * self.speed_forward + math.sin(yaw) * self.speed_right

		-- check if outside of the construction area
		if pos.x < self.pos1.x then vx= velocity end
		if pos.x > self.pos2.x then vx= -velocity end
		if pos.y < self.pos1.y then self.speed_up=  velocity end
		if pos.y > self.pos2.y then self.speed_up= -velocity end
		if pos.z < self.pos1.z then vz=  velocity end
		if pos.z > self.pos2.z then vz= -velocity end

		-- sound control
		if vx ~= 0 or vz ~= 0 or self.speed_up ~= 0 then
			if self.sound == nil then
				self.sound = minetest.sound_play({name="crane"},{object=self.object, pos=pos,
												 gain=towercrane.gain, max_hear_distance=20,
												 loop=true})
			end
		elseif self.sound ~= nil then
			minetest.sound_stop(self.sound)
			self.sound = nil
		end

		self.object:setvelocity({x=vx, y=self.speed_up,z=vz})
	else
		self.object:setvelocity({x=0, y=0,z=0})
	end
end

----------------------------------------------------------------------------------------------------
-- LuaEntitySAO (non-player moving things): see http://dev.minetest.net/LuaEntitySAO
----------------------------------------------------------------------------------------------------
minetest.register_entity("towercrane:hook", hook)



--##################################################################################################
--##  Tower Crane
--##################################################################################################

local function turnright(dir)
	local facedir = minetest.dir_to_facedir(dir)
	return minetest.facedir_to_dir((facedir + 1) % 4)
end

local function turnleft(dir)
	local facedir = minetest.dir_to_facedir(dir)
	return minetest.facedir_to_dir((facedir + 3) % 4)
end

----------------------------------------------------------------------------------------------------
-- generic function for contruction and removement
----------------------------------------------------------------------------------------------------
local function crane_body_plan(pos, dir, height, width, clbk, tArg)
	pos.y = pos.y + 1
	clbk(pos, "towercrane:mast_ctrl_off", tArg)

	for i = 1,height+1 do
		pos.y = pos.y + 1
		clbk(pos, "towercrane:mast", tArg)
	end

	pos.y = pos.y - 2
	pos.x = pos.x - dir.x
	pos.z = pos.z - dir.z
	clbk(pos, "towercrane:arm2", tArg)
	pos.x = pos.x - dir.x
	pos.z = pos.z - dir.z
	clbk(pos, "towercrane:arm", tArg)
	pos.x = pos.x - dir.x
	pos.z = pos.z - dir.z
	clbk(pos, "towercrane:balance", tArg)
	pos.x = pos.x + 3 * dir.x
	pos.z = pos.z + 3 * dir.z

	for i = 1,width do
		pos.x = pos.x + dir.x
		pos.z = pos.z + dir.z
		if i % 2 == 0 then
			clbk(pos, "towercrane:arm2", tArg)
		else
			clbk(pos, "towercrane:arm", tArg)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Check space for mast and arm
----------------------------------------------------------------------------------------------------
local function check_space(pos, dir, height, width)
	local remove = function(pos, node_name, tArg)
		if minetest.get_node_or_nil(pos).name ~= "air" then
			tArg.res = false
		end
	end
		
	local tArg = {res = true}
	crane_body_plan(pos, dir, height, width, remove, tArg)
	return tArg.res
end

----------------------------------------------------------------------------------------------------
-- Constuct mast and arm
----------------------------------------------------------------------------------------------------
local function construct_crane(pos, dir, height, width, owner)
	local add = function(pos, node_name, tArg)
		minetest.add_node(pos, {name=node_name, param2=minetest.dir_to_facedir(tArg.dir)})
	end
	
	local tArg = {dir = dir}
	crane_body_plan(table.copy(pos), dir, height, width, add, tArg)
	
	pos.y = pos.y + 1
	local meta = minetest.get_meta(pos)
	meta:set_string("dir", minetest.pos_to_string(dir))
	meta:set_string("owner", owner)
	meta:set_int("height", height)
	meta:set_int("width", width)
end

----------------------------------------------------------------------------------------------------
-- Remove the crane
----------------------------------------------------------------------------------------------------
local function remove_crane(pos, dir, height, width)
	local remove = function(pos, node_name, tArg)
		if minetest.get_node_or_nil(pos).name == node_name or
				minetest.get_node_or_nil(pos).name == "towercrane:mast_ctrl_on" then
			minetest.remove_node(pos)
		end
	end
	
	crane_body_plan(table.copy(pos), dir, height, width, remove, {})
end

----------------------------------------------------------------------------------------------------
-- Place the hook in front of the base
----------------------------------------------------------------------------------------------------
local function place_hook(pos, dir)
	pos.y = pos.y - 1
	pos.x = pos.x + dir.x
	pos.z = pos.z + dir.z
	return minetest.add_entity(pos, "towercrane:hook")
end

----------------------------------------------------------------------------------------------------
-- Remove hook, reset player and stop sound
----------------------------------------------------------------------------------------------------
local function remove_hook(player, pos, y_offs)
	-- determine hook_key
	pos = table.copy(pos)
	pos.y = pos.y + y_offs
	local key = minetest.hash_node_position(pos)
	default.player_set_animation(player, "stand" , 10)
	local hook = towercrane.hook[key]
	if hook then
		-- remove hook
		hook:remove()
		if hook:get_luaentity().sound ~= nil then
			-- stop sound
			minetest.sound_stop(hook:get_luaentity().sound)
		end
		towercrane.hook[key] = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Check if the given construction area is not already protected
----------------------------------------------------------------------------------------------------
local function check_area(pos1, pos2, owner)
	if not areas then return true end
	for id, a in ipairs(areas:getAreasIntersectingArea(pos1, pos2)) do
		if a.owner ~= owner then
			return false
		end
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- Calculate and set the protection area (pos1, pos2)
----------------------------------------------------------------------------------------------------
local function protect_area(pos, dir, height, width, owner)
	if not areas then return 0 end
	-- pos1 = close/right/below
	dir = turnright(dir)
	dir = turnright(dir)
	local pos1 = vector.add(pos, vector.multiply(dir, 2))
	dir = turnleft(dir)
	pos1 = vector.add(pos1, vector.multiply(dir, width/2))
	dir = turnleft(dir)
	pos1.y = pos.y - 2

	-- pos2 = far/left/above
	local pos2 = vector.add(pos1, vector.multiply(dir, width+2))
	dir = turnleft(dir)
	pos2 = vector.add(pos2, vector.multiply(dir, width))
	pos2.y = pos.y + 2 + height

	store_crane_data(owner, pos, pos1, pos2)

	-- add area
	local canAdd, errMsg = areas:canPlayerAddArea(pos1, pos2, owner)
	if canAdd then
		local id = areas:add(owner, "Construction site", pos1, pos2, nil)
		areas:save()
		return id
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- Remove the protection area
----------------------------------------------------------------------------------------------------
local function remove_area(id, owner)
	if not areas then return end
	if areas:isAreaOwner(id, owner) then
		areas:remove(id)
		areas:save()
	end
end

----------------------------------------------------------------------------------------------------
-- Check user input (height, width)
----------------------------------------------------------------------------------------------------
local function check_input(fields)
	local size = string.split(fields.size, ",")
	if #size == 2  then
		local height = tonumber(size[1])
		local width = tonumber(size[2])
		if height ~= nil and width ~= nil then
			height = math.max(height, MIN_SIZE)
			height = math.min(height, towercrane.max_height)
			width = math.max(width, MIN_SIZE)
			width = math.min(width, towercrane.max_width)
			return height, width
		end
	end
	return 0, 0
end

----------------------------------------------------------------------------------------------------
-- Register Crane base
----------------------------------------------------------------------------------------------------
minetest.register_node("towercrane:base", {
	description = "Tower Crane Base",
	inventory_image = "towercrane_invent.png",
	tiles = {
		"towercrane_base_top.png",
		"towercrane_base.png",
		"towercrane_base.png",
		"towercrane_base.png",
		"towercrane_base.png",
		"towercrane_base.png",
	},
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {cracky=2},

	-- set meta data (form for crane height and width, dir of the arm)
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		local owner = placer:get_player_name()
		meta:set_string("owner", owner)
		local formspec = "size[5,4]"..
			"label[0,0;Construction area size]" ..
			"field[1,1.5;3,1;size;height,width;]" ..
			"button_exit[1,2;2,1;exit;Save]"
		meta:set_string("formspec", formspec)

		local fdir = minetest.dir_to_facedir(placer:get_look_dir(), false)
		local dir = minetest.facedir_to_dir(fdir)
		meta:set_string("dir", minetest.pos_to_string(dir))
	end,

	-- evaluate user input (height, width), destroyed old crane and build a new one with
	-- the given size
	on_receive_fields = function(pos, formname, fields, player)
		if fields.size == nil then
			return
		end
		local meta = minetest.get_meta(pos)
		local owner = meta:get_string("owner")
		local dir = minetest.string_to_pos(meta:get_string("dir"))
		local height = meta:get_int("height")
		local width = meta:get_int("width")
		local id = meta:get_int("id")

		if not player or not player:is_player() then
			return
		end
		if player:get_player_name() ~= owner then
			return
		end
		-- destroy area and crane
		if dir ~= nil and height ~= nil and width ~= nil then
			remove_crane_data(pos)
			remove_area(id, owner)
			remove_crane(table.copy(pos), dir, height, width)
			remove_hook(player, pos, 1)
		end

		-- evaluate user input
		height, width = check_input(fields)
		if height ~= 0 then
			meta:set_int("height", height)
			meta:set_int("width", width)
			meta:set_string("infotext", "Crane size: " .. height .. "," .. width)
			if no_area_violation(owner, pos) then
				if dir ~= nil then
					if check_space(table.copy(pos), dir, height, width) then
						-- add protection area
						local id = protect_area(table.copy(pos), table.copy(dir), height, width, owner)
						if id ~= nil then
							meta:set_int("id", id)
							construct_crane(table.copy(pos), table.copy(dir), height, width, owner)
						else
							chat(owner, "Construction area is already protected!")
						end
					else
						chat(owner, "Too less space to raise up the crane!")
					end
				end
			else
				chat(owner, "Too less distance to your other crane(s)!")
			end
		end
	end,

	-- remove mast and arm if base gets destroyed
	on_destruct = function(pos)
		local meta = minetest.get_meta(pos)
		local dir = minetest.string_to_pos(meta:get_string("dir"))
		local height = meta:get_int("height")
		local width = meta:get_int("width")
		local id = meta:get_int("id")
		local owner = meta:get_string("owner")

		-- remove protection area
		if id ~= nil then
			remove_area(id, owner)
		end
		-- remove crane
		if dir ~= nil and height ~= nil and width ~= nil then
			remove_crane_data(pos)
			remove_crane(pos, dir, height, width)
		end
		-- remove hook
		local player = minetest.get_player_by_name(owner)
		remove_hook(player, pos, 1)
	end,
})

----------------------------------------------------------------------------------------------------
-- Register Crane balance
----------------------------------------------------------------------------------------------------
minetest.register_node("towercrane:balance", {
	description = "Tower Crane Balance",
	tiles = {
		"towercrane_base.png",
		"towercrane_base.png",
		"towercrane_base.png",
		"towercrane_base.png",
		"towercrane_base.png",
		"towercrane_base.png",
	},
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {crumbly=0, not_in_creative_inventory=1},
})

----------------------------------------------------------------------------------------------------
-- Register Crane mast
----------------------------------------------------------------------------------------------------
minetest.register_node("towercrane:mast", {
	description = "Tower Crane Mast",
	drawtype = "glasslike_framed",
	tiles = {
		"towercrane_mast.png",
		"towercrane_mast.png",
		"towercrane_mast.png",
		"towercrane_mast.png",
		"towercrane_mast.png",
		"towercrane_mast.png",
	},
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {crumbly=0, not_in_creative_inventory=1},
})

----------------------------------------------------------------------------------------------------
-- Register Crane Switch (on)
----------------------------------------------------------------------------------------------------
minetest.register_node("towercrane:mast_ctrl_on", {
	description = "Tower Crane Mast Ctrl On",
	drawtype = "node",
	tiles = {
		"towercrane_mast_ctrl.png",
		"towercrane_mast_ctrl.png",
		"towercrane_mast_ctrl_on.png",
		"towercrane_mast_ctrl_on.png",
		"towercrane_mast_ctrl.png",
		"towercrane_mast_ctrl.png",
	},
	-- switch the crane OFF
	on_rightclick = function (pos, node, clicker)
		local meta = minetest.get_meta(pos)
		if not clicker or not clicker:is_player() then
			return
		end
		if clicker:get_player_name() ~= meta:get_string("owner") then
			return
		end
		node.name = "towercrane:mast_ctrl_off"
		minetest.swap_node(pos, node)

		local id = minetest.hash_node_position(pos)
		remove_hook(clicker, pos, 0)
	end,

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Switch crane on/off")
	end,

	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		local owner = placer:get_player_name()
		meta:set_string("owner", owner)
	end,

	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {crumbly=0, not_in_creative_inventory=1},
})

----------------------------------------------------------------------------------------------------
-- Register Crane Switch (off)
----------------------------------------------------------------------------------------------------
minetest.register_node("towercrane:mast_ctrl_off", {
	description = "Tower Crane Mast Ctrl Off",
	drawtype = "node",
	tiles = {
		"towercrane_mast_ctrl.png",
		"towercrane_mast_ctrl.png",
		"towercrane_mast_ctrl_off.png",
		"towercrane_mast_ctrl_off.png",
		"towercrane_mast_ctrl.png",
	  "towercrane_mast_ctrl.png",
	},
	-- switch the crane ON
	on_rightclick = function (pos, node, clicker)
		-- calculate the construction area, and place the hook
		local meta = minetest.get_meta(pos)
		-- only the owner is allowed to switch
		if not clicker or not clicker:is_player() then
			return
		end
		if clicker:get_player_name() ~= meta:get_string("owner") then
			return
		end
		-- swap to the other node
		node.name = "towercrane:mast_ctrl_on"
		minetest.swap_node(pos, node)
		local dir = minetest.string_to_pos(meta:get_string("dir"))
		if pos ~= nil and dir ~= nil then
			-- store hook instance in 'towercrane'
			local id = minetest.hash_node_position(pos)
			towercrane.hook[id] = place_hook(table.copy(pos), dir)

			--
			-- calculate the construction area dimension (pos1, pos2)
			--
			local height = meta:get_int("height")
			local width = meta:get_int("width")

			-- pos1 = close/right/below
			dir = turnright(dir)
			local pos1 = vector.add(pos, vector.multiply(dir, width/2))
			dir = turnleft(dir)
			local pos1 = vector.add(pos1, vector.multiply(dir, 1))
			pos1.y = pos.y - 2 + height - towercrane.rope_length

			-- pos2 = far/left/above
			local pos2 = vector.add(pos1, vector.multiply(dir, width-1))
			dir = turnleft(dir)
			pos2 = vector.add(pos2, vector.multiply(dir, width))
			pos2.y = pos.y - 3 + height

			-- normalize x/z so that pos2 > pos1
			if pos2.x < pos1.x then
				pos2.x, pos1.x = pos1.x, pos2.x
			end
			if pos2.z < pos1.z then
				pos2.z, pos1.z = pos1.z, pos2.z
			end

			-- store pos1/pos2 in the hook (LuaEntitySAO)
			towercrane.hook[id]:get_luaentity().pos1 = pos1
			towercrane.hook[id]:get_luaentity().pos2 = pos2
		end
	end,

	on_construct = function(pos)
		-- add infotext
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Switch crane on/off")
	end,

	after_place_node = function(pos, placer, itemstack, pointed_thing)
		-- store owner for dig protection
		local meta = minetest.get_meta(pos)
		local owner = placer:get_player_name()
		meta:set_string("owner", owner)
	end,

	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {crumbly=0, not_in_creative_inventory=1},
})

----------------------------------------------------------------------------------------------------
-- Register Crane arm 1
----------------------------------------------------------------------------------------------------
minetest.register_node("towercrane:arm", {
	description = "Tower Crane Arm",
	drawtype = "glasslike_framed",
	tiles = {
		"towercrane_arm.png",
		"towercrane_arm.png",
		"towercrane_arm.png",
		"towercrane_arm.png",
		"towercrane_arm.png",
		"towercrane_arm.png",
	},
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {crumbly=0, not_in_creative_inventory=1},
})

----------------------------------------------------------------------------------------------------
-- Register Crane arm 2
----------------------------------------------------------------------------------------------------
minetest.register_node("towercrane:arm2", {
	description = "Tower Crane Arm2",
	drawtype = "glasslike_framed",
	tiles = {
		"towercrane_arm2.png",
		"towercrane_arm2.png",
		"towercrane_arm2.png",
		"towercrane_arm2.png",
		"towercrane_arm2.png",
		"towercrane_arm2.png",
	},
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {crumbly=0, not_in_creative_inventory=1},
})


----------------------------------------------------------------------------------------------------
-- Register Recipe
----------------------------------------------------------------------------------------------------
if towercrane.recipe then
	minetest.register_craft({
		output = "towercrane:base",
		recipe = {
			{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
			{"default:steel_ingot", "", ""},
			{"default:steel_ingot", "dye:yellow", ""}
		}
	})
end



