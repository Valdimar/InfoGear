_addon.name = 'InfoGear'
_addon.author = 'Valdimar @ Phoenix'	-- based on GearInfo by Sebyg666
_addon.version = '1.28'

-- Raise this whenever the gear parser learns new stats: each character's saved gear is then read again once.
GEAR_PARSER_VERSION = 8	-- 8: v1.27 SIRD, Conserve MP; 3: v1.11 Unity table; 4: v1.12 pet damage taken; 5: v1.15 pet absorb fix; 6: v1.17 pet regen; 7: v1.18 cape augments
_addon.commands = {'ig','infogear'}


require('tables')
require('lists')
require('strings')
require('logger')
require('pack')

DW_Gear = require('res/DW_Gear')
Unity_rank = require('res/Unity_Gear')
Martial_Arts_Gear = require('res/Martial_Arts_Gear')
Set_bonus_by_Set_ID= require('res/Set_bonus_by_Set_ID')
Set_bonus_by_item_id = require('res/Set_bonus_by_item_id')
Blu_spells = require('res/Blue_Mage_Spells')
Gifts = require('res/Gifts')
Cor_Rolls = require('res/Cor_Rolls')
Bard_Songs = require('res/Bard_Songs')
Geo_Spells = require('res/Geo_Spells')
JSE_Neck_Ranks = require('res/JSE_Neck_Ranks')	-- (v1.10) rank bonuses Windower can't read
Limbus_Ranks = require('res/Limbus_Ranks')		-- (v1.11) Murky / Alabaster gear, exact per rank
Limbus_Armor_Ranks = require('res/Limbus_Armor_Ranks')	-- (v1.20) Limbus racial armor and weapons
Ranked_Gear = {}
for id, entry in pairs(JSE_Neck_Ranks) do Ranked_Gear[id] = entry end
for id, entry in pairs(Limbus_Ranks) do Ranked_Gear[id] = entry end
for id, entry in pairs(Limbus_Armor_Ranks) do Ranked_Gear[id] = entry end

res = require('resources')
skills_from_resources = res.skills
Extdata = require("extdata")
config = require('config')
files = require('files')
blu_spells = res.spells:type('BlueMagic')
timer = require('timeit')
packets = require('packets')
bit = require('bit')
chat = require('chat')
chars = require('chat.chars')

require 'Statics'
require 'Gear_Processing'
require 'Job_Traits'
require 'Display'
require 'Calculator'
require 'Action_Processing'
require 'Buff_Processing'
require 'Packet_parsing'
require 'Layouts'
require 'Image_processing'
require 'Extras'	-- (v1.27) per-job cards, food, Ionis / Sanction / Sigil, hover breakdown, snapshots

-- Chat lines when the addon loads. The profile line needs a character, so it is printed from options_load() once
-- that character's settings file (data/<name>_settings.xml) is loaded; logging in reloads the addon, so every
-- character gets its own line.
local function say(text) windower.add_to_chat(207, '[' .. _addon.name .. '] ' .. text) end

function load_echo(character_name)
	if character_name then
		say('Loaded profile layout for ' .. character_name .. '.')
	end
	say('Author: ' .. _addon.author .. ' ' .. _addon.version .. ', based on GearInfo by Sebyg666')
end

windower.register_event('load', function()
	if not windower.ffxi.get_player() then load_echo() end	-- at the login screen: no profile yet
	if windower.ffxi.get_player() then
		options_load()
		--text_box:show()
		
		if files.exists('data\\'..player.name..'_temp_party.lua') then
			local f = io.open(windower.addon_path..'data/'..player.name..'_temp_party.lua','r')
			local t = f:read("*all")
			t = assert(loadstring(t))()
			f:close()
			member_table = t
			local f = io.open(windower.addon_path..'data/'..player.name..'_temp_party.lua','w')
			f:write('return {}')
			f:close()
		end
		if files.exists('data\\'..player.name..'_temp_buffs.lua') then
			local f = io.open(windower.addon_path..'data/'..player.name..'_temp_buffs.lua','r')
			local t = f:read("*all")
			t = assert(loadstring(t))()
			f:close()
			_ExtraData.player.buff_details = t
			local f = io.open(windower.addon_path..'data/'..player.name..'_temp_buffs.lua','w')
			f:write('return {}')
			f:close()
		end
		
	end
end)

windower.register_event('logout', function()
	
	player = {}
	player.equipment = T{}
	buff = 0
	full_gear_table_from_file = T{}
	
	manual_stp = 0
	manual_dw = 0
	manual_ghaste = 0
	WSTP = 0
	
end)

windower.register_event('login',function ()
	windower.send_command('lua r infogear;')
end)

