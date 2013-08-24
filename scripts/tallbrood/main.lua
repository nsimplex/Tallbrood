-----
--[[ Tallbrood ]] VERSION="2.1"
--
-- Last updated: 2013-08-24
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

The file scripts/tallbrood/prefabs/tallbirdnest.lua is based on code from Klei
Entertainment's Don't Starve and is not covered under the terms of this license.
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


modrequire 'postinits.smallish'
modrequire 'postinits.tall'
modrequire 'postinits.nest'


local function inst_tagger(inst)
	inst:AddTag(GetModname() .. '_' .. tostring(inst.prefab))
	return inst
end

AddPrefabPostInit({'smallbird', 'teenbird', 'tallbird', 'tallbirdnest'}, inst_tagger)


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
