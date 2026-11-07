--[[
	Display.lua

	Everything that draws the on-screen widgets, plus update(), which is called from the prerender event.

	update() first calculates the numbers other code depends on (gear stats, total haste, DW needed) and ONLY THEN
	draws widgets. Previously some of those values (Total_haste, the DW flag, and the base stats used for
	attack/evasion/defence) were only calculated as a side effect of drawing the matching widget, so hiding a widget
	could silently change what was sent to Gearswap.

	Each widget block is identified by its index in sections.block[]. The on-screen slot of block N is N + 1.
]]

-------------------------------------------------------------------------------------------------------------
-- small helpers
-------------------------------------------------------------------------------------------------------------

-- Creates block `idx` if it does not exist yet. (`initial` is the first value text, it is overwritten right after.)
local function block(idx, color, label, initial)
	if not sections.block[idx] then
		sections.block[idx] = ImageBlock.New(idx + 1, 'block', color, label, initial or 00)
		sections.block[idx].label = label	-- (v1.27)
		check_positions()	-- place it (and move the others)
	end
	return sections.block[idx]
end

-- Deletes the listed blocks (those that exist).
local function remove_blocks(...)
	for _, idx in ipairs({...}) do
		if sections.block[idx] then sections.block[idx]:delete() end
	end
end

-- Sets the big number of a block. When `is_red` is given the number is coloured red (true) or white (false);
-- leave it nil to keep the colour as it is.
local function set_value(idx, value, is_red)
	local name = sections.block[idx].text[2].name
	sections.block[idx].value = value	-- (v1.27) read back by snapshots
	windower.text.set_text(name, value)
	if is_red == true then
		local c = alert_color or {255, 0, 0}	-- Image_processing.lua
		windower.text.set_color(name, 255, c[1], c[2], c[3])
	elseif is_red == false then
		windower.text.set_color(name, 255, 255, 255, 255)
	end
end

-- Sets the small caption of a block.
local function set_label(idx, text)
	sections.block[idx].label = text	-- (v1.27)
	windower.text.set_text(sections.block[idx].text[1].name, text)
end

-- Damage taken is stored as a negative number but shown as a positive one (and never as "-0").
local function negate(x)
	if x == 0 then return 0 end
	return -x
end

local function is_hand_to_hand()
	return player.equipment.main.skill == "Hand-to-Hand" or player.equipment.main.en == ''
end

-------------------------------------------------------------------------------------------------------------
-- widgets
-------------------------------------------------------------------------------------------------------------

-- blocks 1-4
local function update_haste_widgets()
	if settings.player.show_total_haste ~= true then
		remove_blocks(1, 2, 3, 4)
		return
	end
	block(1, 'red', 'Gear.H')
	block(2, 'red', 'Magic.H')
	block(3, 'red', 'JA.H')
	block(4, 'red', 'Total.H')
	
	local gear = Gear_info['Haste'] + Buffs_inform['g_haste']
	set_value(1, gear, gear > 256)
	
	local magic = Buffs_inform['ma_haste'] + manual_mhaste
	set_value(2, magic, magic > 448)
	
	local ja = Buffs_inform['ja_haste'] + manual_jahaste
	set_value(3, ja, ja > 256)
	
	set_value(4, Total_haste, Total_haste > 820)
end

-- One damage-taken widget. `specific` is PDT/MDT/BDT, `specific2` is the second tier (PDT2/MDT2) or 0.
local function damage_taken_widget(idx, specific, specific2)
	if specific2 < 0 then
		local total = specific + Gear_info['DT'] + specific2
		local cap = math.max(-50 + specific2, -87.6)
		set_value(idx, negate(total), total < cap)
	else
		local total = specific + Gear_info['DT']
		set_value(idx, negate(total), total < -51)
	end
end

-- blocks 5-8
local function update_dt_widgets()
	if settings.player.show_dt_Stuff ~= true then
		remove_blocks(5, 6, 7, 8)
		return
	end
	block(5, 'purple', 'DT')
	block(6, 'purple', 'PDT')
	block(7, 'purple', 'MDT')
	block(8, 'purple', 'BDT')
	
	set_value(5, negate(Gear_info['DT']), Gear_info['DT'] < -51)
	damage_taken_widget(6, Gear_info['PDT'], Gear_info['PDT2'])
	damage_taken_widget(7, Gear_info['MDT'], Gear_info['MDT2'])
	damage_taken_widget(8, Gear_info['BDT'], 0)
end

