-----
--[[ Tallbrood ]] VERSION="2.0"
--
-- Last updated: 2013-08-09
-----

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
local modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.')
module( ..., require(modname .. '.booter') )
--@@END ENVIRONMENT BOOTUP

-- This just enables syntax conveniences.
BindTheMod()


local Lambda = wickerrequire 'paradigms.functional'
local Logic = wickerrequire 'paradigms.logic'

local Pred = wickerrequire 'lib.predicates'

local myutils = wickerrequire 'utils'

local EventChain = wickerrequire 'gadgets.eventchain'


local TallbirdLogic = modrequire 'tallbird_logic'


local function ApplyWildBirdLogic( bird )
	if bird.sg.currentstate.name == "hatch" then
		return
	end

	if not ( bird.components.follower.leader and bird.components.follower.leader:HasTag('player') ) then
		DebugSay('Applying wild bird logic to [', bird, ']')
		TallbirdLogic.AttachBirdToNest( bird )
	elseif Debug() then
		Say('[', bird, '] is not wild.')
	end
end

local function inst_tagger(inst)
	inst:AddTag(GetModname() .. '_' .. tostring(inst.prefab))
	return inst
end

AddPrefabPostInit({'smallbird', 'teenbird', 'tallbird', 'tallbirdnest'}, inst_tagger)


--[[
-- We add the 'tallbird' tag to smallbirds and teenbirds so that they won't get attacked by tallbirds.
-- This is the least obtrusive method I've found, since the alternatives required changing a local function in the Tallbird's brain.
--]]
local function smallish_postinit(inst)
	inst:AddTag("tallbird")
	inst:DoTaskInTime(0, ApplyWildBirdLogic)
	return inst
end

AddPostInit('prefab')({'smallbird', 'teenbird'})(smallish_postinit)


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
		assert(not inst.components.growable)
		inst:AddComponent("growable")
		inst.components.growable.stages = {
			{
				name="egg",
				time = Lambda.Constant(GetConfig().WILD_SMALLBIRD_HATCH_TIME),
			},
			{
				name="hatchingegg",
				fn = function(nest)
					local hatched = false

					if nest:IsValid() and not nest:IsInLimbo() and nest.components.childspawner and nest.components.childspawner:CountChildrenOutside() > 0 then
						if nest.components.pickable and nest.components.pickable:CanBePicked() then
							hatched = TallbirdLogic.HatchWildEggFromNest(nest)
						end
					end

					nest.components.growable:SetStage(1)

					if hatched then
						nest.components.growable:StopGrowing()
					else
						nest.components.growable:StartGrowing()
					end
				end,
			},
		}
		inst.components.growable:SetStage(1)

		local oldonregenfn = pick.onregenfn
		local oldonpickedfn = pick.onpickedfn
		local oldmakeemptyfn = pick.makeemptyfn

		pick:SetOnRegenFn(function(inst, ...)
			if inst.components.growable and not inst.components.growable.targettime then
				inst.components.growable:SetStage(1)
				inst.components.growable:StartGrowing()
				DebugSay('[', inst, ']\'s egg started to grow.')
			end
			if oldonregenfn then
				return oldonregenfn(inst, ...)
			end
		end)
		
		pick:SetOnPickedFn(function(inst, ...)
			if inst.components.growable then
				inst.components.growable:StopGrowing()
				inst.components.growable:SetStage(1)
			end
			if oldonpickedfn then
				return oldonpickedfn(inst, ...)
			end
		end)

		pick:SetMakeEmptyFn(function(inst, ...)
			if inst.components.growable then
				inst.components.growable:StopGrowing()
				inst.components.growable:SetStage(1)
			end
			if oldmakeemptyfn then
				return oldmakeemptyfn(inst, ...)
			end
		end)

		inst.components.growable:StopGrowing()

		inst:DoTaskInTime(0, function(inst)
			if inst.components.pickable and inst.components.growable then
				local time = inst.components.growable.targettime
				if time then
					time = time - GetTime()
				end
				inst.components.growable:StopGrowing()
				if inst.components.pickable:CanBePicked() then
					inst.components.growable:StartGrowing(time)
				end
			end
		end)

		inst:ListenForEvent("daycomplete", function(world)
			if inst:IsValid() and not inst:IsInLimbo() and inst.components.growable and inst.components.growable.targettime then
				local dt = 0.35*TUNING.TOTAL_DAY_TIME*math.random()
				world:DoTaskInTime(dt, function()
					if inst:IsValid() and not inst:IsInLimbo() and inst.components.growable then
						local g = inst.components.growable
						if g.targettime and g.targettime <= GetTime() then
							g:DoGrowth()
						end
					end
				end)
			end
		end, GetWorld())
	elseif Debug() then
		Say('[', inst, '] is not Pickable!')
	end
end

AddPostInit('prefab', 'tallbirdnest', tallbirdnest_postinit)


function tallbird_postinit(inst)
	DebugSay('Initializing [', inst, ']')

	inst:AddComponent("leader")

	inst:AddComponent("nester")

	inst.components.nester:SetNestPrefab("tallbirdnest")
	inst.components.nester:SetFullNestDelay( GetConfig().TALLBIRD_NESTING_DELAY )

	-- Defines the chain of events that must happen if the entity is awake so that a nest will be spawned.
	inst.components.nester:SetEntityAwakeEventChain( EventChain('gotosleep', 'animover') )

	inst.components.nester:SetSearchRadius( GetConfig().TALLBIRD_MAX_NEST_DISTANCE )

	inst.components.nester:SetNestingTestFn(TallbirdLogic.CanSpawnTallbirdNestAtPoint)

	inst.components.nester:SetOnSpawnNestFn(function(inst, nest)
		if nest.components.pickable then
			nest.components.pickable:Pick()
		end
	end)

	inst:DoTaskInTime(0, function() inst.components.nester:StartNesting() end)
end

TheMod:AddPostInit('prefab')('tallbird')(tallbird_postinit)


local function greeter(inst)
	print('Thank you, ' .. (STRINGS.NAMES[inst.prefab:upper()] or "player") .. ', for using ' .. Modname .. ' mod v' .. modinfo.version .. '.')
	print(Modname .. ' is free software, licensed under the terms of the GNU GPLv2.')
end

TheMod:AddSimPostInit(greeter)

return function(...)
	assert( TheMod )

	if Debug() then
		modrequire 'debugtools'
		AddSimPostInit(function(inst)
			inst:AddTag("tallbird")
		end)
	end
end
