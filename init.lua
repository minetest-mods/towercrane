--[[

    Tower Crane Mod
    ===============

    v0.01 by JoSt
    
    Copyright (C) 2017 Joachim Stolberg
    LGPLv2.1+
    See LICENSE.txt for more information

    History:
    2017-06-04  v0.01  first version
    2017-06-06  v0.02  Hook bugfix
]]--


towercrane = {}

--##################################################################################################
--##  Tower Crane Hook
--##################################################################################################
local hook = {
    physical = true, 
    collisionbox = {-0.2, -0.2, -0.2, 0.2, 0.2, 0.2},
    collide_with_objects = false,   
    visual = "cube",
    visual_size = {x=0.4, y=0.4},
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
}
----------------------------------------------------------------------------------------------------
-- Enter/leave the Hook
----------------------------------------------------------------------------------------------------
function hook:on_rightclick(clicker)
    if self.driver and clicker == self.driver then  -- leave?
        clicker:set_detach()
        self.driver = nil
    elseif not self.driver then                     -- enter?
        self.driver = clicker
        clicker:set_attach(self.object, "", {x=0,y=0,z=0}, {x=0,y=0,z=0})
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
-- Constuct mast and arm
----------------------------------------------------------------------------------------------------
local function construct_crane(pos, dir, height, width, owner)
    pos.y = pos.y + 1
    minetest.env:add_node(pos, {name="towercrane:mast_ctrl_off", param2=minetest.dir_to_facedir(dir)})
    local meta = minetest.get_meta(pos)
    meta:set_string("dir", minetest.pos_to_string(dir))
    meta:set_string("owner", owner)
    meta:set_int("height", height)
    meta:set_int("width", width)

    for i = 1,height+1 do
        pos.y = pos.y + 1
        minetest.env:add_node(pos, {name="towercrane:mast"})
    end
    
    pos.y = pos.y - 2
    pos.x = pos.x - dir.x
    pos.z = pos.z - dir.z
    minetest.env:add_node(pos, {name="towercrane:arm2"})
    pos.x = pos.x - dir.x
    pos.z = pos.z - dir.z
    minetest.env:add_node(pos, {name="towercrane:arm"})
    pos.x = pos.x - dir.x
    pos.z = pos.z - dir.z
    minetest.env:add_node(pos, {name="towercrane:balance"})
    pos.x = pos.x + 3 * dir.x
    pos.z = pos.z + 3 * dir.z
    
    for i = 1,width do
        pos.x = pos.x + dir.x
        pos.z = pos.z + dir.z
        if i % 2 == 0 then
            minetest.env:add_node(pos, {name="towercrane:arm2"})
        else
            minetest.env:add_node(pos, {name="towercrane:arm"})
        end
        
    end
end

----------------------------------------------------------------------------------------------------
-- Remove the crane
----------------------------------------------------------------------------------------------------
local function dig_crane(pos, dir, height, width)
    pos.y = pos.y + 1
    minetest.env:remove_node(pos, {name="towercrane:mast_ctrl_off"})
    
    for i = 1,height+1 do
        pos.y = pos.y + 1
        minetest.env:remove_node(pos, {name="towercrane:mast"})
    end

    pos.y = pos.y - 2
    pos.x = pos.x - dir.x
    pos.z = pos.z - dir.z
    minetest.env:remove_node(pos, {name="towercrane:arm2"})
    pos.x = pos.x - dir.x
    pos.z = pos.z - dir.z
    minetest.env:remove_node(pos, {name="towercrane:arm"})
    pos.x = pos.x - dir.x
    pos.z = pos.z - dir.z
    minetest.env:remove_node(pos, {name="towercrane:balance"})
    pos.x = pos.x + 3 * dir.x
    pos.z = pos.z + 3 * dir.z
    
    for i = 1,width do
        pos.x = pos.x + dir.x
        pos.z = pos.z + dir.z
        if i % 2 == 0 then
            minetest.env:remove_node(pos, {name="towercrane:arm2"})
        else
            minetest.env:remove_node(pos, {name="towercrane:arm"})
        end
    end
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
    groups = {cracky=3},
    formspec = set_formspec,

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

        if not player or not player:is_player() then
            return
        end
        local owner = meta:get_string("owner")
        if player:get_player_name() ~= owner then
            return
        end
        
        local dir = minetest.string_to_pos(meta:get_string("dir"))
        local height = meta:get_int("height")
        local width = meta:get_int("width")
        local org_pos = table.copy(pos)
        if dir ~= nil and height ~= nil and width ~= nil then
           dig_crane(pos, dir, height, width)
        end
        --check for correct size format
        size = string.split(fields.size, ",")
        if #size == 2  then
            local height = tonumber(size[1])
            local width = tonumber(size[2])
            if height ~= nil and width ~= nil then
                height = math.max(height, 8)
                height = math.min(height, 24)
                width = math.max(width, 8)
                width = math.min(width, 24)
                meta:set_int("height", height)
                meta:set_int("width", width)
                meta:set_string("infotext", "Crane size: " .. height .. "," .. width)
                if dir ~= nil then
                    construct_crane(org_pos, dir, height, width, owner)
                end
            end
        end
    end,

    -- remove mast and arm if base gets destroyed
    on_destruct = function(pos)
        local meta = minetest.get_meta(pos)
        local dir = minetest.string_to_pos(meta:get_string("dir"))
        local height = meta:get_int("height")
        local width = meta:get_int("width")

        -- remove crane
        if dir ~= nil and height ~= nil and width ~= nil then
           dig_crane(pos, dir, height, width)
        end
        -- remove hook
        local id = minetest.hash_node_position(pos)
        if towercrane.id then
            towercrane.id:remove()
            towercrane.id = nil
        end
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
        if towercrane.id then
            towercrane.id:remove()
            towercrane.id = nil
        end
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
    on_rightclick = function (pos, node, clicker)
        -- switch switch on, calculate the construction area, and place the hook
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
            towercrane.id = place_hook(table.copy(pos), dir)

            -- calculate the construction area dimension (pos, pos2)
            local height = meta:get_int("height")
            local width = meta:get_int("width")

            -- pos1 = close/right
            dir = turnright(dir)
            local pos1 = vector.add(pos, vector.multiply(dir, width/2))
            dir = turnleft(dir)
            local pos1 = vector.add(pos1, vector.multiply(dir, 1))
            pos1.y = pos.y - 1

            -- pos2 = far/left
            local pos2 = vector.add(pos1, vector.multiply(dir, width-1))
            dir = turnleft(dir)
            pos2 = vector.add(pos2, vector.multiply(dir, width))
            pos2.y = pos.y - 4 + height

            -- normalize x/z so that pos2 > pos1
            if pos2.x < pos1.x then
                pos2.x, pos1.x = pos1.x, pos2.x
            end
            if pos2.z < pos1.z then
                pos2.z, pos1.z = pos1.z, pos2.z
            end

            -- store pos1/pos2 in the hook (LuaEntitySAO)
            towercrane.id:get_luaentity().pos1 = pos1
            towercrane.id:get_luaentity().pos2 = pos2
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
