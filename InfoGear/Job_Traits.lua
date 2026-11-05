--[[
	Job_Traits.lua

	Every "job trait by level" ladder used by InfoGear lives here as DATA, plus the few helpers that read them.
	Previously each ladder was a hand-written if/elseif chain (and the Blue Mage trait code was copy-pasted into
	six different functions).

	Ladder format:   { {first_level, value}, {first_level, value}, ... }   sorted by first_level, ascending.
	A ladder returns the value of the highest row whose first_level <= the player's level (0 / default if none),
	so a level can never fall into a "gap" between two tiers.
]]

-- Returns the value of the highest tier reached at `level`.
function by_level(ladder, level, default)
	local result = default or 0
	if not ladder then return result end
	for i = 1, #ladder do
		if level >= ladder[i][1] then
			result = ladder[i][2]
		else
			break
		end
	end
	return result
end

-- Job points spent on the current main job.
function job_points_spent()
	return player.job_points[player.main_job:lower()]['jp_spent']
end

-- Sum of one named job-point-gift effect (e.g. 'Dual Wield Effect') unlocked at the current JP total.
function gift_bonus(effect_name)
	local jp = job_points_spent()
	local total = 0
	for threshold, effects in pairs(Gifts[player.main_job]['Gifts']) do
		if threshold <= jp then
			local value = effects[effect_name]
			if value then total = total + value end
		end
	end
	return total
end

-- Blue Mage: how many ranks of a trait the set spells give, including the job point boost.
--   partial_rank_gets_boost = false  -> a trait needs at least one FULL rank (8 points) to count (acc/eva/att/def)
--   partial_rank_gets_boost = true   -> any points at all make the job point boost count (dual wield / store TP)
-- Spells that are missing from res/Blue_Mage_Spells.lua are ignored instead of crashing.
function blu_trait_rank(trait, partial_rank_gets_boost)
	local mjob_data = windower.ffxi.get_mjob_data()
	if not mjob_data or not mjob_data.spells then return 0 end
	
	local points = 0
	for _, spell_id in pairs(mjob_data.spells) do
		local spell = Blu_spells[spell_id]
		if spell_id ~= 512 and spell and spell.trait == trait then
			points = points + spell.points
		end
	end
	
	local rank = math.floor(points / 8)
	if rank > 0 or (partial_rank_gets_boost and points > 0) then
		local jp = job_points_spent()
		local boost = 0
		if jp >= 1200 then boost = 2 elseif jp >= 100 then boost = 1 end
		return rank + boost
	end
	return 0
end

----------------------------------------------------------------------------------------------------------
-- Accuracy / Evasion / Attack / Defense bonuses from the main and sub job
----------------------------------------------------------------------------------------------------------
Job_Traits = {
	acc = {
		gift = 'Physical Accuracy Bonus', blu_trait = 'Accuracy',
		blu = {[1] = 10, [2] = 22, [3] = 35, [4] = 48, [5] = 60, [6] = 73},
		main = {
			RNG = {{10, 10}, {30, 22}, {50, 35}, {70, 48}, {86, 60}, {96, 73}},
			DRG = {{30, 10}, {60, 22}, {76, 35}},
			DNC = {{30, 10}, {60, 22}, {76, 35}},
			RUN = {{50, 10}, {70, 22}, {90, 35}},
		},
		sub = {
			RNG = {{10, 10}, {30, 22}},
			DRG = {{30, 10}},
			DNC = {{30, 10}},
		},
	},
	eva = {
		gift = 'Physical Evasion Bonus', blu_trait = 'Evasion',
		blu = {[1] = 10, [2] = 22, [3] = 35, [4] = 48, [5] = 60},
		main = {
			THF = {{10, 10}, {30, 22}, {50, 35}, {70, 48}, {76, 60}, {88, 72}},
			DNC = {{15, 10}, {45, 22}, {75, 35}, {86, 48}},
			-- NOTE: the original code gave PUP nothing at levels 60-76 (its ">76" looks like a typo for ">59").
			-- That behaviour is kept here on purpose; check it against the game data and change the 0 if it is wrong.
			PUP = {{20, 10}, {40, 22}, {60, 0}, {77, 35}},
		},
		sub = {
			THF = {{10, 10}, {30, 22}},
			DNC = {{15, 10}, {45, 22}},
			PUP = {{20, 10}, {40, 22}},
		},
	},
	att = {
		gift = 'Physical Attack Bonus', blu_trait = 'Attack',
		blu = {[1] = 10, [2] = 22, [3] = 35, [4] = 48, [5] = 60, [6] = 72},
		main = {
			DRK = {{10, 10}, {30, 22}, {50, 35}, {70, 48}, {76, 60}, {83, 72}, {91, 84}, {99, 96}},
			DRG = {{10, 10}, {91, 22}},
			WAR = {{30, 10}, {65, 22}, {90, 35}},
		},
		sub = {
			DRK = {{10, 10}, {30, 22}},
			DRG = {{10, 10}},
			WAR = {{30, 10}},
		},
	},
	def = {
		gift = 'Physical Defense Bonus', blu_trait = 'Defense Bonus',
		blu = {[1] = 10, [2] = 22, [3] = 35, [4] = 48, [5] = 60, [6] = 72},
		main = {
			PLD = {{10, 10}, {30, 22}, {50, 35}, {70, 48}, {76, 60}, {91, 72}},
			WAR = {{10, 10}, {45, 22}, {86, 35}},
		},
		sub = {
			PLD = {{10, 10}, {30, 22}},
			WAR = {{10, 10}, {45, 22}},
		},
	},
}

