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

--[[
-- We add the 'tallbird' tag to smallbirds and teenbirds so that they won't get attacked by tallbirds.
-- This is the least obtrusive method I've found, since the alternatives required changing a local function in the Tallbird's brain.
--]]
local function smallish_postinit(inst)
	inst:AddTag("tallbird")
	inst:DoTaskInTime(0, ApplyWildBirdLogic)
	inst:ListenForEvent("onremove", function(inst)
		if inst:IsValid() and inst.components.follower then
			inst.components.follower:StopFollowing()
		end
	end)
	return inst
end

AddPostInit('prefab')({'smallbird', 'teenbird'})(smallish_postinit)


local function GetSgOnEnterPatcher(state_namelist)
	return function(sg)
		for _, state_name in ipairs(state_namelist) do
			local state = assert( sg.states[state_name], "Stategraph " .. sg.name .. " has no state " .. state_name .. "!")

			local old_onenter = state.onenter
			state.onenter = function(inst)
				if inst:IsAsleep() then
					-- We delay the task so we don't go to another state before the initial
					-- GoToState() call ended.
					inst:DoTaskInTime(0, function(inst)
						inst:PushEvent("animover")
					end)
				elseif old_onenter then
					old_onenter(inst)
				end
			end
		end
	end
end


AddPostInit('stategraph')('smallbird')( GetSgOnEnterPatcher {"hatch", "growup"} )
AddPostInit('stategraph')('tallbird')( GetSgOnEnterPatcher {"growup"} )
