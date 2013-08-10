--@@ENVIRONMENT BOOTUP
local modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(modname .. '.booter') )
--@@END ENVIRONMENT BOOTUP

local Lambda = wickerrequire 'paradigms.functional'
local Logic = wickerrequire 'paradigms.logic'

local Pred = wickerrequire 'lib.predicates'


local ConditionalTasker = wickerrequire 'protocomponents.conditionaltasker'
local TallHatchery = ConditionalTasker:Instantiate("TallHatchery")



local function ForceLay(inst)
	local max_dist = TheMod:GetConfig("TALLBIRD_LAYING_MAX_DISTANCE")
	local function close_enough(v)
		return distsq(inst:GetPosition(), v:GetPosition()) < max_dist*max_dist
	end

	if inst.components.childspawner and inst.components.pickable then
		if Logic.ThereExists(close_enough, pairs(inst.components.childspawner.childrenoutside)) then
			inst.components.pickable:Regen()
		end
	end
end


-- Some class defaults.

-- The second return value indicates a hard failure.
TallHatchery:SetConditionFn(function(inst)
	if inst.components.pickable and not inst.components.pickable:CanBePicked() then
		if TheMod:GetConfig("TALLBIRD_DONT_LAY_IF_SMALL_CHILDREN") then
			for k,v in pairs(inst.components.childspawner.childrenoutside) do
				if v.components.leader and v.components.leader:IsBeingFollowedBy("smallbird") then
					return false, true
				end
			end
		end

		return not inst.readytolay
	else
		return false, true
	end
end)

TallHatchery:SetOnCompleteFn(function(inst)
	inst.readytolay = true
	if inst:IsAsleep() then
		ForceLay(inst)
	end
end)

TallHatchery:SetOnTryStartFn(function(inst, success, hardfailure)
	if not success and hardfailure then
		inst.readytolay = nil
	end
end)


--------------------------------------------------------------------------------


local assets =
{
	Asset("ANIM", "anim/tallbird_egg.zip"),
}

local prefabs =
{
	"smallbird",
	"tallbird",
	"tallbirdegg",
}


local function onpicked(inst, picker)
	inst.thief = picker
	inst.AnimState:PlayAnimation("nest")
	inst.components.childspawner.noregen = true
	if inst.components.childspawner and picker then
		for k,v in pairs(inst.components.childspawner.childrenoutside) do
			if v.components.combat then
				v.components.combat:SuggestTarget(picker)
			end
		end
	end
	inst:DoTaskInTime(0, TallHatchery.TryStarter)
end

local function onmakeempty(inst)
	if not inst:IsValid() then return end

	if not inst:IsInLimbo() then
		inst.AnimState:PlayAnimation("nest")
	end
	if inst.components.childspawner then
		inst.components.childspawner.noregen = true
	end
	inst:DoTaskInTime(0, TallHatchery.TryStarter)
end

local function onregrow(inst)
	if not inst:IsValid() then return end

	if not inst:IsInLimbo() then
		inst.AnimState:PlayAnimation("eggnest")
	end
	if inst.components.childspawner then
		inst.components.childspawner.noregen = false
	end
	inst.thief = nil
	TallHatchery.TryStarter(inst)
end


local function onvacate(inst)
	if inst.components.pickable then
		inst.components.pickable:MakeEmpty()
		TallHatchery.TryStarter(inst)
	end
end


local function OnSave(inst, data)
	data.readytolay = inst.readytolay
end

local function OnLoad(inst, data)
	if data then
		inst.readytolay = data.readytolay
		TallHatchery.TryStarter(inst)
	end
end


local function fn(Sim)
	local inst = CreateEntity()
	local trans = inst.entity:AddTransform()
	local anim = inst.entity:AddAnimState()

	local minimap = inst.entity:AddMiniMapEntity()
	minimap:SetIcon( "tallbirdnest.png" )
   
	anim:SetBuild("tallbird_egg")
	anim:SetBank("egg")
	anim:PlayAnimation("eggnest", false)
	
	inst:AddComponent("pickable")
	--inst.components.pickable.picksound = "dontstarve/wilson/harvest_berries"
	inst.components.pickable:SetUp("tallbirdegg", nil)
	inst.components.pickable:SetOnPickedFn(onpicked)
	inst.components.pickable:SetOnRegenFn(onregrow)
	inst.components.pickable:SetMakeEmptyFn(onmakeempty)
	
	
	_G.MakeMediumBurnable(inst)
	_G.MakeSmallPropagator(inst)
	
	-------------------
	inst:AddComponent("childspawner")
	inst.components.childspawner.childname = "tallbird"
	inst.components.childspawner.spawnoffscreen = true
	inst.components.childspawner:SetRegenPeriod( TheMod:GetConfig("TALLBIRD_SPAWN_DELAY") )
	inst.components.childspawner:SetSpawnPeriod(0)
	inst.components.childspawner:SetSpawnedFn(onvacate)
	inst.components.childspawner:SetMaxChildren(1)
	inst.components.childspawner:StartSpawning()
	-------------------
	
	inst:AddComponent("tallhatchery")
	inst.components.tallhatchery:SetFullDelay( TheMod:GetConfig("TALLBIRD_LAYING_DELAY") )
   
	inst:AddComponent("inspectable")
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
   
	return inst
end

return Prefab( "common/objects/tallbirdnest", fn, assets, prefabs) 
