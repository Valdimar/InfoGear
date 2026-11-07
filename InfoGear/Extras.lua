--[[
	Extras.lua (v1.27)

	* Per-job cards: which cards are shown is remembered for each main job (data/<name>_jobs.lua). Changing job
	  switches to that job's cards; a job seen for the first time starts with the cards you had. //ig jobcards
	  turns this off (then one set of cards for every job, as before).
	* Food: the food you eat is read from its own item description (resources), "+10% (Max. 75)" counted as +75,
	  and added to your totals while the Food effect is on. //ig food shows it, //ig food <name> | off sets it.
	* Ionis / Sanction / Sigil (/ Signet): stats from res/Field_Buffs.lua while the effect is on.
	* Hover: with the mouse over a card, a box lists what gives that number (each item, food, field buffs, buffs).
	  //ig hover turns it off / on.
	* Snapshots: //ig snap <name> saves every card's value, //ig diff <name> shows what changed since,
	  //ig snaps lists them, //ig snap del <name> deletes one (data/<name>_snaps.lua).
]]

Field_Buffs = require('res/Field_Buffs')

local function say(text) windower.add_to_chat(207, '[' .. _addon.name .. '] ' .. text) end

local function has_buff(id)
	for _, b in pairs((player and player.buffs) or {}) do
		if b == id then return true end
	end
	return false
end

