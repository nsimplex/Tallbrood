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

The file favicon/tallbrood.tex is based on textures from Klei Entertainment's
Don't Starve and is not covered under the terms of this license.
]]--

--@@ENVIRONMENT BOOTUP
local modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(modname .. '.booter') )
--@@END ENVIRONMENT BOOTUP

-- This just enables syntax conveniences.
BindTheMod()


local Lambda = wickerrequire 'paradigms.functional'
local Logic = wickerrequire 'paradigms.logic'

local Pred = wickerrequire 'lib.predicates'

local TallbirdLogic = modrequire 'tallbird_logic'

local EventChain = wickerrequire 'gadgets.eventchain'


function tallbird_postinit(inst)
	DebugSay('Initializing [', inst, ']')

	inst:AddComponent("leader")

	inst:AddComponent("nester")

	inst.components.nester:SetNestPrefab("tallbirdnest")
	inst.components.nester:SetFullDelay( GetConfig().TALLBIRD_NESTING_DELAY )

	-- Defines the chain of events that must happen if the entity is awake so that a nest will be spawned.
	inst.components.nester:SetEntityAwakeEventChain( EventChain('gotosleep', 'animover') )

	inst.components.nester:SetSearchRadius( GetConfig().TALLBIRD_MAX_NEST_DISTANCE )

	inst.components.nester:SetNestingTestFn(TallbirdLogic.CanSpawnTallbirdNestAtPoint)

	inst.components.nester:SetOnSpawnNestFn(function(inst, nest)
		if nest.components.pickable then
			nest.components.pickable:Pick()
		end
	end)
end

TheMod:AddPostInit('prefab')('tallbird')(tallbird_postinit)
