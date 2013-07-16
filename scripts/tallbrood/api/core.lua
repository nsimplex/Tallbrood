--[[
-- Avoid tail calls like hell.
--]]

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

--@@NO ENVIRONMENT BOOTUP
local modname = assert( (assert(..., 'This file should be loaded through require/modrequire/pkgrequire.')):match('^[%a_][%w_%s]*') , 'Invalid path.')

local assert = assert
local error = assert( error )

local rawget = assert( rawget )
local rawset = assert( rawset )
local getfenv = assert( getfenv )
local pairs = assert( pairs )
local ipairs = assert( ipairs )
local table = assert( table )
local tostring = assert( tostring )
local math = math

-- Raw check, disregarding metamethods.
local function var_exists(name)
	return rawget(getfenv(), name) ~= nil
end

local _G = (var_exists('_G') and _G) or GLOBAL
assert( _G )


local require = require
module(...)

local _M = _M

_M.require = assert( require )
_M.assert = assert( assert )
_M.error = assert( error )
_M.print = assert( _G.print )
_M.type = assert( _G.type )
_M.table = assert( _G.table )
_M.ipairs = assert( _G.ipairs )
_M.pairs = assert( _G.pairs )
_M.next = assert( _G.next )
_M.unpack = assert( _G.unpack )
_M.select = assert( _G.select )
_M.rawset = assert( _G.rawset )
_M.rawget = assert( _G.rawget )
_M.getmetatable = assert( _G.getmetatable )
_M.setmetatable = assert( _G.setmetatable )
_M.string = assert( _G.string )
_M.tostring = assert( _G.tostring )
_M.tonumber = assert( _G.tonumber )
_M.math = assert( _G.math )
_M.getfenv = assert( _G.getfenv )
_M.setfenv = assert( _G.setfenv )
_M.pcall = assert( _G.pcall )
_M.debug = {}
_M.debug.getinfo = assert( _G.debug.getinfo )
_M.debug.traceback = assert( _G.debug.traceback )
_M.os = {}
_M.os.time = assert( _G.os.time )
_M.os.difftime = assert( _G.os.difftime )
_M.os.date = assert( _G.os.date )
_M.io = {}

_M.Class = assert( _G.Class )
_M.EntityScript = assert( _G.EntityScript )
_M.Vector3 = assert( _G.Vector3 )
_M.Point = assert( _G.Point )

_M.TUNING = assert( _G.TUNING )
_M.STRINGS = assert( _G.STRINGS )

_M.GetTime = assert( _G.GetTime )
_M.GetPlayer = assert( _G.GetPlayer )
_M.GetWorld = assert( _G.GetWorld )
_M.GetClock = assert( _G.GetClock )
_M.GetSeasonManager = assert( _G.GetSeasonManager )
_M.SpawnPrefab = assert( _G.SpawnPrefab )
_M.DebugSpawn = assert( _G.DebugSpawn )

-- I don't like importing the global environment, but for backwards compatibility...
_M._G = _G
_M.GLOBAL = _G


-- Returns a unique key.
GetModKey = (function()
	local k = {}
	return function()
		return k
	end
end)()
local GetModKey = GetModKey

function GetModname()
	return modname
end
local GetModName = GetModname


function AssertEnvironmentValidity(env)
	assert( env.GetModname == nil or env.GetModname() == GetModname(), env._NAME )
	assert( env.modname == nil or env.modname == GetModname(), env._NAME )
	assert( env.GetModKey == nil or env.GetModKey() == GetModKey(), env._NAME )
	assert( env.TheMod == nil or _M.TheMod == nil or env.TheMod == _M.TheMod, env._NAME )
end


local loader_metadata = {}
loader_metadata[require] = {name = 'require', category = 'Module'}

loader_metadata[function(t) return t end] = {name = 'GetTable', category = 'Table'}

-- This should be hidden as soon as possible.
function TheCore()
	return _M
end
local TheCore = TheCore
loader_metadata[TheCore] = {name = 'TheCore', category = 'TheCore'}

function modrequire(name)
	local M = require(GetModname() .. '.' .. tostring(name))
	if type(M) == "table" then
		AssertEnvironmentValidity( M )
	end
	return M
end
local modrequire = modrequire
loader_metadata[modrequire] = {name = 'modrequire', category = 'ModModule'}

function GetTheMod()
	local M = modrequire 'api.themod'
	return M
end
local GetTheMod = GetTheMod
loader_metadata[GetTheMod] = {name = 'GetTheMod', category = 'TheMod'}

function InjectNonPrivatesIntoTableIf(p, t, f, s, var)
	for k, v in f, s, var do
		if type(k) == "string" and not k:match('^_') then
			if p(k, v) then
				t[k] = v
			end
		end
	end
	return t
end
local InjectNonPrivatesIntoTableIf = InjectNonPrivatesIntoTableIf

function InjectNonPrivatesIntoTable(t, f, s, var)
	t = InjectNonPrivatesIntoTableIf(function() return true end, t, f, s, var)
	return t
end
local InjectNonPrivatesIntoTable = InjectNonPrivatesIntoTable

local function trace_error(msg)
	return error(msg .. "\n" .. debug.traceback())
end