function options_load()
	
	if windower.ffxi.get_player() then
	
		
		settings = config.load('data\\'..windower.ffxi.get_player().name..'_settings.xml',defaults)
		settings:save('all')
		load_echo(windower.ffxi.get_player().name)
		sections.background = ImageBlock.New(0,'background','')
		player = windower.ffxi.get_player()
		update_party()
		local this_file = files.new('data\\'..player.name..'_data.lua',true)
		
		if not files.exists('data\\'..player.name..'_data.lua') then
			this_file:create()
			local f = io.open(windower.addon_path..'data/'..player.name..'_data.lua','w')
			f:write('return {\n}')
			f:close()
			print(player.name..'_data.lua created by InfoGear')
			parse_inventory()
			settings.parser_version = GEAR_PARSER_VERSION
			settings:save('all')
		else
			full_gear_table_from_file = get_equipment_from_file()
			-- the saved gear was read by an older version that didn't know every stat: read it again, once
			if (tonumber(settings.parser_version) or 0) < GEAR_PARSER_VERSION then
				windower.add_to_chat(207, '[' .. _addon.name .. '] Updating your saved gear for the new stats (one time)...')
				parse_inventory()
				settings.parser_version = GEAR_PARSER_VERSION
				settings:save('all')
			end
		end
		
		-- (v1.26) Regen / Refresh / Regain cards: turned on once for characters that had them off from older versions
		if not settings.player.recovery_cards_on and settings.player.cards then
			for _, k in ipairs({'regen', 'refresh', 'regain'}) do settings.player.cards[k] = true end
			settings.player.recovery_cards_on = true
			settings:save('all')
		end

		manual_stp = 0
		manual_dw = 0
		manual_ghaste = 0
		initialize_packet_parsing()
	end
	
end