-- blocks 9, 10, 11 (melee) and 16, 17, 18 (ranged)
local function update_tp_widgets()
	if settings.player.show_tp_Stuff ~= true then
		remove_blocks(9, 10, 11, 16, 17, 18)
		return
	end
	
	Gear_TP = get_tp_per_hit()
	local melee = Gear_TP.tp_per_hit_melee
	local ranged = Gear_TP.tp_per_hit_range
	
	block(9, 'yellow', 'TP/h')
	block(10, 'yellow', 'to WS')
	set_value(9, melee)
	set_value(10, math.ceil(10000 / melee) / 10)
	
	if ranged > 0 then
		block(16, 'green', 'R.TP/h')
		block(17, 'green', 'R.to WS')
		set_value(16, ranged)
		set_value(17, math.ceil(10000 / ranged) / 10)
	else
		remove_blocks(16, 17)
	end
	
	if WSTP > 0 then
		block(11, 'yellow', 'aft WS')
		set_label(10, 'for WS')
		set_value(10, WSTP)
		set_value(9, math.ceil((10000 - (WSTP * 10)) / melee) / 10)
		if ranged > 0 then
			block(18, 'green', 'R.Aft WS')
			set_label(17, 'R.for WS')
			set_value(17, WSTP)
			set_value(16, math.ceil((10000 - (WSTP * 10)) / ranged) / 10)
		end
	else
		set_label(10, 'to WS')
		-- (the ranged caption used to be left on 'R.for WS' once the WS TP bonus went away)
		if sections.block[17] then set_label(17, 'R.to WS') end
		remove_blocks(11, 18)
	end
end

-- Accuracy (12, 13, ranged 19) and attack (14, 15, ranged 21) look the same, only the numbers differ.
local function main_sub_range_widgets(total, main_idx, sub_idx, range_idx, color_main, caption, range_caption)
	if total.sub > 0 then
		block(main_idx, color_main, caption .. '1')
		block(sub_idx, color_main, caption .. '2')
		set_label(main_idx, caption .. '1')
		set_value(main_idx, total.main)
		set_value(sub_idx, total.sub)
	else
		block(main_idx, color_main, caption)
		set_label(main_idx, caption)
		set_value(main_idx, total.main)
		remove_blocks(sub_idx)
	end
	
	if total.range > 0 then
		block(range_idx, 'green', range_caption)
		set_value(range_idx, total.range)
	elseif total.range == 0 and total.ammo > 0 then
		block(range_idx, 'green', range_caption)
		set_value(range_idx, total.ammo)
	else
		remove_blocks(range_idx)
	end
end

local function update_acc_widgets()
	if settings.player.show_acc_Stuff ~= true then
		remove_blocks(12, 13, 19)
		return
	end
	main_sub_range_widgets(get_player_acc(Gear_info), 12, 13, 19, 'yellow', 'Acc.', 'R.Acc.')
end

local function update_att_widgets()
	if settings.player.show_att_Stuff ~= true then
		remove_blocks(14, 15, 21)
		return
	end
	main_sub_range_widgets(get_player_att(Gear_info), 14, 15, 21, 'yellow', 'Att.', 'R.Att.')
end

-- block 22
local function update_evasion_widget()
	if settings.player.show_Evasion ~= true then
		remove_blocks(22)
		return
	end
	block(22, 'yellow', 'Eva.', '')
	set_value(22, tostring(get_player_evasion(Gear_info)))
end

-- block 23
local function update_defence_widget()
	if settings.player.show_Defence ~= true then
		remove_blocks(23)
		return
	end
	block(23, 'yellow', 'Def.', '')
	set_value(23, tostring(get_player_defence(Gear_info)))
end

-- blocks 24, 25
local function update_dw_widgets()
	local sub = player.equipment.sub
	if settings.player.show_DW_Stuff == true and sub.category == 'Weapon' and sub.damage then
		block(24, 'blue', 'DW')
		block(25, 'blue', 'Needed')
		set_value(24, Gear_info['Dual Wield'])
		local needed = DW_needed + manual_dw_needed
		set_value(25, needed, needed < 0)
	else
		remove_blocks(24, 25)
	end
end

-- blocks 26, 27
local function update_ma_widgets()
	if settings.player.show_MA_Stuff == true and is_hand_to_hand() then
		local total_ma, MA_needed = martial_arts_needed()
		block(26, 'pink', 'MA')
		block(27, 'pink', 'Needed')
		set_value(26, total_ma)
		set_value(27, MA_needed, MA_needed < 0)
	else
		remove_blocks(26, 27)
	end
end

-- block 28
local function update_stp_widget()
	if settings.player.show_STP ~= true then
		remove_blocks(28)
		return
	end
	block(28, 'orange', 'STP')
	set_value(28, Gear_info['Store TP'] + Buffs_inform['Store TP'])