-- Returns the index (relative to the calling function) in the Lua stack of the last function with a different environment than the outer function.
-- It uses the Lua side convention for indexes, which are nonnegative and count from top to bottom.
--
-- It defaults to 2 because it shouldn't be used directly from outside this module.
--
-- We should always reach the global environment, which prevents an infinite loop.
-- Ignoring errors is needed to pass over tail calls (which trigger them).
--
-- This could be written much more cleanly and robustly at the C/C++ side.
-- The real setback is that Lua doesn't tell us what the stack size is.
local function GetNextEnvironmentThreshold(i)
	assert( i == nil or (type(i) == "number" and i > 0 and i == math.floor(i)) )
	i = (i or 1) + 1

	local env

	local function get_first()
		local status

		status, env = pcall(getfenv, i + 2)
		if not status then
			trace_error('Unable to get the initial environment!')
		end
		i = i + 1

		return env
	end

	local function get_next()
		local status
		
		while not status do
			status, env = pcall(getfenv, i + 2)
			i = i + 1
		end

		return env
	end

	local first_env = get_first()
	if first_env == _G then
		trace_error('The initial environment is the global environment!')
	end

	assert( env == first_env )

	while env == first_env do
		env = get_next()
	end
	i = i - 1

	if env == _G then
		trace_error('Attempt to reach the global environment!')
	elseif env == _M then
		trace_error('Attempt to reach the core environment!')
	end

	-- No, this is not a typo. The index should be subtracted twice.
	-- The subtractions just have different meanings.
	return i - 1, env
end

-- Counts from 0 up, with 0 meaning the innermost environment different than the caller's.
function GetEnvironmentLayer(n)
	assert( type(n) == "number" )
	assert( n >= 0 )

	local i, env = GetNextEnvironmentThreshold()
	for _ = 1, n do
		i, env = GetNextEnvironmentThreshold(i)
	end

	return env, i - 1
end
local GetEnvironmentLayer = GetEnvironmentLayer

function GetOuterEnvironment()
	local env, i = GetEnvironmentLayer(0)
	return env, i - 1
end

local GetOuterEnvironment = GetOuterEnvironment

function pkgrequire(name)
	assert( type(name) == "string" )
	
	local env = GetOuterEnvironment()
	assert( env )
	assert( type(env._PACKAGE) == "string" )

	-- Beware the dual meaning of '.' below!
	local prefix = env._PACKAGE:gsub('^' .. GetModName() .. '.?', ''):gsub('(.)$', '%1.')
	
	local M = modrequire( prefix .. name )
	return M
end
local pkgrequire = pkgrequire
loader_metadata[pkgrequire] = {name = 'pkgrequire', category = 'ModPackage'}

local function GetDebugInfo()
	local i = GetNextEnvironmentThreshold()
	if i then
		return debug.getinfo(i, 'Sl')
	end
end

function InjectNonPrivatesIntoEnvironmentIf(p, f, s, var)
	local env = GetOuterEnvironment()
	assert( env )
	InjectNonPrivatesIntoTableIf( p, env, f, s, var  )
end

function InjectNonPrivatesIntoEnvironment(f, s, var)
	InjectNonPrivatesIntoEnvironmentIf(function() return true end, f, s, var)
end

local function push_loader_error(loader, what)
	if type(what) == "string" then
		what = "'" .. what .. "'"
	else
		what = tostring(what or "")
	end
	local info = GetDebugInfo() or {}
	return error(  ("The %s(%s) call didn't return a table at:\n%s:%d"):format( loader_metadata[loader].name, what, info.source or "?", info.currentline or 0 )  )
end


-- Returns an __index metamethod.
function LazyCopier(source)
	return function(t, k)
		local v = source[k]
		if v ~= nil then
			rawset(t, k, v)
		end
		return v
	end
end

function AttachMetaIndex(fn, object)
	local meta = getmetatable( object )

	if not meta then
		meta = {}
		setmetatable( object, meta )
	end

	local oldfn = meta.__index

	if oldfn then
		meta.__index = function(object, k)
			local v = fn(object, k)
			if v ~= nil then
				return v
			else
				return oldfn(object, k)
			end
		end
	else
		meta.__index = fn
	end

	return object
end


local advanced_prototypes = {}

function advanced_prototypes.Inject(loader)
	assert( type(loader) == "function" )
	assert( type(loader_metadata[loader].name) == "string" )

	return function(what)
		local M = loader(what)
		if type(M) ~= "table" then
			push_loader_error(loader, what)
		end
		InjectNonPrivatesIntoEnvironment( pairs(M) )
	end
end

function advanced_prototypes.Bind(loader)
	assert( type(loader) == "function" )
	assert( type(loader_metadata[loader].name) == "string" )

	return function(what)
		local M = loader(what)
		if type(M) ~= "table" then
			push_loader_error(loader, what)
		end

		local env = GetOuterEnvironment()

		AttachMetaIndex( LazyCopier(M), env )	

		return M
	end
end

function advanced_prototypes.Become(loader)
	assert( type(loader) == "function" )
	assert( type(loader_metadata[loader].name) == "string" )

	return function(what)
		local M = loader(what)
		if type(M) ~= "table" then
			push_loader_error(loader, what)
		end
		local env, i = GetOuterEnvironment()
		assert( type(i) == "number" )
		assert( i >= 2 )
		local status, err = pcall(setfenv, i + 1, M)
		if not status then
			trace_error(err)
		end
		return M
	end
end

for action, prototype in pairs(advanced_prototypes) do
	for loader, info in pairs(loader_metadata) do
		_M[action .. info.category] = prototype(loader)
	end
end

assert( InjectTheCore )
assert( BindTheCore )
assert( BecomeTheCore )
BecomeTheCore = nil

assert( InjectTheMod )
assert( BindTheMod )
assert( BecomeTheMod )

local function loadfile(fname)
	local status, f = pcall(_G.kleiloadlua, fname)

	if not status or type(f) ~= "function" then
		return nil, f and tostring(f) or ("Can't load " .. fname)
	else
		return f
	end
end

function loadmodfile(fname)
	assert( type(fname) == "string" )
	return loadfile(MODROOT .. fname)
end

function domodfile(fname)
	local f, err = loadmodfile(fname)
	if not f then
		return error(err)
	else
		return f()
	end
end

return BindTheCore
