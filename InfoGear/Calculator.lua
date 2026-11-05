function get_tp_per_hit()
	-- tp_per_hit = {melee = 0, range = 0}
	local tp_per_hit = determine_Base_tp_hit()
	local tp_per_hit_zanshin = 0
	local Job_STP = determine_stp()
	local Return_table = T{}
	local buff = Buffs_inform['Store TP']
	
	local jp_tp_bonus = gift_bonus('Store TP Effect')
	
	--log("base delay =" ..base_delay.. ' | tp_per_hit :' .. tp_per_hit .. ' | Job_traits :'.. Job_STP )
	if player.main_job == 'SAM' then
		
		--log('Main job is SAM Job points TP bonus value:' .. jp_tp_bonus)
		if Gear_info['Store TP'] ~= nil then
			local zanshin = tp_per_hit.melee + (3 * player.merits.ikishoten)
			--log('ikishoten merits = '.. player.merits.ikishoten .. ' STP merits: ' ..player.merits.store_tp_effect  )
			--log('zanshin = tp_per_hit + 3 x merits + jp bonus : ' .. zanshin)
			local merit_STP = (player.merits.store_tp_effect * 2)
			tp_per_hit_zanshin =  math.floor(zanshin * (100 + Gear_info['Store TP'] + Job_STP + merit_STP + jp_tp_bonus + buff) / 100 )
			--log('zanshin tp return = ' ..global_tp_hit_zanshin .. ' where gear STP = ' ..  Gear_info['Store TP'])
			tp_per_hit.melee = math.floor(tp_per_hit.melee * (100 + Gear_info['Store TP'] + merit_STP + jp_tp_bonus + Job_STP + buff) / 100 )
			tp_per_hit.range = math.floor(tp_per_hit.range * (100 + Gear_info['Store TP'] + merit_STP + jp_tp_bonus + Job_STP + buff) / 100 )
		end
	else
		if Gear_info['Store TP'] ~= nil then
			tp_per_hit.melee = math.floor(tp_per_hit.melee * (100 + Gear_info['Store TP'] + jp_tp_bonus + Job_STP + buff) / 100 )
			tp_per_hit.range = math.floor(tp_per_hit.range * (100 + Gear_info['Store TP'] + jp_tp_bonus + Job_STP + buff) / 100 )
			tp_per_hit_zanshin = 0
		end
	end
	Return_table = {tp_per_hit_melee = tp_per_hit.melee, tp_per_hit_zanshin = tp_per_hit_zanshin, tp_per_hit_range = tp_per_hit.range }
	return Return_table
end

function determine_Base_tp_hit()
	
	--Weapon_Delay = T{melee_delay = 0, sub = false, ranged_delay = 0, range = false, ammo = false}
	
	local total_dw = 0
	local weapons = determine_Weapon_Delay()
	local DW = determine_DW()
	
	if Gear_info['Dual Wield'] ~= nil and DW ~= nil then
		total_dw = Gear_info['Dual Wield'] + DW
	end
	
	local base_delay = {melee = 0, range = 0}
	if weapons.sub then
		base_delay.melee = math.floor((weapons.melee_delay * (1 - (total_dw/100 ))) / 2)
		base_delay.range = weapons.ranged_delay
	else
		base_delay.melee = weapons.melee_delay
		base_delay.range = weapons.ranged_delay
	end
	--print('base delay: ' .. base_delay ..' | weapon: ' ..determine_Weapon_Delay() .. ' | DW: ' .. total_dw )
	local tp_per_hit = {melee = 0, range = 0}
	
	for k,v in pairs(base_delay) do
		if base_delay[k] < 181 and base_delay[k] > 0 then
			tp_per_hit[k] = 61 + ((base_delay[k] -180) * 63 / 360)
		elseif base_delay[k] > 180 and base_delay[k] < 541 then
			tp_per_hit[k] = 61 + ((base_delay[k] -180) * 88 / 360)
		elseif base_delay[k] > 540 and base_delay[k] < 631 then
			tp_per_hit[k] = 149 + ((base_delay[k] - 540) * 20 / 360)
		elseif base_delay[k] > 630 and base_delay[k] < 721 then
			tp_per_hit[k] = 154 + ((base_delay[k] - 630) * 28 / 360)
		elseif base_delay[k] > 720 and base_delay[k] < 901 then
			tp_per_hit[k] = 161 + ((base_delay[k] - 720) * 24 / 360)
		elseif base_delay[k] > 900 then
			tp_per_hit[k] = 173 + ((base_delay[k] - 900) * 28 / 360)
		else	
			tp_per_hit[k] = 0
		end
		--log('tp_per_hit.'..k..': ' .. tp_per_hit[k])
		tp_per_hit[k] = math.floor(tp_per_hit[k])
	end
	
	return tp_per_hit
end

