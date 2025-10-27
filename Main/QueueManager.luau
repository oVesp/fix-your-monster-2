-- ServerScriptService > Main > QueueManager
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CombatZone = require(script.Parent.CombatZone)

-- Carrega os módulos globais que você já tem
local COMBATMANAGER

local STATES = _G.STATES

local QueueManager = {}

local function _isBot(model)
	return model
		and model:IsA("Model")
		and (model:GetAttribute("IsBot") == true or model:GetAttribute("QueueBot") == true)
end

--[[
  Configuração das Filas
  - Cada chave é o nome de uma fila (ex: "FFA_Battle", "Duos").
  - settings:
    - mode: O modo de jogo ("FFA", "2v2", etc.). Isso será usado para configurar os times.
    - minPlayers: Mínimo de jogadores para iniciar o countdown.
    - maxPlayers: Máximo de jogadores na partida.
    - countdown: Tempo em segundos para iniciar a partida após atingir minPlayers.
]]
local queues = {
	["FFA_Battle"] = {
		players = {},
		settings = {
			mode = "FFA",
			minPlayers = 2,
			maxPlayers = 4,
			countdown = 5,
			fillWithBotsAfterSeconds = 5 
		},
		-- Estado da fila
		countdownActive = false,
		startTime = 0,
		waitingStartTime = 0
	}
	-- Você pode adicionar mais filas aqui, como "2v2", "4v4", etc.
	-- ["Team_Deathmatch_2v2"] = {
	--     players = {},
	--     settings = {
	--         mode = "2v2",
	--         minPlayers = 4,
	--         maxPlayers = 4,
	--         countdown = 20
	--     },
	--     countdownActive = false,
	--     startTime = 0
	-- }
}

-- ===== Spot helpers =====
local function _iterSpots()
	local folder = workspace:FindFirstChild("BattleSpots")
	if not folder then return {} end
	return folder:GetChildren()
end

local function _isSpotFree(spot)
	if not (spot and spot:IsA("BasePart")) then return false end
	local occ = spot:GetAttribute("CZ_Occupied")
	return occ == nil or occ == false or occ == ""
end

local function _nearestFreeSpot(anchorPos: Vector3)
	local best, bestD = nil, math.huge
	for _, inst in ipairs(_iterSpots()) do
		if inst:IsA("BasePart") and inst.Name:lower() == "spot" and _isSpotFree(inst) then
			local d = (inst.Position - anchorPos).Magnitude
			if d < bestD then best, bestD = inst, d end
		end
	end
	return best
end

local function _reserveSpot(spot: BasePart?, combatId: string)
	if spot and spot:IsA("BasePart") then
		spot:SetAttribute("CZ_Occupied", combatId)
	end
end

local function _releaseSpot(spot: BasePart?)
	if spot and spot:IsA("BasePart") then
		spot:SetAttribute("CZ_Occupied", nil)
	end
end

-- Módulo de Remotes
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local QueueStatusUpdate = Remotes:WaitForChild("QueueStatusUpdate")

local function spawnNPC(name)
	if not _G.MONSTERGENERATOR or not _G.MONSTERGENERATOR.BuildMonster then
		warn("[QueueManager] _G.MONSTERGENERATORERATOR indisponível para criar bot.")
		return nil
	end

	local ok, result = pcall(function()
		-- BuildMonster(data, playerId?) -> sem ownerId = NPC
		return _G.MONSTERGENERATOR.BuildMonster(nil, nil, { force = true })
	end)

	if not ok or not result then
		warn("[QueueManager] BuildMonster para NPC falhou:", tostring(result))
		return nil
	end

	local instance = result
	if name then 
		instance.Name = name
		instance:SetAttribute("Name", name) 
	end

	if STATES then 
		STATES:SetState(instance, "Idle") 
	end

	return instance
