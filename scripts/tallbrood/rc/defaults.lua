------
---- [Default configurations]
----
---- Modify rc.lua instead.
------


return function()
	---
	--- All measures of time are in seconds.
	--- All distances are measured in meters (a wall's side is 1 meter long, a tile's side is 4 meters long).
	---
	
	--[[
	-- The time configurations are parameterized in terms of the game tuning entries.
	--
	-- TUNING.TOTAL_DAY_TIME means the length of a day (8 minutes, by default).
	--
	-- TUNING.SEG_TIME means the length of a day segment (1/16 of a day or 30 seconds, by default).
	--
	-- TUNING.SMALLBIRD_HATCH_TIME means how long a player grown Tallbird Egg takes to hatch (3 in-game days, by default).
	--]]
	
	-- How long it takes for a nestless Tallbird to create a new nest.
		TALLBIRD_NESTING_DELAY = 7*TUNING.TOTAL_DAY_TIME
	
	-- How long it takes for a Tallbird to lay an egg in an empty nest.
		TALLBIRD_LAYING_DELAY = 35*TUNING.SEG_TIME
	
	-- Prevents a Tallbird from laying an egg if it's currently raising a Smallbird.
	TALLBIRD_DONT_LAY_IF_SMALL_CHILDREN = true
	
	-- Maximum distance between a Tallbird and its nest for an egg to be laid (only matters for offscreen laying).
	TALLBIRD_LAYING_MAX_DISTANCE = 16
	
	-- How long it takes for a wild Tallbird Egg to hatch.
		WILD_SMALLBIRD_HATCH_TIME = 2*TUNING.SMALLBIRD_HATCH_TIME
	
	-- How long it takes for a Tallbird to spawn from a nest.
	TALLBIRD_SPAWN_DELAY = 5*TUNING.TOTAL_DAY_TIME
	
	-- Minimum distance between Tallbird nests.
	TALLBIRD_MIN_NEST_DISTANCE = 4
	
	-- Maximum distance to search for a valid point to put a nest on (only matters for offscreen spawning).
	TALLBIRD_MAX_NEST_DISTANCE = 16
	
	
	--[[
	-- Here I list some default game configurations for ease of editing.
	--]]
	
	-- How long it takes for a Smallbird to grow into a Teenbird.
	TUNING.SMALLBIRD_GROW_TIME = TUNING.SMALLBIRD_GROW_TIME
	
	-- How long it takes for a Teenbird to grow into a Tallbird.
	TUNING.TEENBIRD_GROW_TIME = TUNING.TEENBIRD_GROW_TIME
		
	
	-- Turn on debugging.
	DEBUG = false
end
