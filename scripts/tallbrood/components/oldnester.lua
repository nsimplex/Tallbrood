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

local Debuggable = wickerrequire 'gadgets.debuggable'
local EventChain = wickerrequire 'gadgets.eventchain'

local myutils = wickerrequire 'utils'

local Nester = Class(Debuggable, function(self, inst)
	Debuggable._ctor(self, 'Nester', true)

	self.inst = inst

	self:SetNestPrefab("tallbirdnest")
	-- How long a nestless inst will take to spawn a new one, in seconds.
	self:SetFullNestDelay(math.huge)

	self:SetNestingTestFn(nil)

	-- Nesting task
	self.task = nil
	self.paused_delay = math.huge

	self.entityawake_chain = nil

	self.onspawn_nest_fn = nil

	self.nest_onremove_callback = function(nest)
		self:DebugSay('Running "onremove" callback of [', nest, ']')
		if inst:IsValid() and inst.components.nester then
			GetWorld():DoTaskInTime(0, function()
				if inst:IsValid() and not inst:IsInLimbo() and inst.components.nester then
					inst.components.nester:StartNesting()
				end
			end)
		end
	end

	self.inst:ListenForEvent("daycomplete", function()
		if inst:IsValid() and not inst:IsInLimbo() and inst.components.nester and inst.components.nester:IsNesting() then
			local dt = 0.35*TUNING.TOTAL_DAY_TIME*math.random()
			GetWorld():DoTaskInTime(dt, function()
				if inst:IsValid() and not inst:IsInLimbo() and inst.components.nester then
					inst.components.nester:Reboot(true)
				end
			end)
			if self:Debug() then
				self:Say('daily Reboot() in ', myutils.time.FactorTime(dt))
			end
		end
	end, GetWorld())
end)

function Nester:SetNestingTestFn(f)
	assert(f == nil or Pred.IsCallable(f))
	self.nesting_test_fn = f
	return f
end

function Nester:SetOnSpawnNestFn(f)
	assert(f == nil or Pred.IsCallable(f))
	self.onspawn_nest_fn = f
end

function Nester:GetNestingTestFn()
	return self.nesting_test_fn
end

-- Nesting refers to being in the wait period between losing a nest (or being spawned without one) and making a new one.
function Nester:IsNesting()
	return not self:HasNest()
end

function Nester:HasTask()
	assert( Logic.IfAndOnlyIf(self:GetNestingTime(), not self.paused_delay) )
	assert( Logic.Implies(self.task, self:GetNestingTime()) )
	return self.task and true or false
end

function Nester:GetTentativeRemainingTime()
	return self.paused_delay or math.max(0, self:GetNestingTime() - GetTime())	
end

function Nester:GetFactoredRemainingTime()
	return myutils.time.FactorTime( self:GetTentativeRemainingTime() )
end

function Nester:GetFullNestDelay()
	return self.full_nest_delay
end

function Nester:SetFullNestDelay(delay)
	assert(Pred.IsPositiveNumber(delay))
	self.full_nest_delay = delay
	return self
end

function Nester:GetNestingTime()
	return self.nesting_time
end

function Nester:SetNestingTime(dt)
	assert(dt == nil or Pred.IsNumber(dt))
	self.nesting_time = dt
	return dt
end

function Nester:GetDebugString()
	local t

	if not self:IsNesting() then
		t = {'(not nesting)'}
	else
		t = {}

		if self:HasTask() then
			table.insert(t, '(active at ')
			table.insert(t, tostring(self:GetFactoredRemainingTime()))
			table.insert(t, ' remaining)')
		else
			if self:GetNestingTime() then
				table.insert(t, '(background updating at ')
			else
				table.insert(t, '(paused at ')
			end
			table.insert(t, tostring(self:GetFactoredRemainingTime()))
			table.insert(t, ' remaining)')
		end
	end

	return table.concat(t)
end

function Nester:StartTask()
	if
		not self:HasTask()
		and self:GetNestingTime() < math.huge
		and self.inst:IsValid() and not self.inst:IsInLimbo()
		and not self.inst:IsAsleep()
	then
		self:DebugSay('StartTask()')
		self.task = self.inst:DoTaskInTime(self:GetTentativeRemainingTime(), function()
			if self.inst.components.nester then
				self.inst.components.nester:MakeNest()
			end
		end)
	end
end

function Nester:StopTask()
	if self:HasTask() then
		self:DebugSay('StopTask()')
		self.task:Cancel()
		self.task = nil
	end
end

function Nester:Unpause()
	-- Just for the sanity checks.
	self:HasTask()

	if not self:GetNestingTime() then
		assert( Pred.IsNonNegativeNumber(self.paused_delay) )
		self:SetNestingTime(GetTime() + self.paused_delay)
		self.paused_delay = nil
		self:StartTask()
	end
end

