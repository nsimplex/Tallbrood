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
local modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.')
module( ..., require(modname .. '.booter') )
--@@END ENVIRONMENT BOOTUP


local SearchSpace = wickerrequire 'lib.searchspace'

GLOBAL.tallbrood = GLOBAL.tallbrood or {}
local tallbrood = GLOBAL.tallbrood

function tallbrood.SuitUp()
	local p = GLOBAL.GetPlayer()
	p.components.health:SetInvincible(true)
	p.HUD.minimap.MiniMap:ShowArea(0, 0, 0, 2^18)
	p.components.locomotor.runspeed = 16
end

local DEFAULT_RADIUS = 2^14

function tallbrood.FindAllNests(radius)
	radius = radius or DEFAULT_RADIUS
	local center = GLOBAL.GetPlayer():GetPosition()
	return SearchSpace.FindAllEntities(center, radius, nil, {modname .. '_tallbirdnest'})
end

function tallbrood.FindAllBirds(prefab, radius)
	radius = radius or DEFAULT_RADIUS
	local center = GLOBAL.GetPlayer():GetPosition()
	return SearchSpace.FindAllEntities(center, radius, function(v)
		return not v:HasTag('player') and (not prefab or v.prefab == prefab)
	end, {'tallbird'})
end

function tallbrood.RegenAllNests(radius)
	for _, v in ipairs(tallbrood.FindAllNests(radius)) do
		if v.components.pickable then
			v.components.pickable:Regen()
		end
	end
end

tallbrood.FillAllNests = tallbrood.RegenAllNests

function tallbrood.HatchAllEggs(radius)
	for _, v in ipairs(tallbrood.FindAllNests(radius)) do
		if v.components.pickable and v.components.pickable:CanBePicked() and v.components.growable then
			v.components.growable:SetStage(1)
			v.components.growable:SetStage(2)
		end
	end
end

function tallbrood.GrowAllBirds(radius)
	for _, bird in ipairs( tallbrood.FindAllBirds(nil, radius) ) do
		if bird.components.growable then
			bird.components.growable:DoGrowth()
		end
	end
end

function tallbrood.MakeAllNests(radius)
	for _, tall in ipairs( tallbrood.FindAllBirds('tallbird', radius) ) do
		if tall.components.nester and tall.components.nester:IsNesting() then
			tall.components.nester:MakeNest()
		end
	end
end

tallbrood.SpawnAllNests = tallbrood.MakeAllNests

function tallbrood.RemoveAllNests(radius)
	for _, nest in ipairs( tallbrood.FindAllNests(radius) ) do
		nest:Remove()
	end
end

function tallbrood.KillAllBirds(radius)
	for _, bird in ipairs( tallbrood.FindAllBirds(nil, radius) ) do
		if bird.components.health then
			bird.components.health:SetPercent(0)
		else
			bird:Remove()
		end
	end
end

function tallbrood.RebootAllBirds(radius)
	for _, bird in ipairs( tallbrood.FindAllBirds('tallbird', radius) ) do
		if bird.components.nester then
			bird.components.nester:Reboot()
		end
	end
end

tallbrood.RemoveAllBirds = tallbrood.KillAllBirds
