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

local GetWorld = GetWorld
local GROUND = GROUND
local TheSim = TheSim
local SpawnPrefab = SpawnPrefab

local GetGroundTypeAtPosition = GetGroundTypeAtPosition


--@@ENVIRONMENT BOOTUP
local modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(modname .. '.booter') )
--@@END ENVIRONMENT BOOTUP


local Lambda = wickerrequire 'paradigms.functional'
local Logic = wickerrequire 'paradigms.logic'

local Pred = wickerrequire 'lib.predicates'
local SearchSpace = wickerrequire 'lib.searchspace'

local myutils = wickerrequire 'utils'


function CanSpawnTallbirdNestAtPoint(pt)
	local min_spacing = 2

	local tile = GetGroundTypeAtPosition(pt)
	if tile ~= GROUND.ROCKY and tile ~= GROUND.DIRT then
		return false
	end

	if SearchSpace.FindSomeEntity(pt, min_spacing, function(v)
		return v:HasTag("blocker")
	end) then
		return false
	end

	return SearchSpace.FindSomeEntity(pt, TheMod:GetConfig().TALLBIRD_MIN_NEST_DISTANCE, nil, {modname .. '_tallbirdnest'}) and false or true
end

-- Finds the "best" nest to attach a Smallbird or Teenbird to.
function FindBestNest(bird, radius)
	radius = radius or 2^9

	local prefabname = 'tallbirdnest'
	local basic_tag = modname .. '_' .. prefabname
	local tags = {basic_tag}


	-- First we try to look at the leader.
	if bird.components.follower then
		local leader = bird.components.follower.leader
		if leader and leader.components.homeseeker then
			local home = leader.components.homeseeker.home
			if
				home and home:IsValid() and not home:IsInLimbo()
				and home.prefab == prefabname and home:HasTag(basic_tag)
			then
				return home
			end
		end
	end


	local nests = SearchSpace.FindAllEntities(bird:GetPosition(), radius, function(v)
		return v.prefab == prefabname
	end, tags)

	return myutils.algo.LeastElementsOf(nests, 1, function(a, b)
		return bird:GetDistanceSqToInst(a) < bird:GetDistanceSqToInst(b)
	end)[1]
end

-- Attaches a Smallbird or Teenbird to a nest.
function AttachBirdToNest(bird, nest)
	assert( bird.components.follower )

	if bird.userfunctions then
		-- *insert evil laugh*
		bird.userfunctions.FollowPlayer = Lambda.Nil
	end

	if bird.components.hunger then
		bird.components.hunger:SetRate(0)
		bird.components.hunger:SetPercent(1)
	end

	bird:RemoveTag("companion")

	if not nest then
		local leader = bird.components.follower.leader
		if leader then
			if leader.components.homeseeker then
				nest = leader.components.homeseeker.home
				if nest and nest.prefab ~= "tallbirdnest" then
					nest = nil
				end
			end
		else
			nest = FindBestNest( bird )
		end

		if not nest then
			return bird, bird.components.follower.leader
		end
	end

	assert( nest.components.childspawner )
	assert( Pred.IsTable( nest.components.childspawner.childrenoutside ) )

	-- Custom event. Pushed through postinit imbued logic.
	bird:ListenForEvent(modname .. "_onspawn", function(nest, data)
		if
			data.child
			and bird.components.follower and not bird.components.follower.leader
			and data.child.components.leader
		then
			bird.components.follower:SetLeader(data.child)
		end
	end, nest)

	if not bird.components.follower.leader then
		for _,v in pairs(nest.components.childspawner.childrenoutside) do
			if v.components.leader then
				bird.components.follower:SetLeader(v)
				break
			end
		end
	else
		assert( bird.components.follower.leader.components.homeseeker and bird.components.follower.leader.components.homeseeker.home == nest )
	end

	if nest.components.tallhatchery then
		nest.components.tallhatchery:TryStart()
	end

	return bird, bird.components.follower.leader
end

-- inst should be a tallbird nest.
function HatchWildEggFromNest(inst)
	if not inst.components.pickable or not inst.components.pickable:CanBePicked() then return end
	
	TheMod:DebugNotify('HatchWildEgg([', inst, '])')

	local pt
	if not inst:IsAsleep() then
		pt = inst:GetPosition()
	else
		-- So that the spawned tallbird will nest properly if asleep until then.
		local A = SearchSpace.Annulus(inst:GetPosition(), TheMod:GetConfig().TALLBIRD_MIN_NEST_DISTANCE, TheMod:GetConfig().TALLBIRD_MAX_NEST_DISTANCE)
		pt = A:Search( Pred.LambdaAnd(Pred.IsValidPoint, CanSpawnTallbirdNestAtPoint) )
	end

	if not pt then
		return
	end


	local smallbird = SpawnPrefab( "smallbird" )
	if not smallbird then return end

	TheMod:DebugNotify('Hatching [', smallbird, ']')

	smallbird.Transform:SetPosition(pt.x, pt.y, pt.z)

	if inst:IsAsleep() then
		TheMod:DebugNotify('[', smallbird, '] hatched. Attaching to [', inst, ']')
		return AttachBirdToNest(smallbird, inst)
	else
		smallbird.sg:GoToState("hatch")

		myutils.game.ListenForEventOnce(smallbird, "animover", function(smallbird)
			-- This is just to ensure this runs after the GoToState("idle") on onexit().
			smallbird:DoTaskInTime(0, function(smallbird)
				TheMod:DebugNotify('[', smallbird, '] hatched. Attaching to [', inst, ']')
				AttachBirdToNest(smallbird, inst)
			end)
		end)

		inst.components.pickable:Pick()

		return smallbird
	end
end

return _M