end

-- block 30: movement speed, exactly as Windower's SpeedChecker addon shows it: the game's movement_speed for your
-- character, where 5.0 is normal walking speed (+0%). It includes everything: gear, Flee, Bolt's Role, Quickening,
-- slows, weight; on a mount it shows the mount's speed against walking.
function get_movement_speed_percent()
	local me = windower.ffxi.get_mob_by_target('me')
	if not me then return nil end
	local ms = me.movement_speed or me.speed
	if not ms then return nil end
	return math.floor(100 * (ms / 5 - 1) + 0.5)
end

-------------------------------------------------------------------------------------------------------------
-- (v1.7) extra stat cards 31-58 (list, labels and groups in Layouts.lua: extra_cards)
-- Gear totals include augments and set bonuses. Where InfoGear also tracks the stat from buffs (GEO bubbles,
-- rolls...), that is added. Job traits, job points and merits are NOT included, so these are your gear's numbers.
-- Each returns value, over_cap.
-------------------------------------------------------------------------------------------------------------
local function G(k) return (Gear_info and Gear_info[k]) or 0 end
local function B(k) return (Buffs_inform and Buffs_inform[k]) or 0 end

extra_card_values = {
	-- caps from BG-Wiki: Fast Cast 80%, Magic Burst Bonus (I) 40% from gear, Cure Potency 50%, Cure Potency II 30%,
	-- Subtle Blow 50% each and 75% together, Snapshot 70% from all sources
	fc      = function() local v = G('Fast Cast') + B('Fast Cast');                   return v, v > 80 end,
	macc    = function() return G('Magic Accuracy') + B('Magic Accuracy') end,
	mab     = function() return G('Magic Atk. Bonus') + B('Magic Atk. Bonus') end,
	mbb     = function() local v = G('Magic Burst Bonus');                            return v, v > 40 end,
	mbb2    = function() return G('Magic Burst Bonus II') end,
	cure    = function() local v = G('Cure Potency');                                 return v, v > 50 end,
	cure2   = function() local v = G('Cure Potency II');                              return v, v > 30 end,
	da      = function() return G('Double Attack') + B('Double Attack') end,
	ta      = function() return G('Triple Attack') + B('Tripple Attack') + B('Triple Attack') end,
	qa      = function() return G('Quadruple Attack') + B('Quadruple Attack') end,
	crit    = function() return G('Critical hit rate') + B('Critical hit rate') end,
	critdmg = function() return G('Critical hit damage') + B('Critical hit damage') end,
	sb      = function() local v = G('Subtle Blow') + B('Subtle Blow');               return v, v > 50 end,
	sb2     = function()
		local one, two = G('Subtle Blow') + B('Subtle Blow'), G('Subtle Blow II')
		return two, two > 50 or math.min(one, 50) + two > 75	-- II alone over 50, or both together over 75
	end,
	wsd     = function() return G('Weapon Skill Damage') end,
	pdl     = function() return G('Physical Damage Limit') end,
	snap    = function() local v = G('Snapshot');                                     return v, v > 70 end,
	rapid   = function() return G('Rapid Shot') end,
	meva    = function() return G('Magic Evasion') + B('Magic Evasion') end,
	mdb     = function() return G('Magic Def. Bonus') + B('Magic Def. Bonus') end,
	phalanx = function() return G('Phalanx') end,
	enmity  = function() return G('Enmity') end,
	hp      = function() return G('HP') + B('HP') end,
	mp      = function() return G('MP') + B('MP') end,
	regen   = function() return G('Regen') + B('Regen') end,	-- (v1.26) gear + buffs
	refresh = function() return G('Refresh') + B('Refresh') end,	-- (v1.26) gear + buffs
	regain  = function() return G('Regain') + B('Regain') end,	-- (v1.26) gear + buffs
	th      = function() return G('Treasure Hunter') end,
	-- (v1.27) Spell interruption rate down: 102% from all sources together (incl. 10% merits) stops all interruption
	sird    = function() local v = G('Spell Interruption Rate Down');             return v, v > 102 end,
	conserve = function() return G('Conserve MP') end,
	-- (v1.12) your pet's damage taken from your gear, all pet types together ("Pet:", "Wyvern:", "Avatar:",
	-- "Automaton:", "Luopan:"), shown as physical / magic. Pets cap like players: 50% per type from gear (BG-Wiki).
	-- (v1.16) On main DRG the wyvern's innate -40% damage taken is added on top of the (capped) gear part, up to the
	-- 87.5% overall cap (BG-Wiki, Wyvern (Dragoon Pet)). Red = the gear part is over 50, so some of it is wasted.
	-- (v1.17) Regen your gear gives your pet (HP per tick), all pet types together like Pet DT
	petregen = function() return G('Pet Regen') + B('Pet: Regen') end,	-- (v1.26) + Companion's Roll
	petdt   = function()
		local phys = 0 - (G('Pet DT') + G('Pet PDT'))	-- shown positive like the DT cards (0 - x, never "-0")
		local magic = 0 - (G('Pet DT') + G('Pet MDT'))
		local over = phys > 50 or magic > 50
		local innate = pet_innate_dt()
		if innate > 0 then
			phys = math.min(pet_dt_overall_cap, math.min(phys, 50) + innate)
			magic = math.min(pet_dt_overall_cap, math.min(magic, 50) + innate)
		end
		if phys == 0 then phys = 0 end
		if magic == 0 then magic = 0 end
		return string.format('%d/%d', math.floor(phys), math.floor(magic)), over	-- whole numbers to fit (87.5 -> 87)
	end,
}

