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
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(_modname .. '.booter') )

--@@END ENVIRONMENT BOOTUP


local Lambda = wickerrequire 'paradigms.functional'
local Logic = wickerrequire 'paradigms.logic'

local Pred = wickerrequire 'lib.predicates'
local SearchSpace = wickerrequire 'lib.searchspace'

local EventChain = wickerrequire 'gadgets.eventchain'

local myutils = wickerrequire 'utils'


local ConditionalTasker = wickerrequire 'protocomponents.conditionaltasker'



local function NewOnRemoveCallback(inst)
	return function(nest)
		if Pred.IsOk(inst) and inst.components.nester then
			inst.components.nester:DebugSay('Running "onremove" callback of [', nest, ']')
			inst:DoTaskInTime(0, function(inst)
				if Pred.IsOk(inst) and inst.components.nester then
					inst.components.nester:TryStart()
				end
			end)
		end
	end
end


-- Prototype class for the Nester component.
local ProtoNester = Class(ConditionalTasker, function(self)
	ConditionalTasker._ctor(self)

	-- Some class defaults.
	
	self:SetConditionFn(function(inst)
		return inst.components.nester and not inst.components.nester:HasNest() and not inst.components.nester.dont_spawn
	end)
	
	self:SetOnCompleteFn(function(inst)
		if inst.components.nester then
			inst.components.nester:MakeNest()
		end
	end)
	
	self:SetOnTryStartFn(function(inst, success)
		local self = inst.components.nester
		-- The following assert should be guaranteed by the ConditionalTasker implementation.
		assert( self )
		if not success then
			local nest = inst.components.homeseeker.home
			self:DebugSay('attaching "onremove" callback to [', nest, ']') 
			assert( nest )
	
			-- For some strange reason (which seems to be a buggy behaviour in the game), we need to add two callbacks so that the second will run (the first won't).
			inst:RemoveEventCallback("onremove", Lambda.Nil, nest)
			inst:RemoveEventCallback("onremove", self.nest_onremove_callback, nest)
			inst:ListenForEvent("onremove", Lambda.Nil, nest)
			inst:ListenForEvent("onremove", self.nest_onremove_callback, nest)
		end
	end)
end)


function ProtoNester:new(inst)
	ConditionalTasker.new(self, inst)

	self:SetNestPrefab("tallbirdnest")

	self.entityawake_chain = nil

	self.nest_onremove_callback = NewOnRemoveCallback(inst)
end


-- We need to force instantiation because the package "components/nester" already counts as loaded.
local Nester = ProtoNester:ForcefullyInstantiate("Nester")


function Nester:HasNest()
	return self.inst.components.homeseeker and self.inst.components.homeseeker:HasHome()
end


function Nester:GetNestPrefab()
	return Pred.IsCallable(self.nest_prefab) and self.nest_prefab(self.inst) or self.nest_prefab
end

function Nester:SetNestPrefab(prefab)
	assert( (Pred.IsString(prefab) and Pred.PrefabExists(prefab)) or Pred.IsCallable(prefab) )
	self.nest_prefab = prefab
	return prefab
end

function Nester:GetSearchRadius()
	return self.search_radius
end

function Nester:SetSearchRadius(r)
	assert(r == nil or Pred.IsPositiveNumber(r))
	self.search_radius = r
	return r
end

function Nester:GetNestingTestFn(f)
	return self.nesting_test_fn
end

function Nester:SetNestingTestFn(f)
	assert(f == nil or Pred.IsCallable(f))
	self.nesting_test_fn = f
	return f
end

function Nester:GetOnSpawnNestFn()
	return self.onspawn_nest_fn
end

function Nester:SetOnSpawnNestFn(f)
	assert(f == nil or Pred.IsCallable(f))
	self.onspawn_nest_fn = f
	return f
end


function Nester:CanSpawnNestAtPoint(pt)
	return Pred.IsValidPoint(pt) and ( not self:GetNestingTestFn() or self:GetNestingTestFn()(pt, self.inst) )
end

function Nester:SpawnNestAtPoint(pt)
	local prefab = self:GetNestPrefab()
	if prefab then
		local nest = SpawnPrefab(prefab)
		if nest then
			assert(nest.components.childspawner)
			if self.inst.AnimState and nest.AnimState then
				self.inst.AnimState:SetSortOrder( 1 )
				nest.AnimState:SetSortOrder( 0 )
			end
			nest.Transform:SetPosition(pt:Get())
			self.inst.Transform:SetPosition(pt:Get())

			nest.components.childspawner.childreninside = 0
			nest.components.childspawner:TakeOwnership(self.inst)
			assert(self:HasNest())

			if self:GetOnSpawnNestFn() then
				self:GetOnSpawnNestFn()(self.inst, nest)
			end

			self.dont_spawn = nil


			self:TryStart()

			return nest
		end
	end
end

function Nester:SpawnNest()
	if self.dont_spawn or self:HasNest() then return end

	self:DebugSay('SpawnNest()')

	if self.inst:IsAsleep() then
		self.dont_spawn = true
	end
	
	local function test(pt)
		return self:CanSpawnNestAtPoint(pt)
	end

	local center = self.inst:GetPosition()

	if test(center) then
		return self:SpawnNestAtPoint(center)
	end

	if self:GetSearchRadius() then
		if not self.entityawake_chain or self.inst:IsAsleep() then
			local A = SearchSpace.Annulus(center, 0, self:GetSearchRadius())

			local pt = A:Search(test)
			if pt then
				local nest = self:SpawnNestAtPoint(pt)
				if self:Debug() then
					self:Say('spawned [', nest, '] at (', ('%.1f, %.1f, %.1f'):format(pt:Get()), ')')
				end
				return nest
			end
		end
	end

end


function Nester:SetEntityAwakeEventChain(c)
	assert( Pred.IsInstanceOf(EventChain)(c) )

	c = c:Copy()

	c:Append(function(inst, c)
		if inst.components.nester then
			if inst.components.nester:SpawnNest() then
				c:Disable()
			end
		else
			c:Disable()
		end

		return true
	end)

	c:Attach(self.inst)

	if self:Debug() then
		c:SetCancelFn(function(inst)
			if self:Debug() then
				c:Say('Canceled')
			end
		end)
	end

	self.entityawake_chain = c

	return c
end

function Nester:MakeNest()
	if self:HasNest() then return end
	
	local clock = GetClock()

	self:DebugSay('MakeNest()')

	if self.entityawake_chain and not self.inst:IsAsleep() then
		if not self.entityawake_chain:IsEnabled() and self:Debug() then
			self.entityawake_chain:Say('Enabled')
		end
		self.entityawake_chain:Enable()
	else
		if not clock:IsNight() then
			local inst = self.inst
			-- There shouldn't be any issue if this ends up being scheduled more than once.
			myutils.game.ListenForEventOnce(inst, "nighttime", function(world)
				if Pred.IsOk(inst) and inst.components.nester then
					local dt = 0.4*world.components.clock:GetNightTime()*math.random()
					inst:DoTaskInTime(dt, function(inst)
						if Pred.IsOk(inst) and inst.components.nester then
							inst.components.nester:MakeNest()
						end
					end)
					if self:Debug() then
						self:Say('MakeNest() in ', myutils.time.FactorTime(dt))
					end
				end
			end, clock.inst)
			self:DebugSay('scheduled nightly nesting')
		else
			self:SpawnNest()
		end
	end
end


function Nester:OnEntityWake()
	self.dont_spawn = nil
	if ProtoNester.OnEntityWake then
		ProtoNester.OnEntityWake(self)
	end
end

function Nester:OnEntitySleep()
	if ProtoNester.OnEntitySleep then
		ProtoNester.OnEntitySleep(self)
	end
	if self.entityawake_chain then
		self.entityawake_chain:Disable()
	end
end

function Nester:OnSave()
	local data = ProtoNester.OnSave(self)

	data.dont_spawn = self.dont_spawn

	return data
end

function Nester:OnLoad(data)
	if data then
		self.dont_spawn = data.dont_spawn
	end
	
	ProtoNester.OnLoad(self, data)
end


return Nester
