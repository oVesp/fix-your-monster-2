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
		for k, v in pairs(monster) do
			data.Value.Monster[k] = v
		end
		
		for k,v in pairs(monster.Stats) do
			data.Value.Monster.Stats[k] = v
		end
		data.Value.NewPlayer = false;

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