-- (v1.16) the wyvern's own damage taken reduction, counted on main DRG; overall cap for pets (and players)
wyvern_innate_dt = 40
pet_dt_overall_cap = 87.5
function pet_innate_dt()
	local main = player and player.main_job and tostring(player.main_job):upper()
	if main == 'DRG' then return wyvern_innate_dt end
	return 0
end

-- (v1.13) jobs that can have a pet out: these main jobs, or /SMN or /BST (a /DRG can't call a wyvern, a /PUP can't
-- activate an automaton). Pet cards are hidden on any other job; //ig show pet stays on and they come back on a pet job.
pet_main_jobs = {BST = true, DRG = true, SMN = true, PUP = true, GEO = true}
pet_sub_jobs = {SMN = true, BST = true}

function is_pet_job()
	local main = player and player.main_job and tostring(player.main_job):upper()
	local sub = player and player.sub_job and tostring(player.sub_job):upper()
	return (main and pet_main_jobs[main]) or (sub and pet_sub_jobs[sub]) or false
end

local function update_extra_cards()
	local on = settings.player.cards or {}
	local pet_job = is_pet_job()
	for _, c in ipairs(extra_cards) do
		if on[c.key] == true and extra_card_values[c.key] and (c.group ~= 'pet' or pet_job) then
			local value, red = extra_card_values[c.key]()
			block(c.idx, 'grey', c.label)
			set_value(c.idx, value, red == true)
		else
			remove_blocks(c.idx)
		end
	end
end

local function update_speed_widget()
	if settings.player.show_speed ~= true then
		remove_blocks(30)
		return
	end
	local pct = get_movement_speed_percent()
	if not pct then return end
	block(30, 'green', 'Speed')
	set_value(30, string.format('%+d%%', pct), pct < 0)	-- red while slowed
end

-- block 29: shows whether automatic Gearswap updates are on
local function update_gearswap_widget()
	block(29, 'grey', 'UGS', '')
	set_value(29, tostring(settings.player.update_gs), settings.player.update_gs ~= true)
end

-------------------------------------------------------------------------------------------------------------
-- update(): called from the prerender event a few times per second
-------------------------------------------------------------------------------------------------------------
function update()
	if windower.ffxi.get_info().logged_in == false then
		return
	end
	
	-- 1. numbers that other code (and Gearswap) depend on, whatever is on screen
	local current_equip = check_equipped()
	Gear_info = build_combined_stats(get_equip_stats(current_equip))
	add_extra_sources(Gear_info)	-- (v1.27) food, Ionis / Sanction / Sigil (Extras.lua)
	job_presets_check()	-- (v1.27) main job changed: switch to that job's cards
	Total_haste = get_total_haste()
	DW_needed = dual_wield_needed()
	DW = (player.equipment.sub.category == 'Weapon' and player.equipment.sub.damage) and true or false
	
	-- 2. widgets
	update_haste_widgets()
	update_dt_widgets()
	update_tp_widgets()
	update_acc_widgets()
	update_att_widgets()
	update_evasion_widget()
	update_defence_widget()
	update_dw_widgets()
	update_ma_widgets()
	update_stp_widget()
	update_speed_widget()
	update_extra_cards()
	update_gearswap_widget()
	hover_refresh()	-- (v1.27) keep an open hover box up to date
	
	-- 3. tell Gearswap
	if settings.player.update_gs == true then
		local new_dw = DW_needed + manual_dw_needed
		local total_ma, MA_needed = martial_arts_needed()
		update_gs(DW, new_dw, Total_haste, is_hand_to_hand(), MA_needed)
		old_DW_needed = new_dw
	end
end
