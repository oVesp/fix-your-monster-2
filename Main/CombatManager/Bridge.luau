-- ModuleScript: ServerScriptService>Main>CombatManager>Bridge
local RP = game:GetService("ReplicatedStorage")

-- Carregar sistema VFX modularizado
local MoveVFX = require(RP.Modules.MoveVFX)

local Bridge = {}

local function getRoot(model)
	if not model then return nil end
	if model.PrimaryPart then return model.PrimaryPart end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then return hrp end
	for _, ch in ipairs(model:GetChildren()) do
		if ch:IsA("BasePart") then return ch end
	end
	return model
end

local function playStage(stage, moveId, where, opts)
	opts = opts or {}

	-- Usar sistema VFX modularizado
	local pack, adv = MoveVFX.Resolve(moveId)

	if adv and type(adv[stage]) == "function" then
		local ok = pcall(adv[stage], moveId, where, opts)
		if ok then return end
	end

	local info = pack[stage]
	if not info then return end

	if info.effect and _G.EFFECTS and _G.EFFECTS.EmitterEffect then
		local posCFrame
		if where and where.CFrame then
			posCFrame = where.CFrame
		elseif typeof(opts.Position) == "CFrame" then
			posCFrame = opts.Position
		end

		_G.EFFECTS.EmitterEffect({
			Name = info.effect,
			Position = posCFrame,
			Offset = opts.Offset,
			Duration = opts.Duration or 0.5,
			Weld = where,
		})
	end

	if info.trail and stage == "travel" and _G.EFFECTS and _G.EFFECTS.TrailEffect then
		_G.EFFECTS.TrailEffect({
			Name = info.trail,
			Part = where,
			Duration = opts.Duration or 0.4,
			Offset = opts.Offset,
		})
	end

	local function sfx(name)
		if name and _G.EFFECTS and _G.EFFECTS.PlaySound then
			_G.EFFECTS.PlaySound(name, {
				Where = where,
				Volume = opts.Volume,
				Duration = opts.SfxDuration,
				FadeOutTime = opts.FadeOutTime,
				RandomPitch = opts.RandomPitch,
			})
		end
	end

	sfx(info.sfxStart)
	sfx(info.sfxLoop)
	sfx(info.sfxHit)
	sfx(info.sfxEnd)
end

function Bridge.PlayCast(casterModel, moveId, castTime)
	local casterRoot = getRoot(casterModel)
	playStage("cast", moveId, casterRoot, {Duration = castTime or 1.0})
end

function Bridge.PlayTravel(casterModel, moveId, travelRef, travelTime)
	local casterRoot = getRoot(casterModel)
	playStage("travel", moveId, travelRef or casterRoot, {Duration = travelTime or 0.5})
end

function Bridge.PlayImpact(casterModel, targetModel, moveId)
	local casterRoot = getRoot(casterModel)
	local targetRoot = getRoot(targetModel) or casterRoot
	playStage("impact", moveId, targetRoot, {CasterRoot = casterRoot})
end

function Bridge.PlayEnd(casterModel, moveId)
	local casterRoot = getRoot(casterModel)
	playStage("endcast", moveId, casterRoot)
end

return Bridge