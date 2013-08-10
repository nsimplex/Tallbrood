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


-------------------------------------------------------------------------------
local ConditionalTasker = wickerrequire 'protocomponents.conditionaltasker'

local AutoEggHatcher = ConditionalTasker:Instantiate("AutoEggHatcher")

AutoEggHatcher:SetFullDelay(GetConfig("WILD_SMALLBIRD_HATCH_TIME"))

AutoEggHatcher:SetConditionFn(function(inst)
	return
		Pred.IsOk(inst)
		and inst.components.childspawner
		and inst.components.childspawner:CountChildrenOutside() > 0
		and inst.components.pickable
		and inst.components.pickable:CanBePicked()
end)

AutoEggHatcher:SetOnCompleteFn(function(inst)
	TallbirdLogic.HatchWildEggFromNest(inst)
end)
-------------------------------------------------------------------------------

local function tallbirdnest_postinit(inst)
	DebugSay('Initializing [', inst, ']')

	local spwner = inst.components.childspawner
	if spwner then
		local oldonspawned = spwner.onspawned
		spwner:SetSpawnedFn(function(inst, child)
			inst:PushEvent(modname .. "_onspawn", {child = child})
			if oldonspawned then
				oldonspawned(inst, child)
			end
		end)
	elseif Debug() then
		Say('[', inst '] is not a ChildSpawner!')
	end

	local pick = inst.components.pickable
	if pick then
		inst:AddComponent("autoegghatcher")

		local oldonregenfn = pick.onregenfn
		local oldonpickedfn = pick.onpickedfn
		local oldmakeemptyfn = pick.makeemptyfn

		pick:SetOnRegenFn(function(inst, ...)
			AutoEggHatcher.TryStarter(inst)
			if oldonregenfn then
				return oldonregenfn(inst, ...)
			end
		end)
		
		pick:SetOnPickedFn(function(inst, ...)
			inst:DoTaskInTime(0, AutoEggHatcher.TryStarter)
			if oldonpickedfn then
				return oldonpickedfn(inst, ...)
			end
		end)

		pick:SetMakeEmptyFn(function(inst, ...)
			inst:DoTaskInTime(0, AutoEggHatcher.TryStarter)
			if oldmakeemptyfn then
				return oldmakeemptyfn(inst, ...)
			end
		end)
	elseif Debug() then
		Say('[', inst, '] is not Pickable!')
	end
end

AddPostInit('prefab', 'tallbirdnest', tallbirdnest_postinit)