local function job_trait_bonus(t)
	local sub_value = 0
	if player.sub_job then
		sub_value = by_level(t.sub[player.sub_job:upper()], player.sub_job_level)
	end
	
	local main_value
	if player.main_job == 'BLU' then
		main_value = t.blu[blu_trait_rank(t.blu_trait, false)] or 0
	else
		main_value = by_level(t.main[player.main_job], player.main_job_level)
	end
	
	-- the better of main/sub job, plus the job point gifts (which only ever come from the main job)
	return math.max(sub_value, main_value) + gift_bonus(t.gift)
end

function get_player_acc_from_job() return job_trait_bonus(Job_Traits.acc) end
function get_player_eva_from_job() return job_trait_bonus(Job_Traits.eva) end
function get_player_att_from_job() return job_trait_bonus(Job_Traits.att) end
function get_player_def_from_job() return job_trait_bonus(Job_Traits.def) end

----------------------------------------------------------------------------------------------------------
-- Smite (extra attack multiplier for two-handed weapons and hand-to-hand)
----------------------------------------------------------------------------------------------------------
Smite_Ladders = {
	main = {
		DRK = {{15, 0.097}, {35, 0.15}, {55, 0.199}, {75, 0.25}, {95, 0.296}},
		WAR = {{35, 0.097}, {65, 0.15}, {95, 0.199}},
		MNK = {{40, 0.097}, {80, 0.15}},
		DRG = {{40, 0.097}, {80, 0.15}},
		PUP = {{60, 0.097}},
	},
	sub = {
		DRK = {{15, 0.097}, {35, 0.15}},
		WAR = {{35, 0.097}},
		MNK = {{40, 0.097}},
		DRG = {{40, 0.097}},
	},
}

function get_smite()
	local sub_value = 0
	if player.sub_job then
		sub_value = by_level(Smite_Ladders.sub[player.sub_job:upper()], player.sub_job_level)
	end
	local main_value = by_level(Smite_Ladders.main[player.main_job:upper()], player.main_job_level)
	return math.max(sub_value, main_value)
end

----------------------------------------------------------------------------------------------------------
-- Store TP
----------------------------------------------------------------------------------------------------------
Store_TP_Ladders = {
	-- Samurai. (The original code had off-by-one gaps at levels 30/31, 50/51, 70/71 and 90/91 that returned 0.)
	main = {SAM = {{10, 10}, {30, 15}, {50, 20}, {70, 25}, {90, 30}}},
	sub  = {SAM = {{10, 10}, {30, 15}}},
	blu  = {[1] = 10, [2] = 15, [3] = 20, [4] = 25, [5] = 30},
}

function determine_stp()
	local sub_job_tp = 0
	if player.sub_job then
		sub_job_tp = by_level(Store_TP_Ladders.sub[player.sub_job], player.sub_job_level)
	end
	
	local main_job_tp = 0
	if player.main_job == 'BLU' then
		main_job_tp = Store_TP_Ladders.blu[blu_trait_rank('Store TP', true)] or 0
	else
		main_job_tp = by_level(Store_TP_Ladders.main[player.main_job], player.main_job_level)
	end
	
	return math.max(sub_job_tp, main_job_tp)
end

----------------------------------------------------------------------------------------------------------
-- Dual Wield
----------------------------------------------------------------------------------------------------------
Dual_Wield_Ladders = {
	main = {
		NIN = {{10, 10}, {25, 15}, {45, 25}, {65, 30}, {85, 35}},
		DNC = {{20, 10}, {40, 15}, {60, 25}, {80, 30}},
		THF = {{83, 10}, {90, 15}, {98, 25}},
	},
	sub = {DNC = 15, NIN = 25},      -- flat values, no level requirement in the original code
	blu = {[1] = 10, [2] = 15, [3] = 25, [4] = 30, [5] = 35, [6] = 40},
}

function determine_DW()
	local sub_job_dw = 0
	if player.sub_job then
		sub_job_dw = Dual_Wield_Ladders.sub[player.sub_job] or 0
	end
	
	local main_job_dw = 0
	if player.main_job == 'BLU' then
		main_job_dw = Dual_Wield_Ladders.blu[blu_trait_rank('Dual Wield', true)] or 0
	else
		main_job_dw = by_level(Dual_Wield_Ladders.main[player.main_job], player.main_job_level)
	end
	
	-- job point gifts are added to the main job's value BEFORE it is compared with the sub job
	main_job_dw = main_job_dw + gift_bonus('Dual Wield Effect')
	
	return math.max(sub_job_dw, main_job_dw)
end

----------------------------------------------------------------------------------------------------------
-- Hand-to-hand base delay (Monk / Puppetmaster main or sub job)
----------------------------------------------------------------------------------------------------------
Martial_Arts_Delay_Ladders = {
	-- value = base delay; 480 is the delay of bare hands with no martial arts trait
	main = {
		MNK = {{1, 400}, {2, 380}, {31, 360}, {46, 340}, {61, 320}, {75, 300}, {82, 280}},
		PUP = {{25, 400}, {50, 380}, {75, 360}, {87, 340}, {97, 320}},
	},
	sub = {
		MNK = {{1, 400}, {2, 380}, {31, 360}, {46, 340}},
		PUP = {{25, 400}},
	},
}

-- Returns the main job's and the sub job's base hand-to-hand delay.
function martial_arts_base_delays()
	local main_delay = by_level(Martial_Arts_Delay_Ladders.main[player.main_job], player.main_job_level, 480)
	local sub_delay = 480
	if player.sub_job then
		sub_delay = by_level(Martial_Arts_Delay_Ladders.sub[player.sub_job], player.sub_job_level, 480)
	end
	return main_delay, sub_delay
end
