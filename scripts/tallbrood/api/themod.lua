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

local package = package

--@@ENVIRONMENT BOOTUP
local modname = assert( (assert(..., 'This file should be loaded through require/modrequire/pkgrequire.')):match('^[%a_][%w_%s]*') , 'Invalid path.')
local require = require
module(...)
require(modname .. '.api.core')()
--@@END ENVIRONMENT BOOTUP

local Lambda = modrequire 'paradigms.functional'
local Iterator = Lambda.iterator
local Logic = modrequire 'paradigms.logic'

local Pred = modrequire 'lib.predicates'

local Tree = modrequire 'utils.table.tree'
local Debuggable = modrequire 'gadgets.debuggable'

function ModCheck(self)
	assert( Pred.IsMod(self), "Don't forget to use ':'!" )
end

local Mod = Class(Debuggable, function(self, env, mainname)
	Debuggable._ctor(self, 'TheMod', false)

	self.postinit = Tree()

	local postinit_specs = {}

	for k, v in pairs(env) do
		if type(k) == 'string' then
			local id = k:match('^Add(.-)PostInit$')
			if id then
				postinit_specs[id:lower()] = {
					id = id,
					full_name = k,
					fn = v,
				}
			end
		end
	end
	
	for id, spec in pairs(postinit_specs) do
		self.postinit[id]()
		self[spec.full_name] = function(self, ...)
			return self:AddPostInit(id)(...)
		end
	end

	local function do_main(...)
		local main
		local M = modrequire(mainname)
		if type(M) == "function" then
			main = M
		elseif type(M) == "table" then
			main = M.main
			if not Lambda.IsFunctional( main ) then
				main = M[mainname]
				if not Lambda.IsFunctional( main ) then
					main = Lambda.Find(
						function(v, k) return Lambda.IsFunctional(v) and Pred.IsString(k) and k:lower() == 'main' end,
						pairs( M )
					)
					if not Lambda.IsFunctional( main ) then
						local lowmain = mainname:lower()
						main = Lambda.Find(
							function(v, k) return Lambda.IsFunctional(v) and Pred.IsString(k) and k:lower() == lowmain end,
							pairs( M )
						)
					end
				end
			end
		end

		if not Lambda.IsFunctional( main ) then
			self:Notify("Unable to find a suitable main function from the return value of modrequire('" .. mainname .. "').")
			return
		end

		return main(...)
	end

	function self:Run(...)
		ModCheck(self)

		do_main(...)

		for id, spec in pairs(postinit_specs) do
			local postinit_setter = spec.fn

			local f, s, var = Iterator.Filter(
				function(data, node)
					return Tree.IsTree(node) and Logic.ThereExists(Tree.IsLeaf, ipairs(node))
				end,
				Tree.dfs.Iterator(self.postinit[id])
			)

			for data, node in f, s, var do
				assert( Tree.IsTree(node) )

				local Args = Lambda.CompactlyMap(
					function(branch_node)
						if type(branch_node.k) == "string" then
							return branch_node.k
						end
					end,
					ipairs(data.branch)
				)

				local callbacks = Lambda.CompactlyFilter( Lambda.IsFunctional, ipairs(node) )

				table.insert(Args, Lambda.FunctionList(ipairs(callbacks)))
				
				if self:Debug() then
					local ArgNames = Lambda.CompactlyMap(function(arg)
						if Pred.IsWordable(arg) then
							return '"' .. tostring(arg) .. '"'
						else
							return '[' .. tostring(arg) .. ']'
						end
					end, ipairs(Args))
					self:Notify('Calling ' .. spec.full_name .. '(' .. table.concat(ArgNames, ', ') .. ')')
					self:Notify(#callbacks, ' functions have been smashed into one.')
				end

				postinit_setter( unpack(Args) )
			end
		end

		self.Run = Lambda.Error('TheMod:Run() can only be called once!')
		self.AddPostInit = Lambda.Error("You can't setup a postinit callback after TheMod:Run() has ended!")

		return self
	end
end)

Pred.IsMod = Pred.IsInstanceOf(Mod)

local function Mod_PostInitAdder(self, subroot, reached_leaf)
	local function parameter_iterator(x, ...)
		if x == nil then
			return Mod_PostInitAdder(self, subroot, reached_leaf)
		end

		assert( not reached_leaf or Lambda.IsFunctional(x), "Function expected as a postinit setup argument." )

		if Lambda.IsFunctional(x) then
			assert( not Tree.IsRoot(subroot), "No postinit setup function specified!")
			table.insert(subroot, x)
			reached_leaf = true
		elseif type(x) == "table" then
			-- We create new closures that leave our current upvalues alone.
			local branches = Lambda.CompactlyMap(function(v, i) return Mod_PostInitAdder(self, subroot, reached_leaf)(v) end, ipairs(x))
			
			local function multiplier(...)
				for i, v in ipairs(branches) do
					branches[i] = v(...)
				end
				return multiplier
			end

			return multiplier(...)
		else
			assert( Pred.IsWordable(x), "Invalid argument to postinit setup." )
			x = tostring(x)
			-- We normalize the postinit id (i.e., 'Sim', 'Prefab') to lowercase.
			if Tree.IsRoot(subroot) then
				self:DebugNotify("Normalizing `", x, "'")
				x = x:lower()
			end
			subroot = subroot[x]
		end

		return parameter_iterator(...)
	end

	return parameter_iterator
end


function Mod:AddPostInit(...)
	ModCheck(self)
	return Mod_PostInitAdder(self, self.postinit)(...)
end


return function(env, mainname)
	assert( type(env) == "table" )
	assert( type(mainname) == "string" )

	local TheMod = Mod(env, mainname)

	_M.TheMod = TheMod

	Lambda.ConceptualizeSingletonObject( TheMod, _M )

	package.loaded[_NAME] = _M

	return TheMod
end