function Nester:Pause()
	-- Just for the sanity checks.
	self:HasTask()

	if self:GetNestingTime() then
		self:DebugSay( 'Pause()' )

		self:StopTask()
		self.paused_delay = math.max(0, self:GetNestingTime() - GetTime())
		self:SetNestingTime(nil)
	end
end

function Nester:Reboot(daily)
	self:DebugSay('Reboot()', daily and ' DAILY' or nil)

	self:Pause()

	if self:IsNesting() then
		if self.paused_delay <= 0 then
			self:MakeNest()
		else
			if self.paused_delay == math.huge then
				self.paused_delay = self:GetFullNestDelay()
			end
			self:Unpause()
		end
	else
		self.paused_delay = math.huge
	end

	if self:Debug() then
		self:Say( self:GetDebugString() )
	end
end

function Nester:GetNestPrefab()
	return Pred.IsCallable(self.nest_prefab) and self.nest_prefab(self.inst) or self.nest_prefab
end

function Nester:SetNestPrefab(prefab)
	assert( (Pred.IsString(prefab) and Pred.PrefabExists(prefab)) or Pred.IsCallable(prefab) )
	self.nest_prefab = prefab
	return prefab
end

function Nester:StartNesting()
	self:DebugSay('StartNesting()')
	if self:HasNest() then
		local nest = self.inst.components.homeseeker.home
		self:DebugSay('StartNesting(): attaching "onremove" callback to [', nest, ']') 
		assert( nest )

		-- For some strange reason (which seems to be a buggy behaviour in the game), we need to add two callbacks to that the second will run (the first won't).
		self.inst:RemoveEventCallback("onremove", Lambda.Nil, nest)
		self.inst:RemoveEventCallback("onremove", self.nest_onremove_callback, nest)
		self.inst:ListenForEvent("onremove", Lambda.Nil, nest)
		self.inst:ListenForEvent("onremove", self.nest_onremove_callback, nest)
	else
		self:Reboot()
	end
end

Nester.StopNesting = Nester.Pause

function Nester:HasNest()
	return self.inst.components.homeseeker and self.inst.components.homeseeker:HasHome()
end

function Nester:SpawnNest()
	if self.dont_spawn or not self:IsNesting() then return end

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

	if self.radius then
		if not self.entityawake_chain or self.inst:IsAsleep() then
			local A = SearchSpace.Annulus(center, 0, self.radius)

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
			self:Pause()
			self.paused_delay = math.huge
			self:StartNesting()
			if self.onspawn_nest_fn then
				self.onspawn_nest_fn(self.inst, nest)
			end
			self.dont_spawn = nil
			return nest
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

function Nester:SetSearchRadius(r)
	assert(r == nil or Pred.IsPositiveNumber(r))
	self.radius = r
	return r
end

function Nester:MakeNest()
	local clock = GetClock()

	if not Pred.IsOk(self.inst) or not self.inst.components.nester == self or not self:IsNesting() or not clock then return end

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
					GetWorld():DoTaskInTime(dt, function()
						if Pred.IsOk(inst) then
							inst.components.nester:MakeNest()
						end
					end)
					if self:Debug() then
						self:Say('MakeNest() in ', myutils.time.FactorTime(dt))
					end
				end
			end, clock.inst)
			self:DebugSay('scheduled nightly nesting')
			return
		end
		self:SpawnNest()
	end
end

function Nester:DoDelta(dt)
	if self:Debug() then
		self:Say( 'DoDelta(', myutils.time.FactorTime(dt), ')' )
	end
	self:Pause()
	self.paused_delay = math.max(0, self.paused_delay - dt)
	self:Reboot()
	return dt
end

function Nester:LongUpdate(dt)
	self:DoDelta(dt)
end

function Nester:OnEntityWake()
	self:DebugSay('OnEntityWake()')
	self.dont_spawn = nil
	self:Reboot()
end

function Nester:OnEntitySleep()
	self:DebugSay('OnEntitySleep()')

	if self.entityawake_chain then
		self.entityawake_chain:Disable()
	end
end

local function dump_measure(x)
	assert(Pred.IsNonNegativeNumber(x))
	return x == math.huge and -1 or x
end

local function load_measure(x)
	if x == nil or Pred.IsNonNegativeNumber(x) then
		return x
	else
		return math.huge
	end
end

function Nester:OnSave()
	self:DebugSay('OnSave()')

	self:Pause()

	local data = {
		paused_delay = dump_measure(self.paused_delay),
		dont_spawn = self.dont_spawn,
	}

	self:Reboot()

	return data
end

function Nester:OnLoad(data)
	self:DebugSay('OnLoad()')

	self:StopNesting()

	self.paused_delay = math.min(load_measure(data.paused_delay) or math.huge, self:GetFullNestDelay())
	self.dont_spawn = data.dont_spawn

	self:StartNesting()
end


return Nester