local function infogear_command(command, ...)
	local args = {...}
    command = command and command:lower()
    if command then
        if command:lower() == 'parse' then
			log('Parsing all inventories to file')
			parse_inventory()
		elseif command:lower() == 'rank' then
			--table.vprint(args)
			if type(tonumber(args[1])) == 'number'  then
				settings.player.rank = tonumber(args[1])
				log('Changed \'Unity Rank\' to '..tonumber(args[1])..'. Don\'t forget to \"//ig parse\" to apply new values to your gear.')
				settings:save('all')
			else
				log('Your current \'Unity Rank\' setting is: '..settings.player.rank..'.')
			end
			settings:save('all')
		elseif command:lower() == 'stp' and type(tonumber(args[1])) == 'number' then
			manual_stp = tonumber(args[1])
			log('Set maunal Store TP to ' .. tostring(manual_stp))
		elseif command:lower() == 'dw' and type(tonumber(args[1])) == 'number' then
			manual_dw = tonumber(args[1])
			log('Set maunal Dual Wield to ' .. tostring(manual_dw))
		elseif command:lower() == 'ghaste' and type(tonumber(args[1])) == 'number' then
			manual_ghaste = tonumber(args[1])
			log('Set maunal Gear Haste to ' .. tostring(manual_ghaste))
		elseif command:lower() == 'mhaste' and type(tonumber(args[1])) == 'number' then
			manual_mhaste = tonumber(args[1])
			log('Set maunal Magic Haste to ' .. tostring(manual_mhaste))
		elseif command:lower() == 'jahaste' and type(tonumber(args[1])) == 'number' then
			manual_jahaste = tonumber(args[1])
			log('Set maunal Job Ability Haste to ' .. tostring(manual_jahaste))
		elseif command:lower() == 'dwn' and type(tonumber(args[1])) == 'number' then	
			manual_dw_needed = tonumber(args[1])
			log('Set maunal DW needed to ' .. tostring(manual_dw_needed))
		elseif command:lower() == 'r' or command:lower() == 'reload' then
			
			local new_item = member_table
			local f = io.open(windower.addon_path..'data/'..player.name..'_temp_party.lua','w')
			f:write('return ' .. T(new_item):tovstring())
			f:close()
			
			local new_item = _ExtraData.player.buff_details
			local f = io.open(windower.addon_path..'data/'..player.name..'_temp_buffs.lua','w')
			f:write('return ' .. T(new_item):tovstring())
			f:close()
			notice('Buffs and party saved to temp file. Reloading IG.')

			windower.send_command('lua r infogear;')
		elseif command:lower() == 'save' or command:lower() == 's' then
			if args[1]:lower() == 'wstp' then
				WSTP = get_tp_per_hit(player.equipment).tp_per_hit_melee
			else
				log('Misstype: use //ig save wstp')
			end
		elseif command:lower() == 'delete' or command:lower() == 'd' then
			if args[1]:lower() == 'wstp' then
				WSTP = 0
			else
				log('Misstype: use //ig delete wstp')
			end	
		elseif command:lower() == 'hide' then
			settings.player.show_total_haste = false
			settings.player.show_tp_Stuff = false
			settings.player.show_acc_Stuff = false
			settings.player.show_dt_Stuff = false
			settings.player.show_att_Stuff = false
			settings.player.show_Evasion = false
			settings.player.show_Defence = false
			settings.player.show_STP = false
			settings.player.show_speed = false
			settings.player.show_DW_Stuff = false
			settings.player.show_MA_Stuff = false
			for _, c in ipairs(extra_cards) do settings.player.cards[c.key] = false end
			log('All display settings set to false to hide display.')
			settings:save('all')
		elseif command:lower() == 'update' then
			update_gs(DW, (DW_needed + manual_dw_needed), get_total_haste(), nil, nil, true)
		elseif command:lower() == 'updategs' or command:lower() == 'ugs' then
			if args[1] == nil then
				if settings.player.update_gs == false then
					settings.player.update_gs = true
				elseif settings.player.update_gs then
					settings.player.update_gs = false
				end
			elseif args[1]:lower() == 'true' then
				settings.player.update_gs = true
			elseif args[1]:lower() == 'false' then
				settings.player.update_gs = false
			end
			log('Auto update Gearswap = '..tostring(settings.player.update_gs))
			settings:save('all')
		elseif command:lower() == 'brd' then
			if type(tonumber(args[1])) == 'number' then
				manual_bard_duration_bonus = tonumber(args[1])
				log('Set Brd song+ bonus to ' .. tostring(manual_bard_duration_bonus) .. '.')
			elseif args[1]:lower() == 'add' and type(tostring(args[2])) == 'string' and type(tonumber(args[3])) == 'number' then
				settings.Bards[args[2]:lower()] = default_bard_settings
				settings.Bards[args[2]:lower()]['song_bonus']['all_songs'] = tonumber(args[3])
				settings:save('all')
				log('Added ' .. tostring(args[2]:lower()) .. ' as a known bard with +'.. tonumber(args[3]) .. ' to all songs.')
				notice('For advanced users: You may go into the settings file for your character and edit the bards in a more detailed manner.')
			elseif args[1]:lower() == 'delete' and type(tostring(args[2])) == 'string' then
				settings.Bards[tostring(args[2]):lower()] = nil
				settings:save('all')
				log('Removed ' .. tostring(args[2]:lower()) .. ' as a known bard!')
			end
		elseif command:lower() == 'cor' then
			if type(tonumber(args[1])) == 'number' then
				manual_COR_bonus = tonumber(args[1])
				log('Set Phantom Roll bonus to ' .. tostring(manual_COR_bonus) .. '.')
			elseif args[1]:lower() == 'add' and type(tostring(args[2])) == 'string' and type(tonumber(args[3])) == 'number' then
				settings.Cors[args[2]:lower()] = tonumber(args[3])
				settings:save('all')
				log('Added ' .. tostring(args[2]:lower()) .. ' as a known COR with +' .. tonumber(args[3]) .. ' Phantom Roll !')
			elseif args[1]:lower() == 'delete' and type(tostring(args[2])) == 'string' then
				settings.Cors[tostring(args[2]):lower()] = nil
				settings:save('all')
				log('Removed ' .. tostring(args[2]:lower()) .. ' as a known COR!')
			end
		elseif command:lower() == 'geo' then
			if type(tonumber(args[1])) == 'number' then
				manual_GEO_bonus = tonumber(args[1])
				log('Set Geomancy bonus to ' .. tostring(manual_GEO_bonus) .. '.')
			elseif args[1]:lower() == 'add' and type(tostring(args[2])) == 'string' and type(tonumber(args[3])) == 'number' then
				settings.Geos[args[2]:lower()] = args[3]
				settings:save('all')
				log('Added ' .. tostring(args[2]:lower()) .. ' as a known GEO with +' .. tonumber(args[3]) .. ' Geomancy!')
			elseif args[1]:lower() == 'delete' and type(tostring(args[2])) == 'string' then
				settings.Geos[tostring(args[2]):lower()] = nil
				settings:save('all')
				log('Removed ' .. tostring(args[2]:lower()) .. ' as a known GEO!')
			end
		elseif command:lower() == 'dnc' then
			if dancer_main then
				dancer_main = false
			else
				dancer_main = true
			end
			log('toggled DNC buff from main job to -> ' .. tostring(dancer_main) .. '.')
		elseif command:lower() == 'show' then
			
			if not args[1] then
				windower.send_command('ig cards')
				return
			end
			if extra_card_toggle(args[1]:lower()) then
				-- (v1.7) handled: an extra card or a group of them
			elseif args[1]:lower() == 'haste' then
				if settings.player.show_total_haste == false then
					settings.player.show_total_haste = true
				elseif settings.player.show_total_haste then
					settings.player.show_total_haste = false
				end
				log('Show Haste = '..tostring(settings.player.show_total_haste))
			elseif args[1]:lower() == 'eva' then
				if settings.player.show_Evasion == false then
					settings.player.show_Evasion = true
				elseif settings.player.show_Evasion then
					settings.player.show_Evasion = false
				end
				log('Show Evasion calculations = '..tostring(settings.player.show_Evasion))	
			elseif args[1]:lower() == 'def' then
				if settings.player.show_Defence == false then
					settings.player.show_Defence = true
				elseif settings.player.show_Defence then
					settings.player.show_Defence = false
				end
				log('Show Defence calculations = '..tostring(settings.player.show_Defence))		
			elseif args[1]:lower() == 'att' then
				if settings.player.show_att_Stuff == false then
					settings.player.show_att_Stuff = true
				elseif settings.player.show_att_Stuff then
					settings.player.show_att_Stuff = false
				end
				log('Show Attack calculations = '..tostring(settings.player.show_att_Stuff))	
			elseif args[1]:lower() == 'tp' then
				if settings.player.show_tp_Stuff == false then
					settings.player.show_tp_Stuff = true
				elseif settings.player.show_tp_Stuff then
					settings.player.show_tp_Stuff = false
				end
				log('Show Tp calculations = '..tostring(settings.player.show_tp_Stuff))
			elseif args[1]:lower() == 'stp' then
				if settings.player.show_STP== false then
					settings.player.show_STP = true
				elseif settings.player.show_STP then
					settings.player.show_STP = false
				end
				log('Show Store TP = '..tostring(settings.player.show_STP))
			elseif args[1]:lower() == 'speed' then
				settings.player.show_speed = not (settings.player.show_speed == true)
				log('Show movement speed = '..tostring(settings.player.show_speed))
			elseif args[1]:lower() == 'dw' then
				if settings.player.show_DW_Stuff == false then
					settings.player.show_DW_Stuff = true
				elseif settings.player.show_DW_Stuff then
					settings.player.show_DW_Stuff = false
				end
				log('Show Duel Wield calculations = '..tostring(settings.player.show_DW_Stuff))
			elseif args[1]:lower() == 'ma' then
				if settings.player.show_MA_Stuff == false then
					settings.player.show_MA_Stuff = true
				elseif settings.player.show_MA_Stuff then
					settings.player.show_MA_Stuff = false
				end
				log('Show Martial Arts calculations = '..tostring(settings.player.show_MA_Stuff))
			elseif args[1]:lower() == 'acc' then
				if settings.player.show_acc_Stuff == false then
					settings.player.show_acc_Stuff = true
				elseif settings.player.show_acc_Stuff then
					settings.player.show_acc_Stuff = false
				end
				-- log('Currently dissabled, in testing.')
				log('Show Total Acc = '..tostring(settings.player.show_acc_Stuff))
			elseif args[1]:lower() == 'dt' then
				if settings.player.show_dt_Stuff == false then
					settings.player.show_dt_Stuff = true
				elseif settings.player.show_dt_Stuff then
					settings.player.show_dt_Stuff = false
				end
				-- log('Currently dissabled, in testing.')
				log('Show Defence = '..tostring(settings.player.show_dt_Stuff))
			elseif args[1]:lower() == 'cor' then
				if settings.player.show_COR_messages == false then
					settings.player.show_COR_messages = true
				elseif settings.player.show_COR_messages then
					settings.player.show_COR_messages = false
				end
				log('Cor Chat log messages set to '..tostring(settings.player.show_COR_messages))
			elseif args[1]:lower() == 'all' then
				settings.player.show_total_haste = true
				settings.player.show_tp_Stuff = true
				settings.player.show_acc_Stuff = true
				settings.player.show_dt_Stuff = true
				settings.player.show_att_Stuff = true
				settings.player.show_Evasion = true
				settings.player.show_Defence = true
				settings.player.show_STP = true
				settings.player.show_speed = true
				settings.player.show_DW_Stuff = true
				settings.player.show_MA_Stuff = true
				for _, c in ipairs(extra_cards) do settings.player.cards[c.key] = true end
				log('All display settings set to true to shall all the display.')
			end
			settings:save('all')
		elseif command:lower() == 'test' then
			table.vprint(player['merits']['aggressive_aim'])
			-- for skill_name, value in pairs(player_base_skills) do
				-- if skill_name:contains('eva') then
					-- print(skill_name, value)
				-- end
			-- end
			-- if player_base_skills['evasion'] then print(player_base_skills['evasion']) end
			-- local current_equip = check_equipped()
			-- local Gear_info = get_equip_stats(current_equip)
			-- print(Gear_info['Evasion skill'])
			--check_equipped()
			--settings.Cors['ewellina'] = nil
			-- table.vprint(_ExtraData.player.buff_details)
			--table.vprint(windower.ffxi.get_mob_by_target('t'))
			--table.vprint(member_table)
			--table.vprint(player_base_skills)
			-- local stat_table = get_equip_stats(check_equipped())
			-- local player_Acc = get_player_acc(stat_table)
			-- table.vprint(stat_table.range)
			-- log(player_Acc.agi.. '  '..stat_table["Throwing skill"] .. '  '..stat_table['Ranged Accuracy'])
			-- table.vprint( player_Acc )
			-- log(player_base_skills['hand_to_hand'])
			-- player_base_skills = player.skills
			-- get_player_skill_in_gear(check_equipped())
			--player.stats = get_packet_data_base_stats()
			-- get_packet_data()
			-- Total_acc = get_player_acc(check_equipped())
			-- log(player.stats.DEX .. ' '.. Total_acc.dex .. ' '.. Total_acc.main.. ' '.. Total_acc.sub)
			-- log(player.stats.AGI .. ' '.. Total_acc.agi .. ' '.. Total_acc.range.. ' '.. Total_acc.ammo)
		elseif extras_command(command, args) then
			-- (v1.27) food, sanction, sigil, hover, snap, diff, snaps, jobcards (Extras.lua)
		elseif command == 'cards' then
			extra_cards_list()
		elseif command == 'why' then
			why_command(args)
		elseif command == 'size' then
			size_command(args)
		elseif command == 'columns' or command == 'cols' then
			columns_command(args)
		elseif command == 'scale' then
			scale_command(args)
		elseif command:lower() == 'debug' then
			if debug_mode == false then
				debug_mode = true
			else
				debug_mode = false
			end
			log('Toggled Debug Mode to '..tostring(debug_mode))
		elseif command:lower() == 'help' then
			
			local chat_purple = string.char(0x1F, 200)
			local chat_grey = string.char(0x1F, 160)
			local chat_red = string.char(0x1F, 167)
			local chat_white = string.char(0x1F, 001)
			local chat_green = string.char(0x1F, 214)
			local chat_yellow = string.char(0x1F, 036)
			local chat_d_blue = string.char(0x1F, 207)
			local chat_pink = string.char(0x1E, 5)
			local chat_l_blue = string.char(0x1E, 6)
			
			windower.add_to_chat(6, ' ')
			windower.add_to_chat(6, chat_white.. 	'                         --------------------------' )
			windower.add_to_chat(6, chat_d_blue.. 	'                         Welcome to InfoGear help!' )
			windower.add_to_chat(6, chat_white.. 	'                         --------------------------' )
			windower.add_to_chat(6, ' ')
			windower.add_to_chat(6, chat_d_blue.. 	'Commands available:' )
			windower.add_to_chat(6, ' ')
			windower.add_to_chat(6, chat_l_blue.. 	'\'\/\/ig parse\'' .. chat_white .. '  --  Will reload your inventory to file (eg. after changing unity rank).')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig rank\'' .. chat_white .. '   --  Shows current unity rank setting.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig rank #\'' .. chat_white .. '  --  Change # to your unity rank, anything under 5 is set to 5.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig stp #\'' .. chat_white .. '  --  Change # to + or - \'Store TP\' manually. eg. ' .. chat_yellow .. ' \/\/gs stp +10'.. chat_white ..' or ' .. chat_yellow  .. '\/\/gs stp 10')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig dw #\'' .. chat_white .. '  --  Change # to + or - \'Dual Wield\' manually. eg. ' .. chat_yellow .. ' \/\/gs dw +10'.. chat_white ..' or ' .. chat_yellow  .. '\/\/gs dw 10')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig ghaste #\'' .. chat_white .. '  --  Change # to + or - \'Haste\' manually. eg. ' .. chat_yellow .. ' \/\/gs ghaste +10'.. chat_white ..' or ' .. chat_yellow  .. '\/\/gs ghaste 10')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig mhaste #\'' .. chat_white .. '  --  Change # to + or - \'Haste\' manually. eg. ' .. chat_yellow .. ' \/\/gs mhaste +10'.. chat_white ..' or ' .. chat_yellow  .. '\/\/gs mhaste 10')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig jahaste #\'' .. chat_white .. '  --  Change # to + or - \'Haste\' manually. eg. ' .. chat_yellow .. ' \/\/gs jahaste +10'.. chat_white ..' or ' .. chat_yellow  .. '\/\/gs jahaste 10')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig dwn #\'' .. chat_white .. '  --  Change # to + or - \'DW needed\'. eg. ' .. chat_yellow .. ' \/\/gs dwn +10'.. chat_white ..' or ' .. chat_yellow  .. '\/\/gs dwn 10')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig save/s wstp\'' .. chat_white .. '  --  saves current tp/hit into new line.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig delete/d wstp\'' .. chat_white .. '  --  deletes previously created line.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig brd #\'' .. chat_white .. '  --  Change # to equal your parties BRD max March Bonus.')
			windower.add_to_chat(6, chat_l_blue..	'          add \'name\' \'bonus\'' .. chat_white .. '  --  Save the bard with name and Bonus for future use.')
			windower.add_to_chat(6, chat_yellow..	'eg. \/\/ig brd add bob 7' .. chat_white .. '  --  This will add bob to the list with +7 March Bonus.')
			windower.add_to_chat(6, chat_l_blue..	'          delete \'name\'' .. chat_white .. '  --  Delete a bard from the list.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig cor #\'' .. chat_white .. '  --  Change # to equal your parties COR "Phantom Roll +#" bonus.')
			windower.add_to_chat(6, chat_l_blue..	'          add \'name\' \'bonus\'' .. chat_white .. '  --  Save the COR with name and Bonus for future use.')
			windower.add_to_chat(6, chat_yellow..	'eg. \/\/ig cor add bob 3' .. chat_white .. '  --  This will add bob to the list with Phantom Roll +3. eg "Merirosvo Ring"')
			windower.add_to_chat(6, chat_l_blue..	'          delete \'name\'' .. chat_white .. '  --  Delete a COR from the list.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig geo #\'' .. chat_white .. '  --  Change # to equal your parties GEO "Geomancy +#" bonus.')
			windower.add_to_chat(6, chat_l_blue..	'          add \'name\' \'bonus\'' .. chat_white .. '  --  Save the GEO with name and Bonus for future use.')
			windower.add_to_chat(6, chat_yellow..	'eg. \/\/ig geo add bob 5' .. chat_white .. '  --  This will add bob to the list with Geomancy +5. eg "Duna"')
			windower.add_to_chat(6, chat_l_blue..	'          delete \'name\'' .. chat_white .. '  --  Delete a GEO from the list.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig dnc\'' .. chat_white .. '  --  Toggle if your party is getting Haste Samba from a main DNC or not.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig hide\'' .. chat_white .. '  --  Hide all display (not a toggle).')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig show\'' .. chat_white .. '  --  add subcommand.')
			windower.add_to_chat(6, chat_l_blue..	'              \'haste\'' .. chat_white .. '  --  Toggle hide Total haste.')
			windower.add_to_chat(6, chat_l_blue..	'              \'tp\'' .. chat_white .. '  --  Toggle hide TP Calculator.')
			windower.add_to_chat(6, chat_l_blue..	'              \'acc\'' .. chat_white .. '  --  Toggle hide Accuracy Calculations.')
			windower.add_to_chat(6, chat_l_blue..	'              \'eva\'' .. chat_white .. '  --  Toggle hide Evasion Calculations.')
			windower.add_to_chat(6, chat_l_blue..	'              \'def\'' .. chat_white .. '  --  Toggle hide Defence Calculations.')
			windower.add_to_chat(6, chat_l_blue..	'              \'att\'' .. chat_white .. '  --  Toggle hide Attack Calculations.')
			windower.add_to_chat(6, chat_l_blue..	'              \'stp\'' .. chat_white .. '  --  Toggle hide Store TP.')
			windower.add_to_chat(6, chat_l_blue..	'              \'speed\'' .. chat_white .. '  --  Toggle hide movement speed (+/- %).')
			windower.add_to_chat(6, chat_l_blue..	'              \'melee\' \'ranged\' \'magic\' \'tank\' \'recovery\' \'misc\' \'pet\'' .. chat_white .. '  --  Toggle a group of extra stat cards.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig cards\'' .. chat_white .. '  --  List the extra stat cards (Fast Cast, DA, Snapshot...) and which are shown.')
			windower.add_to_chat(6, chat_l_blue..	'              \'dw\'' .. chat_white .. '  --  Toggle hide DW Calculations.')
			windower.add_to_chat(6, chat_l_blue..	'              \'ma\'' .. chat_white .. '  --  Toggle hide MA Calculations.')
			windower.add_to_chat(6, chat_l_blue..	'              \'dt\'' .. chat_white .. '  --  Toggle hide DT Calculations.')
			windower.add_to_chat(6, chat_l_blue..	'              \'all\'' .. chat_white .. '  --  Toggle all display options on.')
			windower.add_to_chat(6, chat_l_blue..	'              \'cor\'' .. chat_white .. '  --  Toggle rollTracker chat display.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig why pet|dt\'' .. chat_white .. '  --  List what each equipped item gives to Pet DT / your DT.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig hover\'' .. chat_white .. '  --  Toggle the breakdown box shown when the mouse is over a card.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig jobcards\'' .. chat_white .. '  --  Toggle a separate set of shown cards for each main job (on by default).')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig snap name\'' .. chat_white .. ' / ' .. chat_l_blue .. '\'diff name\'' .. chat_white .. ' / ' .. chat_l_blue .. '\'snaps\'' .. chat_white .. '  --  Save every card value as name / compare now with it / list.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig food [name|off]\'' .. chat_white .. '  --  Show the food InfoGear counts, or set / clear it by hand.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig sanction|sigil regen|refresh|food\'' .. chat_white .. '  --  Which bonus you picked for Sanction / Sigil.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig size normal|small\'' .. chat_white .. '  --  Card size: small = smaller cards and text, same columns.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig columns #\'' .. chat_white .. '  --  Cards per row: 4, 5 or 6 (4 = default). eg. ' .. chat_yellow .. '\/\/ig columns 6')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig scale #\'' .. chat_white .. '  --  Size of the whole display, 0.5 - 2 (1 = original). eg. ' .. chat_yellow .. '\/\/ig scale 0.8')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig help\'' .. chat_white .. '  --  This command or any mistakes will show this menu.')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig updategs'.. chat_white ..' or ' .. chat_l_blue .. 'ugs\'' .. chat_white .. '  --  toggle Send info to GearSwap for use, Can add true / false')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig update\'' .. chat_white .. '  --  forces 1 update to gearswap')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig debug\'' .. chat_white .. '  --  toggle debug mode')
			windower.add_to_chat(6, chat_l_blue..	'\'\/\/ig r'.. chat_white ..' or ' .. chat_l_blue .. 'reload\'' .. chat_white .. '  --  Reload addon InfoGear.')
			windower.add_to_chat(6, ' ')

		-- elseif command:lower() == 'test' then	
			-- check_none_existant_ids()
		else
			windower.send_command('ig help')
		end
	else
		windower.send_command('ig help')
	end