function determine_Weapon_Delay()
	local Weapon_Delay = T{melee_delay = 480, gear_MA = 0, sub = false, ranged_delay = 0, range = false, ammo = false}
	
	local Base_Delay = 480
	
	if player.equipment.main.skill == "Hand-to-Hand" or player.equipment.main.en == '' then
		
		-- base hand-to-hand delay of the main job and of the sub job (see Job_Traits.lua)
		local MainJ_Base_Delay, SubJ_Base_Delay = martial_arts_base_delays()
		
		MainJ_Base_Delay = MainJ_Base_Delay - gift_bonus('Martial Arts Effect')
		
		if SubJ_Base_Delay < MainJ_Base_Delay then
			Base_Delay = SubJ_Base_Delay
		else
			Base_Delay = MainJ_Base_Delay
		end
		Weapon_Delay.job_MA = 480 - Base_Delay
		for equip_slot,item in pairs(player.equipment) do
			-- Wrestler's Mantle	Latent Effect (Monk sub job): Hand-to-Hand Delay -10
			if item.id == 13660 and player.sub_job and player.sub_job == 'MNK' then Base_Delay = Base_Delay - 10 end
			-- check all other gear with martial arts
			local MA_item = Martial_Arts_Gear[item.id]
			if MA_item then
				Base_Delay = Base_Delay - MA_item.delay
				Weapon_Delay.gear_MA = Weapon_Delay.gear_MA + MA_item.delay
			end
		end
		if Base_Delay + (player.equipment.main.delay or 0) <= 96 then
			Weapon_Delay.melee_delay = 96
		else
			Weapon_Delay.melee_delay = Base_Delay + (player.equipment.main.delay or 0)
		end
	end
	for k,v in pairs(player.equipment.main) do
		if player.equipment.main.skill ~= "Hand-to-Hand" and player.equipment.main.en ~= '' then
			if k == 'delay' then
				Weapon_Delay.melee_delay = player.equipment.main.delay
			end
		end
	end
	for k,v in pairs(player.equipment.sub) do
		if player.equipment.sub.category == 'Weapon' then
			if k == 'damage' and v > 0 then
				Weapon_Delay.melee_delay = Weapon_Delay.melee_delay + (player.equipment.sub.delay or 0)
				Weapon_Delay.sub = true
			end	
		end
	end
	for k,v in pairs(player.equipment.range) do
		if k == 'damage' and v > 0 then
			Weapon_Delay.ranged_delay = Weapon_Delay.ranged_delay + (player.equipment.range.delay or 0)
			Weapon_Delay.range = true
		end		
	end
	for k,v in pairs(player.equipment.ammo) do
		if k == 'damage' and v > 0 then
			Weapon_Delay.ranged_delay = Weapon_Delay.ranged_delay + (player.equipment.ammo.delay or 0)
			Weapon_Delay.ammo = true
		end		
	end
	--table.vprint(Weapon_Delay)
	-- notice(Weapon_Delay.melee_delay )
	return Weapon_Delay
end

function get_total_haste()
	local gear_haste = 0
	local magic_haste = 0
	local ja_haste = 0
	local total = 0
	
	-- Gear_info['Haste'] already includes manual_ghaste (see get_equip_stats), so do not add it again here.
	-- g_haste is the Ionis-style gear haste; the Gear.H widget counts it, so the total must as well.
	gear_haste = math.min(Gear_info['Haste'] + (Buffs_inform['g_haste'] or 0), 256)
	if (Buffs_inform.ma_haste + manual_mhaste) > 448 then
		magic_haste = 448
	else
		magic_haste = Buffs_inform.ma_haste + manual_mhaste
	end
	if (Buffs_inform.ja_haste + manual_jahaste)> 256 then
		ja_haste = 256
	else
		ja_haste = Buffs_inform.ja_haste + manual_jahaste
	end
	total = gear_haste + magic_haste + ja_haste
	
	return total
end

function dual_wield_needed()
	local DW_needed = 0
	local Weapon_Delay = determine_Weapon_Delay()
	local total_delay = Weapon_Delay.melee_delay
	local total_haste = get_total_haste()
	
	if total_haste > 819 then total_haste = 819 end
		
	if (player.equipment.main.delay or 0) > 0 and Weapon_Delay.sub then	
		DW_needed = math.ceil(  (1- (0.2 / (  (1024 - total_haste)  / 1024) ) )* 100 - determine_DW() )
	end
	
	return DW_needed
end

function martial_arts_needed()
	local MA_needed = 0
	local WD = determine_Weapon_Delay()
	local Weapon_Delay = player.equipment.main.delay or 0
	local total_delay = WD.melee_delay
	local total_haste = get_total_haste()
	local job_MA = WD.job_MA or 0
	local total_gear_MA = WD.gear_MA or 0
	local total_MA = job_MA + total_gear_MA
	
	if total_haste > 819 then total_haste = 819 end
		
	if player.equipment.main.skill == "Hand-to-Hand" or player.equipment.main.en == '' then
		local Delay = 480 + Weapon_Delay
		MA_needed = math.ceil(Delay - ((Delay * 20) / ( (  (1024 - total_haste)  / 1024 * 100)      ))) - total_MA
	end
	
	return total_gear_MA, MA_needed
end

