# Tower Crane Mod V0.05
In order to simplify the construction of buildings, the crane forms a construction area in which the player can fly (similar to fly privs).

Browse on: ![GitHub](https://github.com/joe7575/Minetest-Towercrane)
Download: ![GitHub](https://github.com/joe7575/Minetest-Towercrane/archive/master.zip)

The crane can be completely assembled by setting only the base block.
The size of the crane (which is the construction area) can be configured.
The owner of the crane get automatically area protection over the complete construction area (therefore the area Mod is required).

![Tower Crane](https://github.com/joe7575/Minetest-Towercrane/blob/master/towercrane640.png)


## Introduction
* Place the crane base block.
  The crane arm will later be build in the same direction you are currently looking 

* Right-click the crane base block and set the crane dimensions in height and width (between 8 and 24 by default).
  The crane will be build according to this settings.
  If there is not enough free space for the crane mast/arm or the potential construction area of the 
  crane intersects a protected area from another player, the crane will not be build.

* Right-click the crane switch block to place the hook in front of the crane mast

* Enter the hook by right-clicking the hook

* "Fly" within the working area (height, width) by means of the (default) controls
  - Move mouse: Look around
  - W, A, S, D: Move
  - Space: move up
  - Shift: move down

* Leave the hook by right-clicking the hook or right-clicking the crane switch node

* To remove the crane, destroy the base block.
  **Hint:** The construction area of the crane will also be removed. In order to protect your building again, 
  you have to use the normal chat commands.


## To Do:
- output the crane hook coordinates in the HUD relative to a predefined reference position

# Dependencies
- default
- areas (optional)

# License
Copyright (C) 2017 Joachim Stolberg
Code: Licensed under the GNU LGPL version 2.1 or later. See LICENSE.txt and http://www.gnu.org/licenses/lgpl-2.1.txt
Textures: CC0

