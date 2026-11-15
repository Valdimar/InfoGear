--[[
	Commands.lua (v1.30)

	Every //ig command in one list: its names, what it takes, its help line and what it does. //ig help is made
	from the same list, so the help can't go out of date. Commands are grouped into topics for //ig help <topic>.

	Toggles take an optional on / off (//ig lock on); without one they flip. Commands that take a number show the
	current value when typed without one. Old spellings still work (//ig s wstp, //ig ugs true, //ig show cor...).
]]

local chat_white = string.char(0x1F, 001)
local chat_yellow = string.char(0x1F, 036)
local chat_d_blue = string.char(0x1F, 207)
local chat_grey = string.char(0x1F, 160)
local chat_l_blue = string.char(0x1E, 6)

local function say(text) windower.add_to_chat(207, '[' .. _addon.name .. '] ' .. text) end

-- 'on' / 'off' (or true / false / 1 / 0) -> true / false; nil when it's neither
function parse_on_off(word)
	word = word and tostring(word):lower()
	if word == 'on' or word == 'true' or word == '1' or word == 'yes' then return true end
	if word == 'off' or word == 'false' or word == '0' or word == 'no' then return false end
	return nil
end

local function on_off(v) return v and 'on' or 'off' end

local function deep_copy(t)
	if type(t) ~= 'table' then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = deep_copy(v) end
	return out
end

-- "+10" / "-5" / "10" -> number (nil if it isn't one)
local function number_arg(a)
	return a and tonumber((tostring(a):gsub('^%+', '')))
end

-------------------------------------------------------------------------------------------------------------
-- showing and hiding cards
-------------------------------------------------------------------------------------------------------------
-- the main cards: //ig show <key>
main_card_toggles = {
	{key = 'haste', setting = 'show_total_haste', label = 'Haste (Gear / Magic / JA / Total)'},
	{key = 'dt',    setting = 'show_dt_Stuff',    label = 'DT / PDT / MDT / BDT'},
	{key = 'tp',    setting = 'show_tp_Stuff',    label = 'TP per hit / hits to WS'},
	{key = 'acc',   setting = 'show_acc_Stuff',   label = 'Accuracy'},
	{key = 'att',   setting = 'show_att_Stuff',   label = 'Attack'},
	{key = 'eva',   setting = 'show_Evasion',     label = 'Evasion'},
	{key = 'def',   setting = 'show_Defence',     label = 'Defence'},
	{key = 'stp',   setting = 'show_STP',         label = 'Store TP'},
	{key = 'dw',    setting = 'show_DW_Stuff',    label = 'Dual Wield (+ needed)'},
	{key = 'ma',    setting = 'show_MA_Stuff',    label = 'Martial Arts (+ needed)'},
	{key = 'speed', setting = 'show_speed',       label = 'Movement speed'},
}

local function set_all_cards(value)
	for _, m in ipairs(main_card_toggles) do settings.player[m.setting] = value end
	settings.player.cards = settings.player.cards or {}
	for _, c in ipairs(extra_cards) do settings.player.cards[c.key] = value end
end

-- Turns a card (main or extra), a group of extra cards, or 'all' on / off. value nil = flip.
-- Returns false if the name isn't a card or group.
local function set_card(name, value)
	settings.player.cards = settings.player.cards or {}
	local cards = settings.player.cards
	if name == 'all' then
		set_all_cards(value ~= false)
		say('All cards ' .. on_off(value ~= false) .. '.')
		return true
	end
	for _, m in ipairs(main_card_toggles) do
		if m.key == name then
			if value == nil then value = settings.player[m.setting] ~= true end
			settings.player[m.setting] = value
			say(m.label .. ': ' .. on_off(value) .. '.')
			return true
		end
	end
	for _, c in ipairs(extra_cards) do
		if c.key == name then
			if value == nil then value = cards[c.key] ~= true end
			cards[c.key] = value
			say(c.label .. ': ' .. on_off(value) .. '.')
			return true
		end
	end
	for _, g in ipairs(extra_card_groups) do
		if g.key == name then
			if value == nil then	-- flip: any card of the group off -> all on; all on -> all off
				value = false
				for _, c in ipairs(extra_cards) do
					if c.group == g.key and cards[c.key] ~= true then value = true end
				end
			end
			local labels = {}
			for _, c in ipairs(extra_cards) do
				if c.group == g.key then cards[c.key] = value; labels[#labels + 1] = c.label end
			end
			say(g.key .. ' cards (' .. table.concat(labels, ', ') .. '): ' .. on_off(value) .. '.')
			return true
		end
	end
	return false
end

function cards_list()
	local cards = settings.player.cards or {}
	say('Cards (* = shown). //ig show <name> or <group>, //ig hide <name>, //ig show all, //ig hide all:')
	local parts = {}
	for _, m in ipairs(main_card_toggles) do parts[#parts + 1] = m.key .. (settings.player[m.setting] == true and '*' or '') end
	windower.add_to_chat(207, string.format('  %-9s %s', 'main', table.concat(parts, ' ')))
	for _, g in ipairs(extra_card_groups) do
		parts = {}
		for _, c in ipairs(extra_cards) do
			if c.group == g.key then parts[#parts + 1] = c.key .. (cards[c.key] == true and '*' or '') end
		end
		windower.add_to_chat(207, string.format('  %-9s %s', g.key, table.concat(parts, ' ')))
	end
end

local function show_command(args, value_default)
	local name = args[1] and tostring(args[1]):lower()
	if not name then
		if value_default == false then	-- //ig hide on its own: everything off (as before)
			set_card('all', false)
		else
			cards_list()
		end
		return
	end
	-- //ig show cor: the old way to toggle the roll chat messages
	if name == 'cor' and value_default ~= false then
		settings.player.show_COR_messages = not settings.player.show_COR_messages
		say('Phantom Roll chat messages: ' .. on_off(settings.player.show_COR_messages) .. '.')
		return
	end
	local value = parse_on_off(args[2])
	if value == nil then value = value_default end
	if not set_card(name, value) then
		say('No card or group called "' .. name .. '". //ig cards lists them.')
	end
end

-------------------------------------------------------------------------------------------------------------
-- numbers added by hand (until the addon is reloaded)
-------------------------------------------------------------------------------------------------------------
local manual_numbers = {
	stp     = {var = 'manual_stp',       label = 'Store TP'},
	dw      = {var = 'manual_dw',        label = 'Dual Wield'},
	dwn     = {var = 'manual_dw_needed', label = 'Dual Wield needed'},
	ghaste  = {var = 'manual_ghaste',    label = 'Gear Haste'},
	mhaste  = {var = 'manual_mhaste',    label = 'Magic Haste'},
	jahaste = {var = 'manual_jahaste',   label = 'Job Ability Haste'},
}
local manual_order = {'stp', 'dw', 'dwn', 'ghaste', 'mhaste', 'jahaste'}

local function manual_command(name, args)
	local m = manual_numbers[name]
	local v = number_arg(args[1])
	if v then
		_G[m.var] = v
		say(m.label .. ' added by hand: ' .. string.format('%+d', v) .. (v == 0 and ' (cleared)' or '') .. '.')
	else
		say(m.label .. ' added by hand: ' .. string.format('%+d', tonumber(_G[m.var]) or 0)
			.. '. //ig ' .. name .. ' <number> changes it, 0 clears it.')
	end
end

local function manual_list_command(args)
	if args[1] and tostring(args[1]):lower() == 'clear' then
		for _, k in ipairs(manual_order) do _G[manual_numbers[k].var] = 0 end
		say('All numbers added by hand cleared.')
		return
	end
	local parts = {}
	for _, k in ipairs(manual_order) do
		parts[#parts + 1] = k .. ' ' .. string.format('%+d', tonumber(_G[manual_numbers[k].var]) or 0)
	end
	say('Added by hand: ' .. table.concat(parts, ', ') .. '. //ig manual clear sets them all to 0.')
end

-------------------------------------------------------------------------------------------------------------
-- party members' bonuses: BRD songs, COR rolls, GEO bubbles
-------------------------------------------------------------------------------------------------------------
local party_jobs = {
	brd = {list = 'Bards', manual = 'manual_bard_duration_bonus', what = 'song bonus (all songs +#)', job = 'BRD'},
	cor = {list = 'Cors',  manual = 'manual_COR_bonus',           what = 'Phantom Roll +#',          job = 'COR'},
	geo = {list = 'Geos',  manual = 'manual_GEO_bonus',           what = 'Geomancy +#',              job = 'GEO'},
}

local function party_job_command(name, args)
	local p = party_jobs[name]
	settings[p.list] = settings[p.list] or {}
	local list = settings[p.list]
	local sub = args[1] and tostring(args[1]):lower()
	local n = number_arg(args[1])
	if n then
		_G[p.manual] = n
		say(p.job .. ' ' .. p.what .. ' for anyone not on your list: +' .. n .. '.')
	elseif sub == 'add' then
		local who, bonus = args[2] and tostring(args[2]):lower(), number_arg(args[3])
		if not who or not bonus then say('Use //ig ' .. name .. ' add <name> <bonus>, e.g. //ig ' .. name .. ' add bob 5.') return end
		if name == 'brd' then
			list[who] = deep_copy(default_bard_settings)	-- (each bard gets their own copy)
			list[who]['song_bonus']['all_songs'] = bonus
		else
			list[who] = bonus
		end
		settings:save('all')
		say('Added ' .. who .. ' as a ' .. p.job .. ' with ' .. p.what:gsub('#', tostring(bonus)) .. '.')
		if name == 'brd' then say('(Each song can be set on its own in data/' .. player.name .. '_settings.xml.)') end
	elseif sub == 'del' or sub == 'delete' or sub == 'remove' then
		local who = args[2] and tostring(args[2]):lower()
		if who and list[who] ~= nil then
			list[who] = nil
			settings:save('all')
			say('Removed ' .. who .. ' from your ' .. p.job .. ' list.')
		else
			say('No ' .. p.job .. ' called "' .. tostring(who) .. '" on your list.')
		end
	elseif name == 'cor' and (sub == 'msgs' or sub == 'messages' or sub == 'chat') then
		local v = parse_on_off(args[2])
		if v == nil then v = not settings.player.show_COR_messages end
		settings.player.show_COR_messages = v
		say('Phantom Roll chat messages: ' .. on_off(v) .. '.')
	else
		local names = {}
		for who, v in pairs(list) do
			local b = (type(v) == 'table') and (v.song_bonus and v.song_bonus.all_songs) or v
			names[#names + 1] = who .. ' +' .. tostring(b)
		end
		table.sort(names)
		say(p.job .. ' ' .. p.what .. ' for anyone not on your list: +' .. tostring(tonumber(_G[p.manual]) or 0)
			.. '. Your list: ' .. (#names > 0 and table.concat(names, ', ') or 'empty') .. '.')
		say('//ig ' .. name .. ' <bonus> | add <name> <bonus> | del <name>' .. (name == 'cor' and ' | msgs [on|off]' or ''))
	end
end

-------------------------------------------------------------------------------------------------------------
-- the command list
-------------------------------------------------------------------------------------------------------------
local topics = {
	{key = 'display', title = 'Display'},
	{key = 'cards',   title = 'Cards'},
	{key = 'tools',   title = 'Looking into the numbers'},
	{key = 'buffs',   title = 'Buffs, food and party'},
	{key = 'manual',  title = 'Adding numbers by hand'},
	{key = 'gs',      title = 'Gearswap'},
	{key = 'misc',    title = 'Other'},
}

local function extras(name) return function(args) extras_command(name, args) end end

ig_commands = {
	-- display
	{topic = 'display', names = {'columns', 'cols'}, usage = 'columns 4|5|6', help = 'Cards per row (4 = default).', run = function(a) columns_command(a) end},
	{topic = 'display', names = {'size'}, usage = 'size normal|small', help = 'Card size; small = smaller cards and text.', run = function(a) size_command(a) end},
	{topic = 'display', names = {'scale'}, usage = 'scale <0.5-2>', help = 'Size of the whole display (1 = normal).', run = function(a) scale_command(a) end},
	{topic = 'display', names = {'lock'}, usage = 'lock [on|off]', help = 'Lock the display so it can\'t be dragged.', run = extras('lock')},
	{topic = 'display', names = {'hover'}, usage = 'hover [on|off]', help = 'Breakdown box when the mouse is over a card.', run = extras('hover')},
	{topic = 'display', names = {'cutscene'}, usage = 'cutscene [on|off]', help = 'Hide the display during cutscenes.', run = extras('cutscene')},
	-- cards
	{topic = 'cards', names = {'cards'}, usage = 'cards', help = 'List every card and group, * = shown.', run = function() cards_list() end},
	{topic = 'cards', names = {'show'}, usage = 'show <card|group|all> [on|off]', help = 'Turn cards on (flips without on / off).', run = function(a) show_command(a, nil) end},
	{topic = 'cards', names = {'hide'}, usage = 'hide [card|group|all]', help = 'Turn cards off; on its own: all of them.', run = function(a) show_command(a, false) end},
	{topic = 'cards', names = {'jobcards'}, usage = 'jobcards [on|off]', help = 'Each main job keeps its own cards.', run = extras('jobcards')},
	-- tools
	{topic = 'tools', names = {'why'}, usage = 'why dt|pet', help = 'What each item gives to your DT / your pet\'s DT.', run = function(a) why_command(a) end},
	{topic = 'tools', names = {'snap'}, usage = 'snap <name> | snap del <name>', help = 'Save every card\'s value under a name.', run = extras('snap')},
	{topic = 'tools', names = {'diff'}, usage = 'diff <name>', help = 'What changed since that snapshot.', run = extras('diff')},
	{topic = 'tools', names = {'snaps'}, usage = 'snaps', help = 'List your snapshots.', run = extras('snaps')},
	{topic = 'tools', names = {'eva'}, usage = 'eva [number]', help = 'Your target\'s evasion, for the Hit % card (/check adds its level).', run = extras('eva')},
	{topic = 'tools', names = {'settings', 'status'}, usage = 'settings', help = 'Show your current InfoGear settings.', run = function() settings_command() end},
	-- buffs
	{topic = 'buffs', names = {'food'}, usage = 'food [name|off]', help = 'The food InfoGear counts; set or clear it by hand.', run = extras('food')},
	{topic = 'buffs', names = {'sanction'}, usage = 'sanction regen|refresh|food', help = 'The bonus you picked for Sanction.', run = extras('sanction')},
	{topic = 'buffs', names = {'sigil'}, usage = 'sigil regen|refresh|food', help = 'The bonus you picked for Sigil.', run = extras('sigil')},
	{topic = 'buffs', names = {'regen'}, usage = 'regen [number]', help = 'HP per tick added to Regen spells on you (caster\'s potency).', run = extras('regen')},
	{topic = 'buffs', names = {'refresh'}, usage = 'refresh [number]', help = 'MP per tick added to Refresh spells on you.', run = extras('refresh')},
	{topic = 'buffs', names = {'brd'}, usage = 'brd [bonus] | add <name> <bonus> | del <name>', help = 'Bards\' song bonus (March etc.).', run = function(a) party_job_command('brd', a) end},
	{topic = 'buffs', names = {'cor'}, usage = 'cor [bonus] | add <name> <bonus> | del <name> | msgs', help = 'CORs\' Phantom Roll +#; msgs = roll chat messages.', run = function(a) party_job_command('cor', a) end},
	{topic = 'buffs', names = {'geo'}, usage = 'geo [bonus] | add <name> <bonus> | del <name>', help = 'GEOs\' Geomancy +#.', run = function(a) party_job_command('geo', a) end},
	{topic = 'buffs', names = {'dnc'}, usage = 'dnc [on|off]', help = 'Haste Samba comes from a main DNC.', run = function(a)
		local v = parse_on_off(a[1]); if v == nil then v = not dancer_main end
		dancer_main = v
		say('Haste Samba from a main DNC: ' .. on_off(v) .. '.')
	end},
	-- manual
	{topic = 'manual', names = {'stp'}, usage = 'stp [number]', help = 'Store TP to add (0 clears).', run = function(a) manual_command('stp', a) end},
	{topic = 'manual', names = {'dw'}, usage = 'dw [number]', help = 'Dual Wield to add.', run = function(a) manual_command('dw', a) end},
	{topic = 'manual', names = {'dwn'}, usage = 'dwn [number]', help = 'Dual Wield needed to add.', run = function(a) manual_command('dwn', a) end},
	{topic = 'manual', names = {'ghaste'}, usage = 'ghaste [number]', help = 'Gear Haste to add.', run = function(a) manual_command('ghaste', a) end},
	{topic = 'manual', names = {'mhaste'}, usage = 'mhaste [number]', help = 'Magic Haste to add.', run = function(a) manual_command('mhaste', a) end},
	{topic = 'manual', names = {'jahaste'}, usage = 'jahaste [number]', help = 'Job Ability Haste to add.', run = function(a) manual_command('jahaste', a) end},
	{topic = 'manual', names = {'manual'}, usage = 'manual [clear]', help = 'List the numbers added by hand / clear them all.', run = function(a) manual_list_command(a) end},
	-- gearswap
	{topic = 'gs', names = {'ugs', 'updategs'}, usage = 'ugs [on|off]', help = 'Send haste / DW to Gearswap automatically.', run = function(a)
		local v = parse_on_off(a[1]); if v == nil then v = not settings.player.update_gs end
		settings.player.update_gs = v
		settings:save('all')
		say('Send to Gearswap automatically: ' .. on_off(v) .. '.')
	end},
	{topic = 'gs', names = {'update'}, usage = 'update', help = 'Send to Gearswap once now.', run = function()
		update_gs(DW, (DW_needed + manual_dw_needed), get_total_haste(), nil, nil, true)
		say('Sent to Gearswap.')
	end},
	{topic = 'gs', names = {'wstp', 'save', 's', 'delete', 'd'}, usage = 'wstp save|clear', help = 'Keep your current TP per hit as a second line / remove it.', run = nil},
	-- misc
	{topic = 'misc', names = {'rank'}, usage = 'rank [number]', help = 'Your Unity rank (for Unity gear).', run = function(a)
		local n = number_arg(a[1])
		if n then
			settings.player.rank = n
			settings:save('all')
			say('Unity rank: ' .. n .. '. //ig parse reads your gear again with it.')
		else
			say('Unity rank: ' .. tostring(settings.player.rank) .. '. //ig rank <number> changes it.')
		end
	end},
	{topic = 'misc', names = {'parse'}, usage = 'parse', help = 'Read all your gear again (after changing Unity rank).', run = function()
		say('Reading all your gear again...')
		parse_inventory()
	end},
	{topic = 'misc', names = {'reload', 'r'}, usage = 'reload', help = 'Reload InfoGear, keeping party and buffs.', run = function()
		local f = io.open(windower.addon_path .. 'data/' .. player.name .. '_temp_party.lua', 'w')
		if f then f:write('return ' .. T(member_table):tovstring()); f:close() end
		f = io.open(windower.addon_path .. 'data/' .. player.name .. '_temp_buffs.lua', 'w')
		if f then f:write('return ' .. T(_ExtraData.player.buff_details):tovstring()); f:close() end
		say('Party and buffs saved; reloading.')
		windower.send_command('lua r infogear')
	end},
	{topic = 'misc', names = {'debug'}, usage = 'debug [on|off]', help = 'Debug messages.', run = function(a)
		local v = parse_on_off(a[1]); if v == nil then v = not debug_mode end
		debug_mode = v
		say('Debug mode: ' .. on_off(v) .. '.')
	end},
	{topic = 'misc', names = {'help', '?'}, usage = 'help [topic|command]', help = 'This list; e.g. //ig help buffs, //ig help show.', run = nil},
}

-- wstp: //ig wstp save|clear (also the old //ig save wstp, //ig s wstp, //ig delete wstp, //ig d wstp)
local function wstp_command(command, args)
	local sub = args[1] and tostring(args[1]):lower()
	local save = (command == 'wstp' and sub == 'save') or ((command == 'save' or command == 's') and sub == 'wstp')
	local clear = (command == 'wstp' and (sub == 'clear' or sub == 'delete' or sub == 'del'))
		or ((command == 'delete' or command == 'd') and sub == 'wstp')
	if save then
		WSTP = get_tp_per_hit(player.equipment).tp_per_hit_melee
		say('TP per hit ' .. tostring(WSTP) .. ' kept as a second line on the TP cards. //ig wstp clear removes it.')
	elseif clear then
		WSTP = 0
		say('Second TP line removed.')
	else
		say('Use //ig wstp save (keep your current TP per hit as a second line) or //ig wstp clear.')
	end
end

local by_name = {}
for _, c in ipairs(ig_commands) do
	for _, n in ipairs(c.names) do by_name[n] = c end
end

-------------------------------------------------------------------------------------------------------------
-- help
-------------------------------------------------------------------------------------------------------------
local function help_line(c)
	local alias = #c.names > 1 and (chat_grey .. ' (also ' .. table.concat(c.names, ', ', 2) .. ')') or ''
	windower.add_to_chat(207, '  ' .. chat_l_blue .. '//ig ' .. c.usage .. chat_white .. '  ' .. c.help .. alias)
end

local function help_command(args)
	local want = args[1] and tostring(args[1]):lower()
	if want then
		for _, t in ipairs(topics) do
			if t.key == want or t.title:lower():find(want, 1, true) == 1 then
				windower.add_to_chat(207, chat_d_blue .. 'InfoGear: ' .. t.title)
				for _, c in ipairs(ig_commands) do if c.topic == t.key then help_line(c) end end
				return
			end
		end
		local c = by_name[want]
		if c then help_line(c) return end
		say('No help topic or command called "' .. want .. '".')
	end
	windower.add_to_chat(207, chat_d_blue .. 'InfoGear ' .. _addon.version .. ' commands (//ig help <topic> for details):')
	for _, t in ipairs(topics) do
		local names = {}
		for _, c in ipairs(ig_commands) do if c.topic == t.key then names[#names + 1] = c.names[1] end end
		windower.add_to_chat(207, string.format('  %s%-8s%s %s', chat_l_blue, t.key, chat_white, t.title .. ': ' .. chat_grey .. table.concat(names, ', ')))
	end
	windower.add_to_chat(207, chat_white .. '  e.g. ' .. chat_yellow .. '//ig help cards' .. chat_white .. ', ' .. chat_yellow .. '//ig help show')
end

-------------------------------------------------------------------------------------------------------------
-- //ig settings
-------------------------------------------------------------------------------------------------------------
function settings_command()
	local p = settings.player
	local shown = 0
	for _, m in ipairs(main_card_toggles) do if p[m.setting] == true then shown = shown + 1 end end
	for _, c in ipairs(extra_cards) do if p.cards and p.cards[c.key] == true then shown = shown + 1 end end
	say('Settings for ' .. player.name .. ' (' .. tostring(player.main_job) .. '):')
	local lines = {
		string.format('display: %d columns, %s cards, scale %s, %s, hover %s, hide in cutscenes %s',
			layout_current_columns(), (layout_current_size()),
			tostring(layout_current_scale()), p.locked and 'locked' or 'unlocked',
			on_off(p.hover ~= false), on_off(p.hide_cutscene ~= false)),
		string.format('cards: %d shown, cards per job %s (//ig cards lists them)', shown, on_off(p.job_cards ~= false)),
		string.format('buffs: food %s, Sanction %s, Sigil %s, Regen spells %+d, Refresh spells %+d',
			food and food.name or 'none', (p.sanction and p.sanction ~= '') and p.sanction or 'not set',
			(p.sigil and p.sigil ~= '') and p.sigil or 'not set', tonumber(p.regen_bonus) or 0, tonumber(p.refresh_bonus) or 0),
		string.format('party: BRD +%d, COR +%d, GEO +%d (not on your list), Haste Samba from main DNC %s',
			tonumber(manual_bard_duration_bonus) or 0, tonumber(manual_COR_bonus) or 0, tonumber(manual_GEO_bonus) or 0, on_off(dancer_main)),
		string.format('Gearswap: automatic %s; Unity rank %s', on_off(p.update_gs), tostring(p.rank)),
	}
	for _, l in ipairs(lines) do windower.add_to_chat(207, '  ' .. l) end
end

-------------------------------------------------------------------------------------------------------------
-- running a command
-------------------------------------------------------------------------------------------------------------
local function distance(a, b)	-- edit distance, for "did you mean"
	local d = {}
	for i = 0, #a do d[i] = {[0] = i} end
	for j = 0, #b do d[0][j] = j end
	for i = 1, #a do
		for j = 1, #b do
			local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
			d[i][j] = math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
		end
	end
	return d[#a][#b]
end

function infogear_command(command, ...)
	local args = {...}
	command = command and tostring(command):lower()
	if not command or command == '' then help_command({}) return end
	if command == 'help' or command == '?' then help_command(args) return end
	if command == 'wstp' or ((command == 'save' or command == 's' or command == 'delete' or command == 'd')) then
		wstp_command(command, args)
		return
	end
	local c = by_name[command]
	if c and c.run then
		c.run(args)
		return
	end
	-- not a command: maybe a card name (//ig da -> //ig show da)
	for _, m in ipairs(main_card_toggles) do if m.key == command then show_command({command, args[1]}, nil) return end end
	for _, x in ipairs(extra_cards) do if x.key == command then show_command({command, args[1]}, nil) return end end
	local best, best_d = nil, 3
	for n in pairs(by_name) do
		local dd = distance(command, n)
		if dd < best_d then best, best_d = n, dd end
	end
	say('Unknown command "' .. command .. '".' .. (best and (' Did you mean //ig ' .. best .. '?') or '') .. ' //ig help lists them.')
end
