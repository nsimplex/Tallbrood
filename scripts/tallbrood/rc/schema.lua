--[[
Copyright (C) 2013  simplex

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--

--@@ENVIRONMENT BOOTUP
local modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(modname .. '.booter') )
--@@END ENVIRONMENT BOOTUP

local Pred = wickerrequire 'lib.predicates'


TALLBIRD_NESTING_DELAY = Pred.IsPositiveNumber

TALLBIRD_LAYING_DELAY = Pred.IsPositiveNumber

TALLBIRD_DONT_LAY_IF_SMALL_CHILDREN = Pred.IsBoolean

TALLBIRD_DONT_LAY_IF_TEEN_CHILDREN = Pred.IsBoolean

TALLBIRD_LAYING_MAX_DISTANCE = Pred.IsPositiveNumber

WILD_SMALLBIRD_HATCH_TIME = Pred.IsPositiveNumber

TALLBIRD_SPAWN_DELAY = Pred.IsPositiveNumber

TALLBIRD_MIN_NEST_DISTANCE = Pred.IsPositiveNumber

TALLBIRD_MAX_NEST_DISTANCE = Pred.IsPositiveNumber

DEBUG = Pred.IsBoolean


return _M