-- small Lua-table writer for the data files (strings, numbers, booleans, nested tables)
local function serialize(v, indent)
	indent = indent or ''
	if type(v) == 'table' then
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		local out = {'{\n'}
		for _, k in ipairs(keys) do
			local key = type(k) == 'number' and ('[' .. k .. ']') or ('[' .. string.format('%q', tostring(k)) .. ']')
			out[#out + 1] = indent .. '\t' .. key .. ' = ' .. serialize(v[k], indent .. '\t') .. ',\n'
		end
		out[#out + 1] = indent .. '}'
		return table.concat(out)
	elseif type(v) == 'string' then
		return string.format('%q', v)
	else
		return tostring(v)
	end
end

local function data_path(suffix)
	return windower.addon_path .. 'data/' .. player.name .. suffix
end

local function read_table(path)
	local f = io.open(path, 'r')
	if not f then return {} end
	local text = f:read('*a')
	f:close()
	local chunk = loadstring(text)
	if not chunk then return {} end
	local ok, t = pcall(chunk)
	return (ok and type(t) == 'table') and t or {}
end

local function write_table(path, t)
	local f = io.open(path, 'w')
	if not f then return end
	f:write('return ' .. serialize(t) .. '\n')
	f:close()
end

local function stats_text(stats)
	local keys, parts = {}, {}
	for k in pairs(stats) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local v = stats[k]
		parts[#parts + 1] = k .. ' ' .. (v >= 0 and '+' or '') .. v
	end
	return table.concat(parts, ', ')
end

-------------------------------------------------------------------------------------------------------------
-- food
-------------------------------------------------------------------------------------------------------------
local FOOD_BUFF = 251
food = nil					-- {id, name, stats}
local food_set_at = 0
local food_seen = false		-- the Food effect has been on since this food was set
local food_candidate, food_candidate_at = nil, 0

-- The stats a food gives, from its item description. Percent stats with a cap ("Accuracy+10% (Max. 75)") count
-- as the cap, which you reach with endgame stats. The pet's part ("Pet: ...") is cut off like on gear.
function food_stats(id)
	local item, desc = res.items[id], res.item_descriptions[id]
	if not item or not desc or item.category ~= 'Usable' then return nil end
	local text = desc.en:gsub('\n', ' ')
	text = text:gsub('([+-])%d+%%%s?%(Max%.%s?(%d+)%)', '%1%2')
	-- short forms some foods use
	text = text:gsub('\"M%.%s?Atk%.%s?Bonus\"', '\"Magic Atk. Bonus\"'):gsub('\"M%.%s?Def%.%s?Bonus\"', '\"Magic Def. Bonus\"')
	text = text:gsub('R%.%s?Accuracy', 'Ranged Accuracy'):gsub('R%.%s?Attack', 'Ranged Attack')
	text = text:gsub('M%.%s?Accuracy', 'Magic Accuracy'):gsub('M%.%s?Evasion', 'Magic Evasion')
	text = text:gsub('[HM]P recovered [%a ]-healing%s?[+-]%d+', '')	-- resting only
	local parsed = desypher_description(text, item)
	local stats, any = {}, false
	for k, v in pairs(parsed) do
		if type(v) == 'number' and v ~= 0 and k ~= 'delay' and k ~= 'damage' then
			stats[k] = v
			any = true
		end
	end
	return any and stats or nil
end

local function set_food(id, quiet)
	local stats = id and food_stats(id)
	if not stats then return false end
	food = {id = id, name = res.items[id].en, stats = stats}
	food_set_at = os.time()
	food_seen = false
	settings.player.food_id = id
	settings:save('all')
	if not quiet then say('Food: ' .. food.name .. ' (' .. stats_text(stats) .. ')') end
	return true
end

local function clear_food()
	food = nil
	food_candidate = nil
	settings.player.food_id = 0
	settings:save('all')
end

-- the item you used: message 375 is "<you> use <item>. You receive the effect of <status>." with the status id
windower.register_event('action', function(act)
	if act.category ~= 5 or not player or act.actor_id ~= player.id then return end
	local t = act.targets and act.targets[1]
	local a = t and t.actions and t.actions[1]
	if a and a.param == FOOD_BUFF then
		set_food(act.param)
	elseif act.param and act.param > 0 and food_stats(act.param) then
		food_candidate, food_candidate_at = act.param, os.time()	-- confirmed when the Food effect shows up
	end
end)

local function food_check()
	local active = has_buff(FOOD_BUFF)
	if not food and not food_candidate and tonumber(settings.player.food_id) and tonumber(settings.player.food_id) > 0 then
		if active then set_food(tonumber(settings.player.food_id), true) else clear_food() end	-- after a reload
	end
	if food_candidate and active and os.time() - food_candidate_at <= 5 then
		set_food(food_candidate)
		food_candidate = nil
	elseif food_candidate and os.time() - food_candidate_at > 5 then
		food_candidate = nil
	end
	if food and active then food_seen = true end
	if food and not active and (food_seen or os.time() - food_set_at > 10) then
		say('Food worn off: ' .. food.name .. '.')
		clear_food()
	end
end

-------------------------------------------------------------------------------------------------------------
-- Ionis / Sanction / Sigil / Signet
-------------------------------------------------------------------------------------------------------------
local field_warned = {}

local function field_buff_sources()
	local out = {}
	for id, fb in pairs(Field_Buffs) do
		if has_buff(id) then
			local stats, label = fb.stats or {}, fb.name
			if fb.options then
				local pick = settings.player[fb.setting]
				if not pick or pick == '' or not fb.options[pick] then
					if not field_warned[id] then
						say(fb.name .. ' is on: tell InfoGear which bonus you picked with //ig ' .. fb.setting .. ' regen|refresh|food')
						field_warned[id] = true
					end
					stats = {}
				else
					stats = fb.options[pick]
					label = fb.name .. ' (' .. pick .. ')'
				end
			end
			local any = false
			for _, v in pairs(stats) do if v ~= 0 then any = true end end
			if any then out[#out + 1] = {name = label, stats = stats} end
		end
	end
	return out
end

-------------------------------------------------------------------------------------------------------------
-- adding them to the totals (Display.update calls this right after the gear totals are built)
-------------------------------------------------------------------------------------------------------------
extra_sources = {}

function add_extra_sources(stat_table)
	food_check()
	extra_sources = {}
	if food then extra_sources[#extra_sources + 1] = {name = 'Food: ' .. food.name, stats = food.stats} end
	for _, s in ipairs(field_buff_sources()) do extra_sources[#extra_sources + 1] = s end
	for _, src in ipairs(extra_sources) do
		for k, v in pairs(src.stats) do
			if k == 'Haste' then
				stat_table['Haste'] = (stat_table['Haste'] or 0) + math.floor(v / 100 * 1024)
			elseif type(stat_table[k]) ~= 'table' then
				stat_table[k] = (stat_table[k] or 0) + v
			end
		end
	end
	return stat_table
end

-------------------------------------------------------------------------------------------------------------
-- per-job cards
-------------------------------------------------------------------------------------------------------------
local SHOW_KEYS = {'show_total_haste', 'show_dt_Stuff', 'show_tp_Stuff', 'show_acc_Stuff', 'show_att_Stuff',
	'show_Evasion', 'show_Defence', 'show_STP', 'show_speed', 'show_DW_Stuff', 'show_MA_Stuff'}
local job_presets, preset_job = nil, nil

local function current_toggles()
	local t = {cards = {}}
	for _, k in ipairs(SHOW_KEYS) do t[k] = settings.player[k] == true end
	local cards = settings.player.cards or {}
	for _, c in ipairs(extra_cards) do t.cards[c.key] = cards[c.key] == true end
	return t
end

local function apply_toggles(t)
	for _, k in ipairs(SHOW_KEYS) do
		if t[k] ~= nil then settings.player[k] = t[k] end
	end
	settings.player.cards = settings.player.cards or {}
	for _, c in ipairs(extra_cards) do
		if t.cards and t.cards[c.key] ~= nil then settings.player.cards[c.key] = t.cards[c.key] end
	end
end

local function job_cards_on() return settings.player.job_cards ~= false end

function job_presets_check()
	if not job_cards_on() then return end
	local job = player and player.main_job
	if not job or job == preset_job then return end
	if not job_presets then job_presets = read_table(data_path('_jobs.lua')) end
	if job_presets[job] then
		apply_toggles(job_presets[job])
		if preset_job then say('Showing your ' .. job .. ' cards.') end
	else
		job_presets[job] = current_toggles()
	end
	preset_job = job
	write_table(data_path('_jobs.lua'), job_presets)
	settings:save('all')
end

-- after every //ig command: the toggles now shown belong to the current main job
function job_presets_store()
	if not job_cards_on() or not preset_job or not job_presets then return end
	if not player or player.main_job ~= preset_job then return end
	job_presets[preset_job] = current_toggles()
	write_table(data_path('_jobs.lua'), job_presets)
end

-------------------------------------------------------------------------------------------------------------
-- hover breakdown
-------------------------------------------------------------------------------------------------------------
local SLOTS = {'main', 'sub', 'range', 'ammo', 'head', 'neck', 'left_ear', 'right_ear', 'body', 'hands',
	'left_ring', 'right_ring', 'back', 'waist', 'legs', 'feet'}

-- which stats make up each card: keys = gear / food stat names, buffs = keys in the buff details
-- (nil = the same as keys, {} = none), note = what else goes into the number
local card_specs = {
	[1]  = {keys = {'Haste'}, buffs = {'g_haste'}, haste = true, note = 'gear haste cap 256 (25%)'},
	[2]  = {keys = {}, buffs = {'ma_haste'}, haste = true, note = 'magic haste cap 448 (43.75%)'},
	[3]  = {keys = {}, buffs = {'ja_haste'}, haste = true, note = 'JA haste cap 256 (25%)'},
	[4]  = {keys = {'Haste'}, buffs = {'g_haste', 'ma_haste', 'ja_haste'}, haste = true, note = 'total cap 820 (80%)'},
	[5]  = {keys = {'DT'}, buffs = {}, note = 'cap 50'},
	[6]  = {keys = {'DT', 'PDT', 'PDT2'}, buffs = {}, note = 'cap 50 (PDT II raises it)'},
	[7]  = {keys = {'DT', 'MDT', 'MDT2'}, buffs = {}, note = 'cap 50 (MDT II raises it)'},
	[8]  = {keys = {'DT', 'BDT'}, buffs = {}, note = 'cap 50'},
	[9]  = {keys = {'Store TP'}, note = '+ weapon delay, job traits'},
	[10] = {keys = {'Store TP'}, note = '+ weapon delay, job traits'},
	[11] = {keys = {'Store TP'}, note = '+ weapon delay, job traits'},
	[12] = {keys = {'Accuracy', 'DEX'}, note = '+ weapon skill, DEX x0.75, job traits'},
	[13] = {keys = {'Accuracy', 'DEX'}, note = '+ weapon skill, DEX x0.75, job traits'},
	[14] = {keys = {'Attack', 'STR'}, note = '+ weapon skill, STR, job traits'},
	[15] = {keys = {'Attack', 'STR'}, note = '+ weapon skill, STR, job traits'},
	[16] = {keys = {'Store TP'}, note = '+ weapon delay, job traits'},
	[17] = {keys = {'Store TP'}, note = '+ weapon delay, job traits'},
	[18] = {keys = {'Store TP'}, note = '+ weapon delay, job traits'},
	[19] = {keys = {'Ranged Accuracy', 'AGI'}, note = '+ skill, AGI x0.75, job traits'},
	[21] = {keys = {'Ranged Attack', 'STR'}, note = '+ skill, STR, job traits'},
	[22] = {keys = {'Evasion', 'AGI'}, note = '+ evasion skill, AGI / 2, job traits'},
	[23] = {keys = {'DEF', 'VIT'}, note = '+ level, VIT, job traits'},
	[24] = {keys = {'Dual Wield'}, note = '+ job traits'},
	[25] = {keys = {'Dual Wield'}, note = 'Dual Wield still needed for the delay cap at your haste'},
	[26] = {keys = {'Martial Arts'}, note = '+ job traits'},
	[27] = {keys = {'Martial Arts'}, note = 'Martial Arts still needed for the delay cap'},
	[28] = {keys = {'Store TP'}, note = '+ job traits'},
}
local extra_specs = {
	fc = {'Fast Cast'}, macc = {'Magic Accuracy'}, mab = {'Magic Atk. Bonus'}, mbb = {'Magic Burst Bonus'},
	mbb2 = {'Magic Burst Bonus II'}, cure = {'Cure Potency'}, cure2 = {'Cure Potency II'}, da = {'Double Attack'},
	ta = {'Triple Attack', buffs = {'Triple Attack', 'Tripple Attack'}}, qa = {'Quadruple Attack'},
	crit = {'Critical hit rate'}, critdmg = {'Critical hit damage'}, sb = {'Subtle Blow'}, sb2 = {'Subtle Blow II'},
	wsd = {'Weapon Skill Damage'}, pdl = {'Physical Damage Limit'}, snap = {'Snapshot'}, rapid = {'Rapid Shot'},
	meva = {'Magic Evasion'}, mdb = {'Magic Def. Bonus'}, phalanx = {'Phalanx'}, enmity = {'Enmity'},
	hp = {'HP'}, mp = {'MP'}, regen = {'Regen'}, refresh = {'Refresh'}, regain = {'Regain'}, th = {'Treasure Hunter'},
	petdt = {'Pet DT', 'Pet PDT', 'Pet MDT', buffs = {}}, petregen = {'Pet Regen', buffs = {'Pet: Regen'}},
	sird = {'Spell Interruption Rate Down', note = '+ merits; 102 stops all interruption'},
	conserve = {'Conserve MP'},
}
for _, c in ipairs(extra_cards or {}) do
	local e = extra_specs[c.key]
	if e then
		local keys = {}
		for _, k in ipairs(e) do keys[#keys + 1] = k end
		card_specs[c.idx] = {keys = keys, buffs = e.buffs, note = e.note}
	end
end

local function fmt(v)
	if v == math.floor(v) then return (v >= 0 and '+' or '') .. string.format('%d', v) end
	return (v >= 0 and '+' or '') .. string.format('%.1f', v)
end

local function haste_pct(v) return string.format('%+.1f%%', v / 1024 * 100) end

function card_breakdown(idx)
	local b = sections.block[idx]
	local spec = card_specs[idx]
	if not b or not spec then return nil end
	local lines = {}
	lines[1] = (b.label or '') .. '  ' .. tostring(b.value or '')
	local totals = {}
	-- gear
	for _, slot in ipairs(SLOTS) do
		local item = player.equipment and player.equipment[slot]
		if type(item) == 'table' and item.en and item.en ~= '' then
			local parts = {}
			for _, k in ipairs(spec.keys) do
				local v = tonumber(item[k])
				if v and v ~= 0 then
					parts[#parts + 1] = k .. ' ' .. (spec.haste and (fmt(v) .. '%') or fmt(v))
					totals[k] = (totals[k] or 0) + (k == 'Haste' and math.floor(v / 100 * 1024) or v)
				end
			end
			if #parts > 0 then
				local rank = item.item_rank and (' R' .. item.item_rank) or ''
				lines[#lines + 1] = string.format('%-10s %s%s: %s', slot, item.en, rank, table.concat(parts, ', '))
			end
		end
	end
	-- food and field buffs
	for _, src in ipairs(extra_sources) do
		local parts = {}
		for _, k in ipairs(spec.keys) do
			local v = src.stats[k]
			if v and v ~= 0 then
				parts[#parts + 1] = k .. ' ' .. fmt(v) .. (k == 'Haste' and '%' or '')
				totals[k] = (totals[k] or 0) + (k == 'Haste' and math.floor(v / 100 * 1024) or v)
			end
		end
		if #parts > 0 then lines[#lines + 1] = string.format('%-10s %s', '', src.name .. ': ' .. table.concat(parts, ', ')) end
	end
	-- what's left of the gear total: set bonuses (and your base stat for STR / DEX ...)
	for _, k in ipairs(spec.keys) do
		local g = Gear_info and tonumber(Gear_info[k])
		if g then
			local rest = g - (totals[k] or 0)
			if k == 'Haste' then rest = rest - (manual_ghaste or 0) end
			if math.abs(rest) >= (k == 'Haste' and 5 or 1) then	-- (haste: ignore 1024-unit rounding)
				local what = ({STR = 1, DEX = 1, VIT = 1, AGI = 1, INT = 1, MND = 1, CHR = 1})[k] and 'base + set bonus' or 'set bonus / other'
				lines[#lines + 1] = string.format('%-10s %s %s', '', what .. ':', k .. ' ' .. (k == 'Haste' and haste_pct(rest) or fmt(rest)))
			end
		end
	end
	-- buffs
	local buff_keys = spec.buffs or spec.keys
	for _, buff in pairs((_ExtraData and _ExtraData.player and _ExtraData.player.buff_details) or {}) do
		local parts = {}
		for _, k in ipairs(buff_keys) do
			local v = tonumber(buff[k])
			if v and v ~= 0 then
				local shown = k:gsub('_haste', ' haste'):gsub('^g ', 'gear '):gsub('^ma ', 'magic '):gsub('^ja ', 'JA ')
				parts[#parts + 1] = shown .. ' ' .. (spec.haste and haste_pct(v) or fmt(v))
			end
		end
		if #parts > 0 then
			local name = buff.full_name or buff.name or (res.buffs[buff.id] and res.buffs[buff.id].en) or '?'
			local from = buff.Caster and (' (' .. tostring(buff.Caster) .. ')') or ''
			lines[#lines + 1] = string.format('%-10s %s', 'buff', name .. from .. ': ' .. table.concat(parts, ', '))
		end
	end
	if idx == 59 and pet_innate_dt and pet_innate_dt() > 0 then
		lines[#lines + 1] = string.format('%-10s %s', '', 'wyvern innate: DT -' .. pet_innate_dt() .. ' (total cap ' .. pet_dt_overall_cap .. ')')
	end
	if #lines == 1 then lines[#lines + 1] = 'nothing equipped or active gives this' end
	if spec.note then lines[#lines + 1] = '(' .. spec.note .. ')' end
	return lines
end

local TIP = 'InfoGear_hover_box'
local tip_shown, hover_idx, tip_mx, tip_my = false, nil, 0, 0
local tip_lines = {''}

local function hide_tip()
	if tip_shown then windower.text.delete(TIP) end
	tip_shown, hover_idx = false, nil
end

local function place_tip(lines)
	local longest = 0
	for _, l in ipairs(lines) do if #l > longest then longest = #l end end
	local s = (settings.display and tonumber(settings.display.scale)) or 1
	local w, h = longest * 7 * s, #lines * 14 * s
	local ws = windower.get_windower_settings()
	local sw, sh = ws.x_res or 1920, ws.y_res or 1080
	local x, y = tip_mx + 18, tip_my + 14
	if x + w > sw then x = math.max(0, tip_mx - w - 12) end
	if y + h > sh then y = math.max(0, sh - h - 4) end
	windower.text.set_location(TIP, x, y)
end

local function show_tip(idx)
	local lines = card_breakdown(idx)
	if not lines then hide_tip() return end
	if tip_shown then windower.text.delete(TIP) end	-- made again so it is drawn over the cards
	windower.text.create(TIP)
	windower.text.set_font(TIP, 'Consolas')
	windower.text.set_font_size(TIP, math.floor(9 * ((settings.display and tonumber(settings.display.scale)) or 1) + 0.5))
	windower.text.set_color(TIP, 255, 230, 232, 240)
	windower.text.set_bg_color(TIP, 235, 20, 24, 31)
	windower.text.set_bg_border_size(TIP, 4)
	windower.text.set_bg_visibility(TIP, true)
	windower.text.set_text(TIP, table.concat(lines, '\n'))
	tip_lines = lines
	place_tip(lines)
	windower.text.set_visibility(TIP, true)
	tip_shown, hover_idx = true, idx
end

function hover_refresh()
	if not tip_shown or not hover_idx then return end
	if settings.player.hover == false or not sections.block[hover_idx] then hide_tip() return end
	local lines = card_breakdown(hover_idx)
	if not lines then hide_tip() return end
	tip_lines = lines
	windower.text.set_text(TIP, table.concat(lines, '\n'))
end

windower.register_event('mouse', function(type, x, y, delta, blocked)
	if type ~= 0 then return end
	if blocked or settings == nil or settings.player.hover == false or (is_dragging and is_dragging()) then
		if tip_shown then hide_tip() end
		return
	end
	local found = nil
	for idx, b in pairs(sections.block or {}) do
		-- (own hit test: ImageBlock:hover() calls self:visible(), which show() replaces with a boolean)
		local bx, by, bw, bh = tonumber(b.x), tonumber(b.y), tonumber(b.width), tonumber(b.height)
		if bx and by and bw and bh and x >= bx and x <= bx + bw and y >= by and y <= by + bh then found = idx break end
	end
	tip_mx, tip_my = x, y
	if found ~= hover_idx then
		if found then show_tip(found) else hide_tip() end
	elseif found and tip_shown then
		place_tip(tip_lines)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- snapshots
-------------------------------------------------------------------------------------------------------------
local snap_labels = {[25] = 'DW Needed', [27] = 'MA Needed'}

function snapshot_values()
	local t = {}
	for idx, b in pairs(sections.block or {}) do
		if idx ~= 29 and b.label and b.value ~= nil then t[snap_labels[idx] or b.label] = b.value end
	end
	for _, c in ipairs(extra_cards) do
		if t[c.label] == nil and extra_card_values[c.key] and (c.group ~= 'pet' or is_pet_job()) then
			local ok, v = pcall(extra_card_values[c.key])
			if ok and v ~= nil then t[c.label] = v end
		end
	end
	return t
end

local function snaps_load() return read_table(data_path('_snaps.lua')) end
local function snaps_save(t) write_table(data_path('_snaps.lua'), t) end

local function snap_command(args)
	local name = args[1] and tostring(args[1]):lower()
	if not name then say('Use //ig snap <name> (e.g. //ig snap tp), then //ig diff <name>.') return end
	local snaps = snaps_load()
	if name == 'del' or name == 'delete' then
		local which = args[2] and tostring(args[2]):lower()
		if which and snaps[which] then snaps[which] = nil; snaps_save(snaps); say('Deleted snapshot "' .. which .. '".')
		else say('No snapshot called "' .. tostring(which) .. '".') end
		return
	end
	local values = snapshot_values()
	local n = 0
	for _ in pairs(values) do n = n + 1 end
	snaps[name] = {values = values, job = player.main_job .. '/' .. tostring(player.sub_job), time = os.date('%Y-%m-%d %H:%M')}
	snaps_save(snaps)
	say('Saved snapshot "' .. name .. '" (' .. n .. ' values). //ig diff ' .. name .. ' compares with it.')
end

local function to_num(v)
	if type(v) == 'number' then return v end
	if type(v) == 'string' and v:match('^[+-]?[%d%.]+%%?$') then return tonumber((v:gsub('%%', ''))) end
	return nil
end

local function diff_command(args)
	local name = args[1] and tostring(args[1]):lower()
	local snaps = snaps_load()
	local snap = name and snaps[name]
	if not snap then say('No snapshot "' .. tostring(name) .. '". //ig snaps lists them.') return end
	local now = snapshot_values()
	local labels, seen = {}, {}
	for k in pairs(snap.values or {}) do if not seen[k] then labels[#labels + 1] = k; seen[k] = true end end
	for k in pairs(now) do if not seen[k] then labels[#labels + 1] = k; seen[k] = true end end
	table.sort(labels)
	local changes = {}
	for _, k in ipairs(labels) do
		local was, is = snap.values[k], now[k]
		if was == nil or is == nil then
			-- shown in only one of the two (card hidden, or no sub weapon...): skip
		elseif to_num(was) and to_num(is) then
			local d = to_num(is) - to_num(was)
			if math.abs(d) > 0.0001 then changes[#changes + 1] = string.format('%-9s %s -> %s  (%s)', k, tostring(was), tostring(is), fmt(d)) end
		elseif tostring(was) ~= tostring(is) then
			changes[#changes + 1] = string.format('%-9s %s -> %s', k, tostring(was), tostring(is))
		end
	end
	say('Now vs "' .. name .. '" (' .. tostring(snap.job) .. ', ' .. tostring(snap.time) .. '):')
	if #changes == 0 then say('  no differences.') end
	for _, line in ipairs(changes) do windower.add_to_chat(207, '  ' .. line) end
end

local function snaps_command()
	local snaps = snaps_load()
	local names = {}
	for k in pairs(snaps) do names[#names + 1] = k end
	table.sort(names)
	if #names == 0 then say('No snapshots yet: //ig snap <name>.') return end
	say('Snapshots:')
	for _, k in ipairs(names) do windower.add_to_chat(207, '  ' .. k .. '  (' .. tostring(snaps[k].job) .. ', ' .. tostring(snaps[k].time) .. ')') end
end

-------------------------------------------------------------------------------------------------------------
-- commands (called from InfoGear.lua; returns true when handled)
-------------------------------------------------------------------------------------------------------------
function extras_command(command, args)
	if command == 'hover' then
		settings.player.hover = settings.player.hover == false
		if settings.player.hover == false then hide_tip() end
		settings:save('all')
		say('Hover breakdown ' .. (settings.player.hover == false and 'off' or 'on') .. '.')
	elseif command == 'jobcards' then
		settings.player.job_cards = not job_cards_on()
		if job_cards_on() then preset_job = nil end	-- picks up the current job on the next update
		settings:save('all')
		say('Cards per job ' .. (job_cards_on() and 'on: each main job keeps its own cards.' or 'off: the same cards on every job.'))
	elseif command == 'food' then
		local arg = table.concat(args, ' ')
		if arg == '' then
			if food then say('Food: ' .. food.name .. ' (' .. stats_text(food.stats) .. ')')
			else say('No food counted. //ig food <name> sets it by hand.') end
		elseif arg:lower() == 'off' or arg:lower() == 'none' then
			clear_food()
			say('Food cleared.')
		else
			local want = arg:lower()
			local found = nil
			for id, item in pairs(res.items) do
				if item.en and (item.en:lower() == want or (item.enl and item.enl:lower() == want)) and food_stats(id) then found = id break end
			end
			if found and set_food(found) then
				food_set_at = os.time() + 3600	-- set by hand: kept while the Food effect is on (or for an hour)
			else
				say('No food called "' .. arg .. '" with stats InfoGear can read.')
			end
		end
	elseif command == 'sanction' or command == 'sigil' then
		local pick = args[1] and tostring(args[1]):lower()
		if pick == 'regen' or pick == 'refresh' or pick == 'food' then
			settings.player[command] = pick
		elseif pick == 'none' or pick == 'off' then
			settings.player[command] = ''
		else
			say('Use //ig ' .. command .. ' regen|refresh|food (now: ' .. tostring(settings.player[command] or 'not set') .. ').')
			return true
		end
		settings:save('all')
		say(command:gsub('^%l', string.upper) .. ' bonus: ' .. (settings.player[command] ~= '' and settings.player[command] or 'none') .. '.')
	elseif command == 'snap' then
		snap_command(args)
	elseif command == 'diff' then
		diff_command(args)
	elseif command == 'snaps' then
		snaps_command()
	else
		return false
	end
	return true
end