end

-- (v1.27) after every command, the card toggles are remembered for the current main job (Extras.lua)
windower.register_event('addon command', function(...)
	infogear_command(...)
	if settings and player and player.main_job then job_presets_store() end
end)

function save_table_to_file(item_table)

	local new_item = item_table
	
	local f = io.open(windower.addon_path..'data/'..player.name..'_data.lua','w')
	f:write('return ' .. T(new_item):tovstring())
    f:close()
	notice('File Saved')
end

function get_equipment_from_file()

	local f = io.open(windower.addon_path..'data/'..player.name..'_data.lua','r')
	local t = f:read("*all")
	t = assert(loadstring(t))()
	f:close()
	
	return t
end

function parse_inventory()
	
	local items_in_bag = T{}
	local full_gear_table_rw = T{}
	for k,v in pairs(res.bags) do
		for i,n in pairs(windower.ffxi.get_items(v.id)) do
			items_in_bag[#items_in_bag +1] = n
		end
	end
	for k,v in pairs(items_in_bag) do
		if v ~= nil and type(v) == 'table' then
			if v.id ~= 0 then
				local this_item = find_all_values(v)
				if this_item ~= nil then
					full_gear_table_rw[#full_gear_table_rw +1] = this_item
				end
			end
		end	
	end
	
	full_gear_table_from_file = full_gear_table_rw
	save_table_to_file(full_gear_table_from_file)
end

function parse_new_single_item(item)

	if item ~= nil and type(item) == 'table' then
		if item.id ~= 0 then
			local this_item = find_all_values(item)
			if this_item ~= nil then
				full_gear_table_from_file[#full_gear_table_from_file +1] = this_item
			end
			
			save_table_to_file(full_gear_table_from_file)
			
			return this_item
		end
	end
end

-- (v1.10, v1.11) A copy of a saved item with its rank bonuses added (the saved gear itself is not changed).
-- `ext` is the item's decoded extdata. Its rank is used; an item that shows a rank path ("Path: A") but no readable
-- rank is taken as max rank, and an item that was never augmented as rank 0.
-- Entries with `ranks` (Limbus gear) give the exact bonus per rank; entries with `stats` (JSE necks) give the
-- max-rank bonus, scaled by rank / max rank below that.
function ranked_item_rank(ext, max_rank)
	local rank = tonumber(ext and ext.rank)
	if not rank then
		local has_path = false
		for _, a in pairs((ext and ext.augments) or {}) do
			if type(a) == 'string' and a:find('Path:', 1, true) then has_path = true end
		end
		rank = has_path and max_rank or 0
	end
	if rank > max_rank then rank = max_rank end
	if rank < 0 then rank = 0 end
	return rank
end

function with_rank_bonus(item, ranked, ext)
	local rank = ranked_item_rank(ext, ranked.max_rank)
	local copy = {}
	for key, value in pairs(item) do copy[key] = value end
	if ranked.ranks then
		for stat, value in pairs(ranked.ranks[rank] or {}) do
			copy[stat] = (tonumber(copy[stat]) or 0) + value
		end
	else
		for stat, max_value in pairs(ranked.stats) do
			local value = max_value * rank / ranked.max_rank
			value = value < 0 and math.ceil(value) or math.floor(value)	-- toward 0, so -7 at R24 is -6
			copy[stat] = (tonumber(copy[stat]) or 0) + value
		end
	end
	copy.item_rank = rank
	return copy
end

-- (v1.15) //ig why pet | dt: which equipped items give the numbers on the Pet DT / DT cards
function why_command(args)
	local what = args[1] and tostring(args[1]):lower() or ''
	local keys
	if what == 'pet' then keys = {'Pet DT', 'Pet PDT', 'Pet MDT', 'Pet Regen'}
	elseif what == 'dt' then keys = {'DT', 'PDT', 'MDT', 'BDT'}
	else
		log('Use //ig why pet (your pet\'s damage taken and Regen) or //ig why dt (yours): it lists what each item gives.')
		return
	end
	local slots = {'main','sub','range','ammo','head','neck','left_ear','right_ear','body','hands','left_ring','right_ring','back','waist','legs','feet'}
	local totals, any = {}, false
	log('What your gear gives (' .. table.concat(keys, ' / ') .. '):')
	for _, slot in ipairs(slots) do
		local item = player.equipment and player.equipment[slot]
		if type(item) == 'table' and item.en and item.en ~= '' then
			local parts = {}
			for _, k in ipairs(keys) do
				local v = tonumber(item[k])
				if v and v ~= 0 then parts[#parts + 1] = k .. ' ' .. v; totals[k] = (totals[k] or 0) + v end
			end
			if #parts > 0 then
				any = true
				local rank = item.item_rank and (' (rank ' .. item.item_rank .. ')') or ''
				log(string.format('  %-10s %s%s: %s', slot, item.en, rank, table.concat(parts, ', ')))
			end
		end
	end
	if not any then log('  nothing equipped gives these.') end
	if what == 'pet' and pet_innate_dt and pet_innate_dt() > 0 then
		log('  wyvern (innate): Damage taken -' .. pet_innate_dt() .. ', on top of the gear part (gear capped at 50 per type, all together at ' .. pet_dt_overall_cap .. ')')
	end
	local t = {}
	for _, k in ipairs(keys) do t[#t + 1] = k .. ' ' .. (totals[k] or 0) end
	log('  total from gear: ' .. table.concat(t, ', ') .. '  (set bonuses not listed per item)')
end

function check_equipped()

	local new_gear_table = T{}
	local local_gear_table = T{}
	local items_equipped = windower.ffxi.get_items().equipment
	
	local default_slot = T{'sub','range','ammo','head','body','hands','legs','feet','neck','waist', 'left_ear', 'right_ear', 'left_ring', 'right_ring','back'}
	default_slot[0]= 'main'	
	
	if items_equipped then
		for id,name in pairs(default_slot) do
			items_equipped[name] = {
                    slot = items_equipped[name],
                    bag = items_equipped[name..'_bag']
                    }
                    items_equipped[name..'_bag'] = nil
			
		end
	end
	
	for k,v in pairs(items_equipped) do
		if v.slot == 0 then
			new_gear_table[k] = {count = 0 ,status = 0,id = 0,slot = 0,bazaar = 0,extdata = ''}
		else
			new_gear_table[k] = windower.ffxi.get_items(v.bag, v.slot)
		end
	end

	local sloted_items = new_gear_table
	for k,v in pairs(new_gear_table) do
		if v.count > 0 then
			local item_has_augment = Extdata.decode(v)
			local no_match = true
			local temp_item = new_gear_table[k]

			for x,y in pairs(full_gear_table_from_file) do
				if v.id == y.id then
					if type(item_has_augment.augments) == 'table' and table.length(item_has_augment.augments) > 0 then
						for i, j in pairs(y) do
							local int = 0
							if i == 'augments' then
								for a,b in pairs(item_has_augment.augments) do
									-- (v1.10) the saved copy can have fewer augment lines (re-augmented item): that is
									-- no match, not an error (the error stopped the whole display updating)
									if type(j) == 'table' and type(j[a]) == 'string' and j[a]:contains(b) then
										int = int +1
									end
								end
								if int == table.length(item_has_augment.augments) then
									y.augments = item_has_augment.augments
									local_gear_table[#local_gear_table +1] = y
									sloted_items[k] = local_gear_table[#local_gear_table]
									no_match = false
									break
								end
							end
						end
					else
                        no_match = false
						local_gear_table[#local_gear_table+1] = y
						sloted_items[k] = local_gear_table[#local_gear_table]
					end
				end	
			end

			if no_match == true then

				local_gear_table[#local_gear_table+1] = parse_new_single_item(temp_item)
				sloted_items[k] = local_gear_table[#local_gear_table]
				no_match = false
			end
			
			-- (v1.10, v1.11) ranked gear: add the rank bonuses (res/JSE_Neck_Ranks.lua, res/Limbus_Ranks.lua)
			if Ranked_Gear[v.id] and type(sloted_items[k]) == 'table' then
				sloted_items[k] = with_rank_bonus(sloted_items[k], Ranked_Gear[v.id], item_has_augment)
			end
		else
			local_gear_table[#local_gear_table+1] = {id = 0, en = '', category = '', delay = 0, haste = 0, dual_wield = 0, stp = 0, augments = '' }
			sloted_items[k] = local_gear_table[#local_gear_table]
		end
	end
	
	--log(table.length(local_gear_table) .. ' ' .. table.length(sloted_items))
	
	player.equipment = sloted_items
	
	return sloted_items
end

--options_load()
			
-- windower.register_event('job change',function()
	-- player = windower.ffxi.get_player()
	-- -- get_player_skill_in_gear(check_equipped())
	-- -- player.stats = get_packet_data_base_stats()
    -- --initialize(text_box,settings)
-- end)

function incoming_chunk(id,data,modified,injected,blocked)
        
    if not injected and parse.i[id] then
        parse.i[id](data,blocked)
    end
end

function outgoing_chunk(id,original,data,injected,blocked)
    
    if not blocked and parse.o[id] then
        parse.o[id](data,injected)
    end
end

--table.vprint(windower.get_windower_settings())

-- update() now lives in Display.lua

loop_count = 0
frame_count = 0
windower.register_event('prerender',function()
	if frame_count%2 == 0 and windower.ffxi.get_info().logged_in then
		centre_all_text()
	end
    if frame_count%15 == 0 and windower.ffxi.get_info().logged_in then
        local temp_equip = player.equipment
        local temp_stats = player.stats
		local temp_pos = player.position
        player = windower.ffxi.get_player()
        player.equipment = temp_equip
		-- get_player_skill_in_gear(check_equipped())
        player.stats = temp_stats
		player.position = temp_pos
		player.is_moving = check_player_movement(player)
		check_buffs()
		update_party()
		calculate_total_haste()
        update()
		loop_count = loop_count + 1
    end
    frame_count = frame_count + 1
end)

windower.register_event('incoming chunk',incoming_chunk)
windower.register_event('outgoing chunk',outgoing_chunk)

windower.register_event('incoming text', function(old, new, color)
    --Hides Battlemod
	if settings.player.show_COR_messages then
		if old:match("Roll.* The total.*") or old:match('.*Roll.*' .. string.char(0x81, 0xA8)) or old:match('.*uses Double.*The total') and color ~= 123 then
			return true
		end

		--Hides normal
		if old:match('.* receives the effect of .* Roll.') ~= nil then
			return true
		end

		--Hides Older Battlemod versions --Antiquated
		if old:match('%('..'%w+'..'%).* Roll ') then
			new = old
		end

		return new, color
	-- else
		-- return old, color
	end
end)

-- update() runs about 4x per second. Sending 'gs c gearinfo ...' every time floods Gearswap's command queue,
-- so only send when the payload changed. A slow heartbeat re-sends the current values every ~5 seconds so a
-- Gearswap that was reloaded in the meantime catches up. The command format itself is unchanged, so existing
-- Gearswap lua files keep working.
local last_gs_command = nil
local gs_calls_since_send = 0
local GS_HEARTBEAT_CALLS = 20

function update_gs(DW, Total_DW_needed, haste, MA, MA_needed, force)
	local command
	if DW == true then
		command = 'gs c gearinfo '..Total_DW_needed .. ' ' .. haste ..' '.. tostring(player.is_moving)..' '..tostring(MA)
	elseif DW == false then
		if MA then
			command = 'gs c gearinfo '.. tostring(DW).. ' ' .. haste ..' '.. tostring(player.is_moving)..' '..MA_needed
		else
			command = 'gs c gearinfo '..Total_DW_needed .. ' ' .. haste ..' '.. tostring(player.is_moving)..' '..tostring(MA)
		end
	end
	if not command then return end
	
	gs_calls_since_send = gs_calls_since_send + 1
	if not force and command == last_gs_command and gs_calls_since_send < GS_HEARTBEAT_CALLS then
		return
	end
	last_gs_command = command
	gs_calls_since_send = 0
	windower.send_command(command)
end

windower.register_event('unload', function()

end)