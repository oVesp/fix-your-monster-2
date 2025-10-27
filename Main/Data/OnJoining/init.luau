local RP = game:GetService('ReplicatedStorage');

local queue_functions = require(script:WaitForChild('QueueFunctions'));

local CURRENT_UPDATE = 1

local module = {

	--function(plr, data) -- initial values
	--	if not data.Value.NewPlayer then return end
			
	--	data.Value.NewPlayer = false;
	--end,
	
	function(plr, data)

		--if data.Value.Monster then return end
		if not data.Value.NewPlayer then print("already has monster") return end
		print("no monster")
		local monster = _G.MONSTERGENERATOR.RollMonster()
		print(data)
		
		-- Initialize Stats and Moves tables if they don't exist (since template doesn't define them)
		if not data.Value.Monster.Stats then
			data.Value.Monster.Stats = {}
		end
		if not data.Value.Monster.Moves then
			data.Value.Monster.Moves = {}
		end
		
		-- Copy all monster data
		for k, v in pairs(monster) do
			if k == "Stats" then
				-- Copy stats individually to ensure they're all set
				for statKey, statValue in pairs(v) do
					data.Value.Monster.Stats[statKey] = statValue
				end
			elseif k == "Moves" then
				-- Copy moves individually
				for moveKey, moveValue in pairs(v) do
					data.Value.Monster.Moves[moveKey] = moveValue
				end
			else
				-- Copy other fields directly
				data.Value.Monster[k] = v
			end
		end
		
		data.Value.NewPlayer = false;

	end,

	function(plr, data) -- migrate existing players with empty Stats/Moves
		-- Check if player already has a monster but Stats or Moves are empty/corrupted
		if data.Value.NewPlayer then return end -- Skip new players
		
		local monster = data.Value.Monster
		if not monster then return end -- No monster data at all
		
		-- Check if Stats or Moves are empty or missing
		local needsStatsMigration = not monster.Stats or (type(monster.Stats) == "table" and next(monster.Stats) == nil)
		local needsMovesMigration = not monster.Moves or (type(monster.Moves) == "table" and next(monster.Moves) == nil)
		
		if needsStatsMigration or needsMovesMigration then
			print("Migrating corrupted data for player:", plr.Name)
			
			-- Regenerate monster data based on existing race and level
			local newMonster = _G.MONSTERGENERATOR.RollMonster(plr.UserId, false, {
				race = monster.Race,
				level = monster.Level or 1,
				stage = monster.Stage
			})
			
			-- Only fix Stats if corrupted
			if needsStatsMigration then
				monster.Stats = {}
				for statKey, statValue in pairs(newMonster.Stats) do
					monster.Stats[statKey] = statValue
				end
				print("Restored Stats for", plr.Name)
			end
			
			-- Only fix Moves if corrupted
			if needsMovesMigration then
				monster.Moves = {}
				for moveKey, moveValue in pairs(newMonster.Moves) do
					monster.Moves[moveKey] = moveValue
				end
				print("Restored Moves for", plr.Name)
			end
		end
	end,

	function(plr, data) -- update versioning: game version is now up-to-date
		local last_played = data.Value.LastUpdatePlayed;

		if last_played and tonumber(last_played) >= CURRENT_UPDATE then return end
		


		data.Value.LastUpdatePlayed = tostring(CURRENT_UPDATE)
	end,

	function(plr, data) -- data versioning: data is now up-to-date
		while not _G.DATA do task.wait(1) end
		
		data.Value.Version = _G.DATA.Template.Version
	end,

	function(plr, data) -- process_queue
		data.ProcessQueue:Connect(function(id, values_array) data:Remove(id)
			for _, pack in ipairs(values_array) do
				if not queue_functions[pack.key] then continue end

				for k, v in pairs(pack) do
					print(k, v)
				end

				queue_functions[pack.key](plr, pack.info)
			end
		end);
	end,
}

return module
