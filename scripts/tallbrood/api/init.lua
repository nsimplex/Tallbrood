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

local assert = assert
local error = error
local table = table
local pairs = pairs
local ipairs = ipairs

--@@ENVIRONMENT BOOTUP
local modname = assert( (assert(..., 'This file should be loaded through require/modrequire/pkgrequire.')):match('^[%a_][%w_%s]*') , 'Invalid path.')
local require = require
module(...)
require(modname .. '.api.core')()
--@@END ENVIRONMENT BOOTUP

local core = assert( assert( TheCore )() )
core.TheCore = nil
TheCore = nil

AssertEnvironmentValidity(_M)

return function(env, mainname)
	AssertEnvironmentValidity(_M)
	

	mainname = mainname or 'main'

	core.InjectNonPrivatesIntoTableIf(function(k, v)
		local kl = k:lower()
		return not core[k] and v ~= env and not kl:match('postinit') and not kl:match('modname')
	end, core, pairs(env))

	assert( modinfo, 'The mod environment has no modinfo!' )
	assert( MODROOT, 'The mod environment has no MODROOT!' )

	core.modenv = env

	core.Modname = core.modinfo.name or modname


	AssertEnvironmentValidity(_M)


	local Configurable = modrequire 'gadgets.configurable'
	Configurable.SetMasterKey( GetModKey() )

	local mod_builder = GetTheMod()
	assert( type(mod_builder) == "function" )
	local TheMod = mod_builder(env, mainname)
	local TheModConcept = GetTheMod()
	assert( TheMod ~= TheModConcept )
	assert( TheMod == TheModConcept.TheMod )

	local ModCheck = assert( TheModConcept.ModCheck )

	TheMod.modname = GetModname()
	TheMod.Modname = Modname
	TheMod.version = modinfo.version
	TheMod.author = modinfo.author

	TheMod.modinfo = modinfo

	core.TheMod = TheMod
	core.TheModConcept = TheModConcept


	AssertEnvironmentValidity(_M)


	Configurable.LoadConfigurationFunction(modrequire('rc.defaults'), 'the default configuration file')
	Configurable.LoadConfigurationFile 'rc.lua'


	AssertEnvironmentValidity(_M)

	return TheMod
end
