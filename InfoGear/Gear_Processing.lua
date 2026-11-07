
-- (v1.11) Unity Ranking value for your rank (//ig rank): rank 1 gives max, the formula is GearInfo's. Works for
-- negative ranges too (Enmity-5 to -10).
function unity_value(min, max, rank)
	rank = tonumber(rank) or 1
	local sign = (max < 0 or min < 0) and -1 or 1
	min, max = math.abs(min), math.abs(max)
	-- (the tiny epsilon stops e.g. 25 / 11 * 11 = 24.999... rounding down to 24)
	return sign * (math.floor(((max - min) / 11) * (11 - (rank - 1)) + 0.0000001) + min)
end

function find_all_values(item)
	-- notice(item.id)
	local temp = check_for_augments(item)
	local augs = Extdata.decode(item).augments
	
	local item = res.items[item.id]
	if not item then return nil end   -- item newer than the installed resources
	
	if item.flags:contains('Equippable') then
	
		if res.item_descriptions[item.id] then
			item.discription = string.gsub(res.item_descriptions[item.id].en, '\n', ' ') 
		else
			item.discription = 'none'
		end
		
		descript_table = T{}
		descript_table = desypher_description(item.discription, item)
		
		item.defined_job = T{}
		
		for k, v in pairs(item.jobs) do
			item.defined_job[k] = res.jobs[k].ens	
		end
		
		item.defined_slots = T{}
		for k, v in pairs(item.slots) do
			item.defined_slots[k] = res.slots[k].en	
		end
	
		local edited_item = T{en=item.en, id=item.id, category=item.category , discription = item.discription, jobs = item.defined_job, slots = item.defined_slots}
		
			--item_level
		if item.item_level then
			edited_item.item_level = item.item_level
		end
		
		if augs then edited_item.augments = augs end
		
		for k, v in pairs(descript_table) do
			edited_item[k] = v
		end
		
		-- Check "Enhances \"Dual Wield\" effect" Gear for value
		local dw_gear = DW_Gear[item.id]
		if dw_gear then
			edited_item['Dual Wield'] = (edited_item['Dual Wield'] or 0) + dw_gear["Dual Wield"]
		end
		
		-- Check Unity gear for stat and value.
		local unity = Unity_rank[item.id]
		if unity then
			-- (v1.11) the table can give several stats per item; same rank formula as before
			local applied = {}
			for _, u in ipairs(unity.stats or {}) do
				local value = unity_value(u.min, u.max, settings.player.rank)
				edited_item[u.stat] = (edited_item[u.stat] or 0) + value
				applied[#applied + 1] = u.stat .. ' ' .. (value >= 0 and '+' or '') .. tostring(value)
			end
			edited_item['Unity Ranking Bonus Applied'] = table.concat(applied, ', ')
		end
		
		local set_bonus_entry = Set_bonus_by_item_id[item.id]
		if set_bonus_entry then
			edited_item['Set Bonus'] = {["set id"] = set_bonus_entry["set id"], ["bonus"] = set_bonus_entry["bonus"] }
		end
		
		if item.category == 'Weapon' then
			for k,v in pairs(item) do
				-- if k == 'delay' then	
					-- edited_item[k] = tonumber(v)
				-- end
				if k == 'skill' then
					local skill = res.skills[v].en
					edited_item[k] = skill
				end
			end
		end
		
		if temp then
			local temp_augments = T{}
			for k, v in pairs(temp) do
				temp_augments[k] = v
			end
			
			for k, v in pairs(temp_augments) do
				if edited_item[k] then
					edited_item[k] = edited_item[k] + v
				else
					edited_item[k] = v
				end
			end
		end

		return edited_item
	end
		
end

function check_for_augments(item)
	
	local augs = Extdata.decode(item).augments
	local item_t = res.items[item.id]
	local temp = T{}
	if augs then
		for k,v in pairs(augs) do
			-- (v1.18) pet lines ("Pet: Damage taken -5%", "Pet: "Regen"+10") go through desypher_description too: it
			-- reads the pet's Damage taken / Regen into Pet DT / Pet Regen and cuts the rest off, so nothing of the
			-- pet's counts as yours. (Before, every pet line was skipped.)
			if type(v) == 'string' then
				for i, j in pairs(desypher_description(v, item_t)) do
					if type(j) == 'number' then
						temp[i] = (temp[i] or 0) + j
					end
				end
			end
		end
		return temp
	else
		return nil
	end
	
end

-- (v1.7) see desypher_description
local conditional_prefixes = {
	'Pet:', 'Avatar:', 'Wyvern:', 'Automaton:', 'Luopan:', 'Trust:', 'Fellow:', 'Summoned Pet:',
	'Latent effect:', 'Latent Effect:', 'Unity Ranking:', 'Set:', 'Song effects:', 'Enchantment:', 'Aftermath:',
	'Reives:', 'Campaign:', 'Besieged:', 'Assault:', 'Salvage:', 'Domain Invasion:', 'Legion:', 'Garrison:',
	'Nighttime:', 'Daytime:', 'Dusk to dawn:', 'Full Moon:', 'Right ear:', 'Left ear:', 'Right ring:', 'Left ring:',
	'All Jumps:', 'Grimoire:', 'Zanshin:', 'Innin:', 'Yonin:', 'Climactic Flourish:', 'Minuet:', 'Depending on day',
	'Citizens of ', 'Silence:', 'Paralysis:', 'Weather:',
}
local conditional_patterns = {'Vs%. [%a ]+:', 'On [%a ]+days?:', '[%a]+ weather:', 'In [%a]+:', '[%a]+sdays? or [%a]+sdays?:'}

function cut_conditional_stats(text)
	local cut = nil
	for _, prefix in ipairs(conditional_prefixes) do
		local i = text:find(prefix, 1, true)
		if i and (not cut or i < cut) then cut = i end
	end
	for _, pat in ipairs(conditional_patterns) do
		local i = text:find(pat)
		if i and (not cut or i < cut) then cut = i end
	end
	if cut then return text:sub(1, cut - 1) end
	return text
end

-- (v1.12) Damage taken your gear gives your pet: the "Pet:", "Wyvern:", "Avatar:", "Automaton:" and "Luopan:"
-- parts of a description, all added together (one Pet DT card). Each part runs until the next prefix.
local pet_prefixes = {'Pet:', 'Wyvern:', 'Avatar:', 'Automaton:', 'Luopan:'}

function pet_damage_taken(text)
	local found = {}
	for _, prefix in ipairs(pet_prefixes) do
		local start = 1
		while true do
			local i = text:find(prefix, start, true)
			if not i then break end
			local part = text:sub(i + #prefix)
			local cut = #part + 1
			for _, p in ipairs(conditional_prefixes) do
				local j = part:find(p, 1, true)
				if j and j < cut then cut = j end
			end
			for _, pat in ipairs(conditional_patterns) do
				local j = part:find(pat)
				if j and j < cut then cut = j end
			end
			found[#found + 1] = part:sub(1, cut - 1)
			start = i + #prefix
		end
	end
	local total = {}
	local function add(key, v) total[key] = (total[key] or 0) + tonumber(v) end
	for _, part in ipairs(found) do
		-- (v1.15) "Absorbs damage taken +18%" (Peltast's Mezail...) is an absorb effect, not damage taken: skip it
		part = part:gsub('[Aa]bsorbs [%a ]-damage taken%s?[+-]?%d*%%?', '')
		part = part:gsub('[Pp]hysical [Dd]amage taken%s?([+-]%d+)', function(v) add('Pet PDT', v) return '' end)
		part = part:gsub('[Pp]hys%.%s?dmg%.%s?taken%s?([+-]%d+)', function(v) add('Pet PDT', v) return '' end)
		part = part:gsub('[Mm]agic [Dd]amage taken%s?([+-]%d+)', function(v) add('Pet MDT', v) return '' end)
		part = part:gsub('[Mm]agic dmg%.%s?taken%s?([+-]%d+)', function(v) add('Pet MDT', v) return '' end)
		part = part:gsub('[Bb]reath [Dd]amage taken%s?([+-]%d+)', '')	-- not shown
		-- (v1.17) "Regen"+N; "Adds "Regen" effect" gives no number, so it can't be counted
		part = part:gsub('\"Regen\"%s?([+-]%d+)', function(v) add('Pet Regen', v) return '' end)
		part = part:gsub('[Dd]amage taken%s?([+-]%d+)', function(v) add('Pet DT', v) return '' end)
	end
	return total
end

function desypher_description(discription_string, item_t)
	local pet_dt = pet_damage_taken(discription_string)	-- (v1.12) before the pet parts are cut off
	
	-- string that need modifying to stop clashing
	discription_string = string.gsub(discription_string, 'Ranged Accuracy%s?', 'Ranged_accuracy') 
	discription_string = string.gsub(discription_string, 'Rng.%s?Acc.%s?', 'Ranged_accuracy')  
	discription_string = string.gsub(discription_string, 'Ranged Attack%s?', 'Ranged_attack') 
	discription_string = string.gsub(discription_string, 'Rng.%s?Atk.%s?', 'Ranged_attack') 
	
	discription_string = string.gsub(discription_string, 'Magic Accuracy%s?', 'Magic_accuracy')
	discription_string = string.gsub(discription_string, 'Mag.%s?Acc.%s?', 'Magic_accuracy') 	
	discription_string = string.gsub(discription_string, 'Magic Acc.%s?', 'Magic_accuracy') 
	
	-- (v1.7) stats that look like other stats but aren't: give them names nothing matches
	discription_string = string.gsub(discription_string, 'Magic [Cc]ritical hit rate', 'MCRIT_rate' )
	discription_string = string.gsub(discription_string, 'Magic [Cc]ritical hit damage', 'MCRIT_dmg' )
	discription_string = string.gsub(discription_string, '\"?Cure\"? potency received', 'CURE_recv' )
	
	-- (v1.7) short forms used by augments and newer gear
	discription_string = string.gsub(discription_string, '\"Mag%.%s?Atk%.%s?Bns%.\"', 'Magic Atk. Bonus' )
	discription_string = string.gsub(discription_string, '\"Mag%.%s?Atk%.%s?B%.\"', 'Magic Atk. Bonus' )
	discription_string = string.gsub(discription_string, '\"Mag%.%s?Def%.%s?Bns%.\"', 'Magic Def. Bonus' )
	discription_string = string.gsub(discription_string, '\"Mag%.%s?Def%.%s?B%.\"', 'Magic Def. Bonus' )
	discription_string = string.gsub(discription_string, '\"M%.%s?Def%.%s?B%.\"', 'Magic Def. Bonus' )
	discription_string = string.gsub(discription_string, 'Mag%.%s?Eva%.', 'Magic_evasion' )
	discription_string = string.gsub(discription_string, 'Mag%.%s?Evasion', 'Magic_evasion' )
	discription_string = string.gsub(discription_string, 'Crit%.%s?hit rate', 'Critical hit rate' )
	discription_string = string.gsub(discription_string, 'Crit%.%s?hit damage', 'Critical hit damage' )
	discription_string = string.gsub(discription_string, '[Mm]agic burst damage II', 'MBB_2' )
	discription_string = string.gsub(discription_string, '[Mm]agic burst dmg%.%s?II', 'MBB_2' )
	discription_string = string.gsub(discription_string, '[Mm]agic burst damage', 'MBB_1' )
	discription_string = string.gsub(discription_string, '[Mm]agic burst dmg%.', 'MBB_1' )
	discription_string = string.gsub(discription_string, '\"Cure\" potency II', 'CURE_2' )
	discription_string = string.gsub(discription_string, 'Cure potency II', 'CURE_2' )
	discription_string = string.gsub(discription_string, '\"Cure\" potency', 'CURE_1' )
	discription_string = string.gsub(discription_string, 'Cure potency', 'CURE_1' )
	discription_string = string.gsub(discription_string, '[Ww]eapon [Ss]kill damage', 'WSD' )
	discription_string = string.gsub(discription_string, 'Physical damage limit', 'PDL' )
	discription_string = string.gsub(discription_string, '\"Phalanx\" received', 'Phalanx' )
	discription_string = string.gsub(discription_string, '\"Quad Attack\"', '\"Quadruple Attack\"' )
	-- (v1.27) "Spell interruption rate down 10%" (sometimes written -10%): stored as a positive number
	discription_string = string.gsub(discription_string, 'Spell interruption rate down%s?%-?(%d+)%%?', 'SIRD+%1' )
	-- (v1.18) augment short forms (Ambuscade capes etc.): "Dbl.Atk.", "Triple Atk.", and Eva. on its own
	-- (Mag. Eva. was already turned into Magic_evasion above, so what is left is plain evasion)
	discription_string = string.gsub(discription_string, '\"Dbl%.%s?Atk%.\"', '\"Double Attack\"' )
	discription_string = string.gsub(discription_string, '\"Triple%s?Atk%.\"', '\"Triple Attack\"' )
	discription_string = string.gsub(discription_string, '^Eva%.', 'Evasion' )
	discription_string = string.gsub(discription_string, '([%s/])Eva%.', '%1Evasion' )
	
	discription_string = string.gsub(discription_string, '\"Magic Atk. Bonus\"', 'Magic Atk. Bonus' )
	discription_string = string.gsub(discription_string, '\"Mag.%s?Atk.%s?Bns.\"', 'Magic Atk. Bonus' ) 
	
	discription_string = string.gsub(discription_string, 'Magic Evasion', 'Magic_evasion' )
	discription_string = string.gsub(discription_string, '\"Magic Def. Bonus\"', 'Magic Def. Bonus' )
	
	discription_string = string.gsub(discription_string, 'Crit. hit damage', 'Critical hit damage' )
	discription_string = string.gsub(discription_string, 'Crit. hit rate', 'Critical hit rate' )

	discription_string = string.gsub(discription_string, 'Physical [Dd]amage taken II', 'PDT_2' )
	discription_string = string.gsub(discription_string, 'Physical [Dd]amage taken', 'PDT' )	-- (v1.7) also "Physical Damage taken"
	discription_string = string.gsub(discription_string, 'Breath damage taken', 'BDT' )
	discription_string = string.gsub(discription_string, 'Breath dmg. taken', 'BDT' )
	discription_string = string.gsub(discription_string, 'Magic [Dd]amage taken II', 'MDT_2' )
	discription_string = string.gsub(discription_string, 'Magic [Dd]amage taken', 'MDT' )
	discription_string = string.gsub(discription_string, 'Phys. dmg. taken', 'PDT' )
	discription_string = string.gsub(discription_string, 'Magic dmg. taken', 'MDT' )
	discription_string = string.gsub(discription_string, 'Damage taken', 'D_T' )
	
	discription_string = string.gsub(discription_string, 'Weapon skill DEX', 'WS_dex' )
	
	discription_string = string.gsub(discription_string,  "Great Axe skill",  "Great axe skill")
	discription_string = string.gsub(discription_string,  "Great Katana skill",  "Great katana skill")
	discription_string = string.gsub(discription_string,  "Great Sword skill",  "Great sword skill")
	
	-- (v1.7) Everything after the first of these is a pet's stats, a set / unity bonus (handled by their own tables),
	-- or only applies sometimes (weather, day, area, latent...). Cut the description at the earliest one, so none of
	-- it counts as your own always-on stats. (Before, only six prefixes were checked, and in a fixed order.)
	discription_string = cut_conditional_stats(discription_string)
	
	local valid_strings = L{'Delay','DEF','HP','MP','STR','DEX','VIT','AGI','INT','MND','CHR',
								'Accuracy','Acc.','Attack','Atk.',
								'Ranged_accuracy', 'Ranged_attack',
								'Magic_accuracy', 'Magic Atk. Bonus',
								'Haste','\"Slow\"','\"Store TP\"','\"Dual Wield\"','\"Fast Cast\"','\"Martial Arts\"',
								'DMG','PDT','MDT','BDT','D_T','MDT_2','PDT_2',
								'Evasion',
								'Critical hit damage' ,'Critical hit rate', 
								"Hand%-to%-Hand skill", "Dagger skill", "Sword skill", "Great sword skill", "Axe skill", "Great axe skill",  "Scythe skill", "Polearm skill", 
								"Katana skill", "Great katana skill", "Club skill",  "Staff skill", "Archery skill", "Marksmanship skill" , "Throwing skill","Guarding skill","Evasion skill","Shield skill","Parrying skill",
								"Divine Magic skill","Healing Magic skill","Enhancing Magic skill","Enfeebling Magic skill","Elemental Magic skill","Dark Magic skill","Summoning Magic skill","Ninjutsu skill","Singing skill",
								"Stringed Instrument skill","Wind Instrument skill","Blue Magic skill","Geomancy skill","Handbell skill",
								"Phalanx",'All magic skills','All skills','Combat skills','Magic skills',
								-- (v1.7)
								'\"Double Attack\"','\"Triple Attack\"','\"Quadruple Attack\"',
								'\"Subtle Blow\"','\"Subtle Blow II\"',
								'Magic_evasion','Magic Def%. Bonus',
								'\"Snapshot\"','Snapshot','\"Rapid Shot\"',
								'MBB_1','MBB_2','CURE_1','CURE_2','WSD','PDL',
								'\"Regain\"','Regain','\"Refresh\"','\"Regen\"','\"Treasure Hunter\"','Enmity',
								'SIRD','\"Conserve MP\"',	-- (v1.27)
								}
	
	local temp_table = T{}
	local temp_key = { 
		['Delay'] = 'delay',
		["Acc."] = "Accuracy",
		["Atk."] = 'Attack',
		['\"Slow\"'] = 'Slow',
		['\"Store TP\"'] = 'Store TP', 
		['\"Dual Wield\"'] = 'Dual Wield' ,
		['\"Fast Cast\"'] = 'Fast Cast' ,
		['Magic_accuracy'] = 'Magic Accuracy' , 
		['Ranged_accuracy'] =  'Ranged Accuracy' ,
		['Ranged_attack'] =  'Ranged Attack' ,
		['Magic_evasion'] = 'Magic Evasion',
		["Great axe skill"] = "Great Axe skill" ,
		["Great katana skill"] = "Great Katana skill",
		["Great sword skill"] = "Great Sword skill",
		['DMG'] = 'damage',
		['D_T'] = 'DT',
		['MDT_2'] = 'MDT2',
		['PDT_2'] = 'PDT2',
		['\"Martial Arts\"'] = 'Martial Arts',
		['WS_dex'] = 'Weapon skill DEX',
		['\"Quadruple Attack\"'] = 'Quadruple Attack',
		['\"Triple Attack\"'] = 'Triple Attack',
		['\"Double Attack\"'] = 'Double Attack',
		-- (v1.7)
		['\"Subtle Blow\"'] = 'Subtle Blow',
		['\"Subtle Blow II\"'] = 'Subtle Blow II',
		['\"Snapshot\"'] = 'Snapshot',
		['\"Rapid Shot\"'] = 'Rapid Shot',
		['MBB_1'] = 'Magic Burst Bonus',
		['MBB_2'] = 'Magic Burst Bonus II',
		['CURE_1'] = 'Cure Potency',
		['CURE_2'] = 'Cure Potency II',
		['WSD'] = 'Weapon Skill Damage',
		['PDL'] = 'Physical Damage Limit',
		['\"Regain\"'] = 'Regain',
		['\"Refresh\"'] = 'Refresh',
		['\"Regen\"'] = 'Regen',
		['\"Treasure Hunter\"'] = 'Treasure Hunter',
		['SIRD'] = 'Spell Interruption Rate Down',	-- (v1.27)
		['\"Conserve MP\"'] = 'Conserve MP',
	}
	
	for k, v in pairs(pet_dt) do temp_table[k] = v end	-- (v1.12)
	for k, v in pairs(valid_strings) do
		-- v = DEF etc
		pattern = "("..v.."):?%s?([+-]?%d+)"
		for key , val in discription_string:gmatch(pattern) do
			
			if temp_key[key] then
				temp_table[temp_key[key]] = tonumber(val)
			else
				temp_table[key] = tonumber(val)	
			end
			-- if item_t then
				-- if item_t.id == 20540 then
					-- notice('('..discription_string .. ') '..key .. ' ' ..val)
				-- end
			-- end
		end
	end
	return temp_table
end

-- (v1.7) names used in res/Set_bonus_by_Set_ID.lua -> names used in the stat table
set_bonus_names = {
	['Critical Hit Rate'] = 'Critical hit rate',
	['Cure potency'] = 'Cure Potency',
	['Cure potency II'] = 'Cure Potency II',
}

function get_equip_stats(equipment_table)

	local stat_table = { ['Haste'] = 0, ['Slow'] = 0, ['Dual Wield'] = 0, ['Store TP'] = 0, ['Accuracy'] = 0, ['Attack'] = 0, ['Ranged Accuracy'] = 0, ['Ranged Attack'] = 0,
									['Evasion'] = 0,

									['DT'] = 0, ['PDT'] = 0, ['PDT2'] = 0, ['MDT'] = 0, ['MDT2'] = 0, ['BDT'] = 0,
									['DEF'] = 0,
							 
									["MND"]=0, ["AGI"]=0, ["DEX"]=0, ["VIT"]=0, ["STR"]=0, ["INT"]=0,  ["CHR"]=0, 
							 
									["Hand-to-Hand skill"]=0, ["Dagger skill"]=0, ["Sword skill"]=0, ["Great Sword skill"]=0, ["Axe skill"]=0, ["Great Axe skill"]=0, ["Scythe skill"]=0, ["Polearm skill"]=0, 
									["Katana skill"]=0, ["Great Katana skill"]=0,["Club skill"]=0,["Staff skill"]=0,["Archery skill"]=0,["Marksmanship skill"]=0,["Throwing skill"]=0,['Combat skills']=0,
									
									['Evasion skill'] = 0,
									
									-- (v1.7)
									['HP'] = 0, ['MP'] = 0, ['Fast Cast'] = 0, ['Magic Accuracy'] = 0, ['Magic Atk. Bonus'] = 0,
									['Magic Burst Bonus'] = 0, ['Magic Burst Bonus II'] = 0, ['Cure Potency'] = 0, ['Cure Potency II'] = 0,
									['Double Attack'] = 0, ['Triple Attack'] = 0, ['Quadruple Attack'] = 0,
									['Critical hit rate'] = 0, ['Critical hit damage'] = 0, ['Subtle Blow'] = 0, ['Subtle Blow II'] = 0,
									['Weapon Skill Damage'] = 0, ['Physical Damage Limit'] = 0, ['Snapshot'] = 0, ['Rapid Shot'] = 0,
									['Magic Evasion'] = 0, ['Magic Def. Bonus'] = 0, ['Phalanx'] = 0, ['Enmity'] = 0,
									['Regen'] = 0, ['Refresh'] = 0, ['Regain'] = 0, ['Treasure Hunter'] = 0,
									['Pet DT'] = 0, ['Pet PDT'] = 0, ['Pet MDT'] = 0,	-- (v1.12)
									['Pet Regen'] = 0,	-- (v1.17)
									['Spell Interruption Rate Down'] = 0, ['Conserve MP'] = 0,	-- (v1.27)
									
									['main'] = {['skill'] = '', value = 0}, ['sub'] = {['skill'] = '', value = 0}, ['range'] = {['skill'] = '', value = 0}, ['ammo'] = {['skill'] = '', value = 0},
								}
								
	local melee_skills = L{"Hand-to-Hand skill", "Dagger skill", "Sword skill", "Great Sword skill", "Axe skill", "Great Axe skill", "Scythe skill", "Polearm skill", "Katana skill", "Great Katana skill", "Club skill", "Staff skill"}
	local ranged_skills = L{"Archery skill", "Marksmanship skill", "Throwing skill"}
							
	local set_bonus = {}
	
	if type(equipment_table) ~= 'table' or equipment_table == nil then
		error('get_equip_stats() function went wrong')
		return stat_table
	else	
		for equip_slot, equipped_item in pairs(equipment_table) do
			for key, value in pairs(equipped_item) do
				if stat_table[key] then
					if equipped_item["category"]=="Weapon" then
						if equipped_item['skill'] then
							stat_table[equip_slot]['skill'] =  equipped_item['skill']
							if 	equipped_item[equipped_item['skill'] ..' skill'] then
								stat_table[equip_slot].value =  equipped_item[equipped_item['skill'] ..' skill']
							end
						end
						if not melee_skills:contains(key) and not ranged_skills:contains(key) then
							if key == 'Haste' then
								stat_table['Haste'] = stat_table['Haste'] + math.floor(value / 100 * 1024)
							elseif key == 'Slow' then
								stat_table['Haste'] = stat_table['Haste'] - math.floor(value / 100 * 1024)
							elseif key == 'Combat skills' then
								stat_table['main'].value = stat_table['main'].value + value
								stat_table['sub'].value = stat_table['sub'].value + value
								stat_table['range'].value = stat_table['range'].value + value
								stat_table['ammo'].value = stat_table['ammo'].value + value
							else
								stat_table[key] = stat_table[key] + value
							end
						end
					else
						if key == 'Haste' then
							stat_table['Haste'] = stat_table['Haste'] + math.floor(value / 100 * 1024)
						elseif key == 'Slow' then
							stat_table['Haste'] = stat_table['Haste'] - math.floor(value / 100 * 1024)
						elseif key == 'Combat skills' then
							stat_table['main'].value = stat_table['main'].value + value
							stat_table['sub'].value = stat_table['sub'].value + value
							stat_table['range'].value = stat_table['range'].value + value
							stat_table['ammo'].value = stat_table['ammo'].value + value
						else
							stat_table[key] = stat_table[key] + value
						end
					end
				elseif equip_slot == 'main' and equipped_item.en == '' then
					stat_table['main']['skill'] = 'Hand-to-Hand'
				end
				if key == "Set Bonus" then
					if type(value["set id"]) == 'table' then
						for i, j  in pairs(value["set id"]) do
							if set_bonus[j]  then
								set_bonus[j] = set_bonus[j] + 1
							else
								set_bonus[j]  = 1
							end
						end
					else
						if set_bonus[value["set id"]] then
							set_bonus[value["set id"]] = set_bonus[value["set id"]] + 1
						else
							set_bonus[value["set id"]]  = 1
						end
					end
				end
			end
		end

		for k, v in pairs(set_bonus) do
			if v > 1 then
				if v >= Set_bonus_by_Set_ID[k]["minimum peices"] then
					if Set_bonus_by_Set_ID[k]["bonus"][v] then
						for key, value in pairs(Set_bonus_by_Set_ID[k]["bonus"][v]) do
							key = set_bonus_names[key] or key	-- the set table spells a few names differently
							if stat_table[key] then
								stat_table[key] = stat_table[key] + value
							end
						end
					end
				end
			end
		end
	end
	-- table.vprint(stat_table['main'])
	stat_table['Haste'] = stat_table['Haste'] + manual_ghaste
	stat_table['Dual Wield'] = stat_table['Dual Wield'] + manual_dw
	stat_table['Store TP'] = stat_table['Store TP'] + manual_stp
	
	return stat_table
	
end

-- Converts a resource skill name ('Hand-to-Hand', 'Great Sword') into the key used by
-- windower.ffxi.get_player().skills ('hand_to_hand', 'great_sword').
function skill_key(skill_name)
	return (skill_name:lower():gsub('[%s%-]', '_'))
end

-- Adds everything that is NOT gear (base weapon skills, base STR/DEX/..., Blue Mage spell stats)
-- on top of the gear totals from get_equip_stats().
-- Call this exactly ONCE per update() and hand the result to get_player_acc / _att / _evasion / _defence.
-- (Previously get_player_acc() did this in place, so att/eva/def were only right while Acc was displayed.)
function build_combined_stats(stat_table)
	local slot_needs_damage = {main = false, sub = false, range = true, ammo = true}
	
	for skill_name, value in pairs(player_base_skills) do
		for slot, needs_damage in pairs(slot_needs_damage) do
			local slot_skill = stat_table[slot].skill
			if slot_skill ~= '' and skill_name == skill_key(slot_skill)
				and (not needs_damage or player.equipment[slot]['damage']) then
				stat_table[slot].value = stat_table[slot].value + value + (stat_table[slot_skill .. ' skill'] or 0)
			end
		end
	end
	
	if player.stats then
		for stat, value in pairs(player.stats) do
			if stat_table[stat] then 
				stat_table[stat] = stat_table[stat] + value 
			end	
		end
	end
	
	return get_blue_mage_stats_from_equipped_spells(stat_table)
end

-- stat_table must come from build_combined_stats(). This function no longer modifies it.
function get_player_acc(stat_table)
	
	local Total_acc = {main = 0, sub = 0, range = 0, ammo = 0, dex = 0, agi = 0}
	local main_acc_skill = acc_from_skill(stat_table['main'].value)
	local sub_acc_skill = acc_from_skill(stat_table['sub'].value )
	local ranged_acc_skill = racc_from_skill(stat_table['range'].value )
	local ammo_acc_skill = racc_from_skill(stat_table['ammo'].value )
	Total_acc.dex = math.floor(stat_table['DEX'] * 0.75)
	Total_acc.agi = math.floor(stat_table['AGI'] * 0.75)
	
	Total_acc.main = main_acc_skill + math.floor((stat_table['DEX']+ Buffs_inform['DEX']) * 0.75) + stat_table['Accuracy'] + get_player_acc_from_job() + Buffs_inform['Accuracy']

	if player.equipment.sub.id ~= 0 and player.equipment.sub.category == 'Weapon' and player.equipment.sub.damage then
		Total_acc.sub = sub_acc_skill + math.floor((stat_table['DEX']+ Buffs_inform['DEX']) * 0.75) + stat_table['Accuracy'] + get_player_acc_from_job() + Buffs_inform['Accuracy']
	else
		Total_acc.sub = 0
	end
	if player.equipment.range.id ~= 0 and player.equipment.range.category == 'Weapon' and player.equipment.range['damage'] then
		Total_acc.range = ranged_acc_skill + math.floor((stat_table['AGI']+ Buffs_inform['AGI']) * 0.75) + stat_table['Ranged Accuracy'] + get_player_acc_from_job() + Buffs_inform['Ranged Accuracy']
	else
		Total_acc.range = 0
	end
	if player.equipment.ammo.id ~= 0 and player.equipment.ammo.category == 'Weapon' and player.equipment.ammo['damage'] then
		Total_acc.ammo = ammo_acc_skill + math.floor((stat_table['AGI']+ Buffs_inform['AGI']) * 0.75) + stat_table['Ranged Accuracy'] + get_player_acc_from_job() + Buffs_inform['Ranged Accuracy']
	else
		Total_acc.ammo = 0
	end
	
	--notice('Main Acc = '.. Total_acc.main .. ' | Off hand Acc = '.. Total_acc.sub .. ' | Ranged Acc = '.. Total_acc.range .. ' | ammo Acc = '.. Total_acc.ammo)
	--log('Dex = '.. stat_table['DEX'] .. ' | Main skill  = '.. stat_table['main'].value .. ' | Sub skill = '.. stat_table['sub'].value .. ' | job acc = ' ..get_player_acc_from_job() .. ' | gear acc = ' .. stat_table['Accuracy'])
	--log('Agi = '.. stat_table['AGI'] .. ' | Range skill  = '.. stat_table['range'].value .. ' | Ammo skill = '.. stat_table['ammo'].value .. ' | job acc = ' ..get_player_acc_from_job().. ' | gear r.acc = ' .. stat_table['Ranged Accuracy'])
	
	--log(main_acc_skill.. ' ' .. item_acc .. ' ' .. get_player_acc_from_job() .. ' ' .. main_hand.value .. ' ' .. skill_from_gear_main .. ' ' ..item_dex .. ' ' .. player_dex )
	--log(ammo_acc_skill.. ' ' .. item_racc .. ' ' .. get_player_acc_from_job() .. ' ' .. ammo.value .. ' ' .. skill_from_gear_ammo .. ' ' ..item_agi .. ' ' .. player_agi )	
	return Total_acc
end

function get_player_att(stat_table)
	
	local stat_table = stat_table
	
	local two_handers ={ ["Great Sword"]=0, ["Great Axe"]=0, ["Scythe"]=0, ["Polearm"]=0, ["Great Katana"]=0,["Staff"]=0}
								
	--stat_table = get_blue_mage_stats_from_equipped_spells(stat_table)
	
	local Total_att = {main = 0, sub = 0, range = 0, ammo = 0, str = 0}
	
	
	-- Attack (2H) 
	if table.containskey(two_handers, stat_table['main']['skill']) then
		local base_attack = 8 + stat_table['main'].value + math.floor(3 * (stat_table['STR'] + Buffs_inform['STR']) / 4) + stat_table['Attack'] + get_player_att_from_job() + Buffs_inform['Attack']
		local multi = Buffs_inform['Attack perc'] / 1024
		local BA_multi = math.floor(base_attack * (1 + get_smite() + multi))
		Total_att.main = BA_multi
		--print(base_attack, get_smite(), multi, Buffs_inform['Attack perc'])
	-- Attack (H2H)
	elseif stat_table['main']['skill'] == 'Hand-to-Hand' then
		local base_attack = 8 + stat_table['main'].value + math.floor(5 * (stat_table['STR'] + Buffs_inform['STR']) / 8) + stat_table['Attack'] + get_player_att_from_job() + Buffs_inform['Attack']
		local multi = Buffs_inform['Attack perc'] / 1024
		local BA_multi = math.floor(base_attack * (1 + get_smite() + multi))
		Total_att.main = BA_multi
	-- Attack (1H main)
	else
		local base_attack = 8 + stat_table['main'].value + math.floor(3 * (stat_table['STR'] + Buffs_inform['STR']) / 4) + stat_table['Attack'] + get_player_att_from_job() + Buffs_inform['Attack']
		local multi = Buffs_inform['Attack perc'] / 1024
		local BA_multi = math.floor(base_attack * (1 + multi))
		Total_att.main = BA_multi
	end
	
	-- Attack (1H sub)
	if player.equipment.sub.id ~= 0 and player.equipment.sub.category == 'Weapon' and player.equipment.sub.damage then
		local base_attack = 8 + stat_table['sub'].value + math.floor( (stat_table['STR'] + Buffs_inform['STR']) / 2) + stat_table['Attack'] + get_player_att_from_job() + Buffs_inform['Attack']
		local multi = Buffs_inform['Attack perc'] / 1024
		local BA_multi = math.floor(base_attack * (1 + multi))
		Total_att.sub = BA_multi
	end
	-- Ranged Attack
	if player.equipment.range.id ~= 0 and player.equipment.range.category == 'Weapon' and player.equipment.range['damage'] then
		local base_attack = 8 + stat_table['range'].value + math.floor(3 * (stat_table['STR'] + Buffs_inform['STR']) / 4) + stat_table['Ranged Attack'] + get_player_att_from_job() + Buffs_inform['Attack']
		local multi = Buffs_inform['Attack perc'] / 1024
		local BA_multi = math.floor(base_attack * (1 + multi))
		Total_att.range = BA_multi
	end
	
	if player.equipment.range.id == 0 and player.equipment.ammo.id ~= 0 and player.equipment.ammo.category == 'Weapon' and player.equipment.ammo['damage'] then
		local base_attack = 8 + stat_table['ammo'].value + math.floor(3 * (stat_table['STR'] + Buffs_inform['STR']) / 4) + stat_table['Ranged Attack'] + get_player_att_from_job() + Buffs_inform['Attack']
		local multi = Buffs_inform['Attack perc'] / 1024
		local BA_multi = math.floor(base_attack * (1 + multi))
		Total_att.ammo = BA_multi
	end
	
	return Total_att
end

function get_player_evasion(stat_table)
	
	-- work on a local copy of the one number we change, never on the shared table
	local evasion_skill = stat_table['Evasion skill'] + (player_base_skills['evasion'] or 0)
	
	local evasion = math.floor( (stat_table['AGI'] + Buffs_inform['AGI'])/2 ) + ( eva_from_skill(evasion_skill) ) + ( get_player_eva_from_job() + stat_table['Evasion'] + Buffs_inform['Evasion'])
	return evasion
end

function get_player_defence(stat_table)
	
	local stat_table = stat_table
	local defence = 0
	--notice(stat_table['AGI'] .. ' | ' .. stat_table['Evasion skill'] .. ' | ' .. eva_from_skill(stat_table['Evasion skill'] ) .. ' | ' .. get_player_eva_from_job().. ' | ' .. stat_table['Evasion'])
	if player.main_job_level < 51 then
		defence = math.floor(3*stat_table['VIT']/2) + player.main_job_level + 8
	elseif player.main_job_level > 50 and player.main_job_level < 61 then
		defence = math.floor(3*stat_table['VIT']/2) + (2 * player.main_job_level ) - 48
	elseif player.main_job_level > 60 and player.main_job_level < 90 then
		defence = math.floor(3*stat_table['VIT']/2) + ( player.main_job_level ) + 18
	else
		defence = math.floor(3*stat_table['VIT']/2) + ( player.main_job_level ) + 18 + math.floor( (player.main_job_level - 89) / 2 )
	end
	defence = defence + stat_table['DEF'] + get_player_def_from_job() + Buffs_inform['DEF']
	-- buff VIT (the formulas above use gear + base VIT only) and Barrier bubbles (% on the 1/1024 scale)
	defence = defence + math.floor(3 * Buffs_inform['VIT'] / 2)
	defence = math.floor(defence * (1 + Buffs_inform['Defense perc'] / 1024))

	return defence
end

function get_blue_mage_stats_from_equipped_spells(stat_table)

	local mjob_data = windower.ffxi.get_mjob_data()
	if not mjob_data or not mjob_data.spells then
		return stat_table
	end
	
	local spells_set = T(mjob_data.spells):filter(function(id) return id ~= 512 end):map(function(id) return id end)
	
	for key, spell_id in pairs(spells_set) do
		-- skip spells that are newer than res/Blue_Mage_Spells.lua instead of crashing
		if Blu_spells[spell_id] then
			for stat, value in pairs(Blu_spells[spell_id]) do
				if stat_table[stat] then 
					stat_table[stat] = stat_table[stat] + value 
				end
			end
		end
	end

	return stat_table
end

function get_player_skill_in_gear(equip)
	
	player_base_skills = player.skills
	
	-- string.gsub(sub_hand.skill, ' ', '_')
	local combat_skills = L{"hand_to_hand", "dagger", "sword", "great_sword", "axe", "great_axe",  "scythe", "polearm", 
										"katana", "great_katana", "club",  "staff", "archery", "marksmanship" , "throwing","guard","evasion","shield","parrying",}
	local magic_skills = L{"divine_magic","healing_magic","enhancing_magic","enfeebling_magic","elemental_magic","dark_magic","summoning_magic",
									"ninjutsu","singing","stringed Instrument","wind Instrument","blue_magic","geomancy","handbell"}
	local skills = L{"Hand-to-Hand skill", "Dagger skill", "Sword skill", "Great sword skill", "Axe skill", "Great axe skill",  "Scythe skill", "Polearm skill", 
							"Katana skill", "Great katana skill", "Club skill",  "Staff skill", "Archery skill", "Marksmanship skill" , "Throwing skill","Guard skill","Evasion skill","Shield skill","Parrying skill",
							"Divine Magic skill","Healing Magic skill","Enhancing Magic skill","Enfeebling Magic skill","Elemental Magic skill","Dark Magic skill","Summoning Magic skill","Ninjutsu skill","Singing skill",
							"Stringed Instrument skill","Wind Instrument skill","Blue Magic skill","Geomancy skill","Handbell skill",'All magic skills','Combat skills','Magic skills',
							}
	
	if equip then
		for slot ,item in pairs(equip) do
			if slot == 'main' or slot == 'sub' or slot == 'range' or slot == 'ammo' then
				if item.category == 'Weapon' then
					if item.damage == nil then
						if item.item_level == nil then
							for stat_key, value in pairs(item) do
								if skills:contains(stat_key) then
									str = string.gsub(stat_key, ' skill', '')
									if player_base_skills[string.gsub(str, ' ', '_'):lower()] then
										player_base_skills[string.gsub(str, ' ', '_'):lower()] = player_base_skills[string.gsub(str, ' ', '_'):lower()] - value
										-- notice('value 1 = ' .. value)
										-- break
									elseif player_base_skills['hand_to_hand'] and stat_key == "Hand-to-Hand skill" then
										player_base_skills['hand_to_hand'] = player_base_skills['hand_to_hand'] - value
									elseif stat_key == "Combat skills" then
										for k, player_skill in pairs(player_base_skills) do
											if combat_skills:contains(player_skill) then
												player_base_skills.player_skill = player_base_skills.player_skill - value
											end
										end
									elseif stat_key == 'All magic skills' or stat_key == 'Magic skills' then
										for k, player_skill in pairs(player_base_skills) do
											if magic_skills:contains(player_skill) then
												player_base_skills.player_skill = player_base_skills.player_skill - value
											end
										end
									end
								end
							end
						end
					end
				end
			else
				for stat_key, value in pairs(item) do
					if skills:contains(stat_key) then
						str = string.gsub(stat_key, ' skill', '')
						if player_base_skills[string.gsub(str, ' ', '_'):lower()] then
							player_base_skills[string.gsub(str, ' ', '_'):lower()] = player_base_skills[string.gsub(str, ' ', '_'):lower()] - value
							-- notice('value 2 = ' .. value .. ' for item: ' .. item.en)
							-- break
						elseif player_base_skills['hand_to_hand'] and stat_key == "Hand-to-Hand skill" then
							player_base_skills['hand_to_hand'] = player_base_skills['hand_to_hand'] - value
						elseif stat_key == "Combat skills" then
							for k, player_skill in pairs(player_base_skills) do
								if combat_skills:contains(player_skill) then
									player_base_skills.player_skill = player_base_skills.player_skill - value
								end
							end
						elseif stat_key == 'All magic skills' or stat_key == 'Magic skills' then
							for k, player_skill in pairs(player_base_skills) do
								if magic_skills:contains(player_skill) then
									player_base_skills.player_skill = player_base_skills.player_skill - value
								end
							end
						end
					end
				end
			end
		end
	end
	-- notice(player_base_skills.sword)
end
	
-- Converts a skill level into the accuracy / ranged accuracy / evasion it is worth.
-- (acc, ranged acc and evasion all use the same curve, so they share this one function.)
function rating_from_skill(skill)
	if skill < 200 then return skill end
	if skill < 400 then return math.floor((skill - 200) * 0.9) + 200 end
	if skill < 600 then return math.floor((skill - 400) * 0.8) + 380 end
	return math.floor((skill - 600) * 0.9) + 540
end
acc_from_skill = rating_from_skill
racc_from_skill = rating_from_skill
eva_from_skill = rating_from_skill
