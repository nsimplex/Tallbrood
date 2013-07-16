---
--- All measures of time are in seconds.
--- All distances are measured in meters (a wall's side is 1 meter long, a tile's side is 4 meters long).
---


-- How long it takes for a wild Tallbird Egg to hatch.
--@example WILD_SMALLBIRD_HATCH_TIME = 1.25*TUNING.SMALLBIRD_HATCH_TIME
WILD_SMALLBIRD_HATCH_TIME = 2*TUNING.SMALLBIRD_HATCH_TIME

-- How long it takes for a nestless Tallbird to create a new nest.
TALLBIRD_NESTING_DELAY = 7*TUNING.TOTAL_DAY_TIME

-- Minimum distance between Tallbird nests.
TALLBIRD_MIN_NEST_DISTANCE = 4

-- Maximum distance to search for a valid point to put a nest on (this only matters for offscreen spawning).
TALLBIRD_MAX_NEST_DISTANCE = 16
--@stopreading


-- Turn on debugging.
DEBUG = false