end
-- Função para encontrar o monstro de um jogador (similar à que você já usa)
local function getPlayerMonster(player)
	if _G.MONSTERGENERATOR and _G.MONSTERGENERATOR.GetPlayerMonster then
		local monster = _G.MONSTERGENERATOR.GetPlayerMonster(player.UserId)
		if monster and monster.Parent then
			return monster
		end
	end
	-- Fallback para procurar no workspace
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("OwnerId") == player.UserId then
			return obj
		end
	end
	return nil
end

function QueueManager.Join(player, queueName)
	local queueData = queues[queueName]
	if not queueData then
		return false, "Fila não encontrada."
	end
	if #queueData.players >= queueData.settings.maxPlayers then
		return false, "A fila está cheia."
	end
	if not getPlayerMonster(player) then
		return false, "Você precisa de um monstro para entrar na fila."
	end

	QueueManager.Leave(player)
	table.insert(queueData.players, player)

	-- >>> MUDANÇA IMPORTANTE: Inicia o timer de espera por bots
	if #queueData.players == 1 and queueData.settings.fillWithBotsAfterSeconds then
		queueData.waitingStartTime = os.clock()
		print(("[QueueManager] Primeiro jogador entrou. Timer para preenchimento com bots iniciado para a fila %s."):format(queueName))
	end

	print(("[QueueManager] Player %s entrou na fila %s (%d/%d)."):format(player.Name, queueName, #queueData.players, queueData.settings.maxPlayers))
	QueueStatusUpdate:FireClient(player, { status = "InQueue", queueName = queueName, playerCount = #queueData.players, maxPlayers = queueData.settings.maxPlayers })
	return true, "Entrou na fila com sucesso."
end

function QueueManager.Leave(player)
	for queueName, queueData in pairs(queues) do
		for i, queuedPlayer in ipairs(queueData.players) do
			if queuedPlayer == player then
				table.remove(queueData.players, i)
				print(("[QueueManager] Player %s saiu da fila %s."):format(player.Name, queueName))

				-- >>> MUDANÇA IMPORTANTE: Reseta o timer se a fila ficar vazia
				if #queueData.players == 0 then
					queueData.waitingStartTime = 0
				end

				if queueData.countdownActive and #queueData.players < queueData.settings.minPlayers then
					queueData.countdownActive = false
					print(("[QueueManager] Countdown para %s cancelado."):format(queueName))
				end
				QueueStatusUpdate:FireClient(player, { status = "None" })
				return true
			end
		end
	end
	return false
end

-- A função startMatch foi refatorada para aceitar bots
local function startMatch(queueData, bots)
	bots = bots or {}
	print(("[QueueManager] Iniciando partida para a fila %s com %d jogadores e %d bots!"):format(queueData.settings.mode, #queueData.players, #bots))
	if not COMBATMANAGER then
		COMBATMANAGER = _G.COMBATMANAGER
	end
	local participants = {}
	local validPlayers = {}
	local botsForCleanup = {}

	-- Adiciona monstros dos jogadores reais
	for _, player in ipairs(queueData.players) do
		local monster = getPlayerMonster(player)
		if monster and monster.Parent then
			table.insert(participants, monster)
			table.insert(validPlayers, player)
		end
	end

	-- Adiciona os bots
	for _, botMonster in ipairs(bots) do
		table.insert(participants, botMonster)
	end
	
	for _, m in ipairs(participants) do
		-- mark bots if you know which ones are AI/NPC
		if not m:GetAttribute("OwnerId") then
			-- heuristic: no owner -> likely an NPC/bot
			m:SetAttribute("QueueBot", true)
		end
		if _isBot(m) then
			table.insert(botsForCleanup, m)
		end
	end

	-- Limpa a fila
	queueData.players = {}
	queueData.countdownActive = false
	queueData.waitingStartTime = 0

	if #participants < queueData.settings.minPlayers then
		print(("[QueueManager] Partida cancelada, número insuficiente de participantes válidos (%d)."):format(#participants))
		for _, player in ipairs(validPlayers) do
			QueueStatusUpdate:FireClient(player, { status = "Cancelled" })
		end
		return
	end

	-- Define os times
	if queueData.settings.mode == "FFA" then
		for i, monster in ipairs(participants) do monster:SetAttribute("Team", i) end
	end

	print("[QueueManager] Definindo estado 'InCombat' para todos os participantes...")
	for _, monster in ipairs(participants) do
		if monster and STATES then
			STATES:SetState(monster, "InCombat")
		end
	end

	task.wait() -- let state changes settle for a frame

	-- 2) Choose anchor position (from first real player if possible)
	local anchorFrom = Vector3.new()
	do
		local firstPlayer = validPlayers[1]
		if firstPlayer and firstPlayer.Character and firstPlayer.Character.PrimaryPart then
			anchorFrom = firstPlayer.Character.PrimaryPart.Position
		else
			-- fallback: any participant's root
			for _, m in ipairs(participants) do
				if m and m.PrimaryPart then anchorFrom = m.PrimaryPart.Position break end
			end
		end
	end

	-- 3) Find & reserve nearest free Spot
	local spot = _nearestFreeSpot(anchorFrom)
	if not spot then
		print("[QueueManager] Nenhum Spot livre. Aguardando liberação...")
		-- Re-enqueue or early return; do NOT start combat now.
		-- return here if you prefer to wait:
		return
	end
	local center = spot.Position

	local opts = { center = center, radius = 30, height = 16 }

	-- Temporary reservation id; we’ll update once we get the real combatId
	if spot then spot:SetAttribute("CZ_Reserved", true) end


	-- 4) Start combat at this spot (CombatManager will ring-place + leash)
	print("[QueueManager] Chamando CombatManager.StartCombat com arena opts...")
	local combatId
	if COMBATMANAGER and COMBATMANAGER.StartCombat then
		combatId = COMBATMANAGER.StartCombat(participants, opts, function(results)
			local combatId = COMBATMANAGER.StartCombat(participants, opts, function(results)
				-- release the spot (from Fix 1)
				if spot then
					spot:SetAttribute("CZ_Occupied", nil)
					spot:SetAttribute("CZ_Reserved", nil)
				end

				-- BOT CLEANUP
				for _, bot in ipairs(botsForCleanup) do
					if bot and bot.Parent then
						-- optional: small delay lets any end-of-combat effects finish
						task.defer(function()
							if bot and bot.Parent then
								bot:Destroy()
							end
						end)
					end
				end
			end)
			
			_releaseSpot(spot)
			-- notify players completion if you like:
			for _, player in ipairs(validPlayers) do
				QueueStatusUpdate:FireClient(player, { status = "Finished", results = true })
			end
		end)
		if not combatId then
			-- failed to start; free reservation and kill bots now
			if spot then
				spot:SetAttribute("CZ_Occupied", nil)
				spot:SetAttribute("CZ_Reserved", nil)
			end
			for _, bot in ipairs(botsForCleanup) do
				if bot and bot.Parent then bot:Destroy() end
			end
			return
		end
	else
		warn("[QueueManager] CombatManager não foi encontrado!")
	end

	-- 5) Update reservation with the real id
	if combatId and spot and spot.Parent then
		spot:SetAttribute("CZ_Occupied", combatId)
	end

	if spot and spot.Parent then
		spot:SetAttribute("CZ_Occupied", combatId)
		spot:SetAttribute("CZ_Reserved", nil)
	end
	
	-- 6) Notify players match started (keep your code)
	for _, player in ipairs(validPlayers) do
		QueueStatusUpdate:FireClient(player, { status = "Started" })
	end

	-- >>> INÍCIO DA MUDANÇA CRÍTICA <<<

	-- 1. Força o estado de combate em TODOS os participantes.
	-- O CombatManager pode não "ver" os monstros se eles não estiverem neste estado.
	print("[QueueManager] Definindo estado 'InCombat' para todos os participantes...")
	for _, monster in ipairs(participants) do
		if monster and STATES then
			STATES:SetState(monster, "InCombat")
		end
	end

	-- 2. Aguarda um único frame do servidor.
	-- Isso garante que todas as mudanças de estado e posição sejam processadas antes de iniciar a lógica de combate.
	task.wait() 

	-- 3. Inicia o combate de forma segura.
	print("[QueueManager] Chamando CombatManager.StartCombat...")
	--local success, err = pcall(function()
	--	if COMBATMANAGER and COMBATMANAGER.StartCombat then
	--		COMBATMANAGER.StartCombat(participants)
	--	else
	--		warn("[QueueManager] _G.COMBATMANAGER.StartCombat não foi encontrado!")
	--	end
	--end)
	if COMBATMANAGER and COMBATMANAGER.StartCombat then
		COMBATMANAGER.StartCombat(participants)
		if spot then
			spot:SetAttribute("CZ_Occupied", nil)
			spot:SetAttribute("CZ_Reserved", nil)
		end
	else
		warn("[QueueManager] CombatManager não foi encontrado!")
	end
	--if not success then
	--	warn("[QueueManager] ERRO ao chamar StartCombat:", err)
	--else
	--	print("[QueueManager] O combate foi iniciado com sucesso!")
	--end

	-- >>> FIM DA MUDANÇA CRÍTICA <<<

	-- Notifica os jogadores
	for _, player in ipairs(validPlayers) do
		QueueStatusUpdate:FireClient(player, { status = "Started" })
	end
end

-- O loop de update agora tem a lógica de preenchimento com bots
function QueueManager.update()
	local now = os.clock()
	for queueName, queueData in pairs(queues) do
		if queueData.countdownActive then
			if now >= queueData.startTime + queueData.settings.countdown then
				startMatch(queueData) -- Inicia a partida normalmente
			else
				local timeLeft = math.ceil((queueData.startTime + queueData.settings.countdown) - now)
				for _, player in ipairs(queueData.players) do
					QueueStatusUpdate:FireClient(player, { status = "Countdown", timeLeft = timeLeft })
				end
			end
		else
			-- >>> INÍCIO DA NOVA LÓGICA DE BOTS <<<
			local timeToFill = queueData.settings.fillWithBotsAfterSeconds
			-- Verifica se a fila está esperando por jogadores e se o tempo acabou
			if timeToFill and queueData.waitingStartTime > 0 and (now > queueData.waitingStartTime + timeToFill) then
				local playersInQueue = #queueData.players
				if playersInQueue > 0 and playersInQueue < queueData.settings.maxPlayers then
					local botsNeeded = queueData.settings.maxPlayers - playersInQueue
					print(("[QueueManager] Tempo de espera esgotado. Adicionando %d bot(s) à fila %s."):format(botsNeeded, queueName))

					local spawnedBots = {}
					for i = 1, botsNeeded do
						local bot = spawnNPC("Bot_"..i)
						if bot then
							table.insert(spawnedBots, bot)
						end
					end

					-- Inicia a partida imediatamente com os jogadores e os bots
					startMatch(queueData, spawnedBots)
				end
				-- >>> FIM DA NOVA LÓGICA DE BOTS <<<
			else
				if #queueData.players >= queueData.settings.minPlayers then
					queueData.countdownActive = true
					queueData.startTime = now
					print(("[QueueManager] Countdown iniciado para a fila %s."):format(queueName))
				end
			end
		end
	end
end




	RunService.Heartbeat:Connect(function()
		-- Roda a uma frequência menor que Heartbeat para não pesar no servidor
		if os.clock() % 1 > 0.5 and (os.clock() - 0.016) % 1 < 0.5 then
			QueueManager.update()
		end
	end)


-- Inicia o loop de atualização


return QueueManager