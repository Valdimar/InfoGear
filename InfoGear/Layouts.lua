--[[
	Layouts.lua

	Where the widgets go on screen: flat dark cards, 4 across, each a small coloured caption over a big bold number,
	on a plain dark panel. Drawn only with textures/cards/card.png and textures/cards/panel.png.

	layout_plan() gets the list of blocks that currently exist and returns a "plan": a rectangle for every block,
	relative to the panel's top-left corner. Image_processing.lua applies it. Which widgets exist is still decided
	by the //ig show ... toggles. //ig scale <0.5-2> resizes everything.
]]

local floor = math.floor
local function R(v) return floor(v + 0.5) end

-------------------------------------------------------------------------------------------------------------
-- settings you may want to change
-------------------------------------------------------------------------------------------------------------
card_columns = 4	-- the default; each character can pick 4, 5 or 6 with //ig columns (settings: display.columns)

-- (v1.9) Cards are placed by group: a group that fits in a row is never split over two rows, a bigger group wraps
-- from the start of a new row, and small groups fill gaps left in earlier rows. So the panel stays grouped at
-- 4, 5 or 6 columns. Order = which group comes first (block numbers from Display.lua). The extra cards (31-58) are
-- added from extra_cards below, UGS always goes in the last row, and blocks in no group go at the end.
card_groups = {
	{key = 'haste',  blocks = {1, 2, 3, 4}},			-- Gear.H, Magic.H, JA.H, Total.H
	{key = 'dt',     blocks = {5, 6, 7, 8}},			-- DT, PDT, MDT, BDT
	{key = 'tp',     blocks = {9, 10, 11, 28}},			-- TP/h, to WS, aft WS, STP
	{key = 'accatt', blocks = {12, 13, 14, 15}},		-- Acc.1, Acc.2, Att.1, Att.2
	{key = 'ranged', blocks = {16, 17, 18, 19, 21}},	-- R.TP/h, R.to WS, R.aft WS, R.Acc, R.Att
	{key = 'evadef', blocks = {22, 23}},				-- Eva., Def.
	{key = 'dw',     blocks = {24, 25}},				-- DW, Needed
	{key = 'ma',     blocks = {26, 27}},				-- MA, Needed
	{key = 'speed',  blocks = {30}},					-- Speed
}
card_last = 29	-- UGS: last row if there's room, else the first gap

-- (v1.7) Extra stat cards. Each is turned on with //ig show <key> or a whole group with //ig show <group>; all
-- start off. Values and caps are in Display.lua (extra_card_values).
extra_card_groups = {
	{key = 'melee',  title = 'multi-attack, crit, Subtle Blow, WSD, PDL', color = {245, 170, 90}},
	{key = 'ranged', title = 'Snapshot, Rapid Shot',                        color = {130, 215, 150}},
	{key = 'magic',  title = 'Fast Cast, magic acc / attack, burst, Cure',  color = {200, 150, 255}},
	{key = 'tank',   title = 'magic evasion / defence, Phalanx, Enmity',    color = {226, 220, 196}},
	{key = 'misc',   title = 'HP, MP, Regen, Refresh, Regain, Treasure Hunter', color = {170, 190, 210}},
	{key = 'pet',    title = "your pet's damage taken (physical / magic) and Regen from your gear", color = {150, 220, 180}},
}
extra_cards = {
	{idx = 38, key = 'da',      group = 'melee',  label = 'DA'},
	{idx = 39, key = 'ta',      group = 'melee',  label = 'TA'},
	{idx = 40, key = 'qa',      group = 'melee',  label = 'QA'},
	{idx = 41, key = 'crit',    group = 'melee',  label = 'Crit'},
	{idx = 42, key = 'critdmg', group = 'melee',  label = 'Crit.D'},
	{idx = 43, key = 'sb',      group = 'melee',  label = 'SB'},
	{idx = 44, key = 'sb2',     group = 'melee',  label = 'SB II'},
	{idx = 45, key = 'wsd',     group = 'melee',  label = 'WSD'},
	{idx = 46, key = 'pdl',     group = 'melee',  label = 'PDL'},
	{idx = 47, key = 'snap',    group = 'ranged', label = 'Snap'},
	{idx = 48, key = 'rapid',   group = 'ranged', label = 'Rapid'},
	{idx = 31, key = 'fc',      group = 'magic',  label = 'F.Cast'},
	{idx = 32, key = 'macc',    group = 'magic',  label = 'M.Acc'},
	{idx = 33, key = 'mab',     group = 'magic',  label = 'MAB'},
	{idx = 34, key = 'mbb',     group = 'magic',  label = 'MBB'},
	{idx = 35, key = 'mbb2',    group = 'magic',  label = 'MBB II'},
	{idx = 36, key = 'cure',    group = 'magic',  label = 'Cure'},
	{idx = 37, key = 'cure2',   group = 'magic',  label = 'Cure II'},
	{idx = 49, key = 'meva',    group = 'tank',   label = 'M.Eva'},
	{idx = 50, key = 'mdb',     group = 'tank',   label = 'MDB'},
	{idx = 51, key = 'phalanx', group = 'tank',   label = 'Phalanx'},
	{idx = 52, key = 'enmity',  group = 'tank',   label = 'Enmity'},
	{idx = 53, key = 'hp',      group = 'misc',   label = 'HP'},
	{idx = 54, key = 'mp',      group = 'misc',   label = 'MP'},
	{idx = 55, key = 'regen',   group = 'misc',   label = 'Regen'},
	{idx = 56, key = 'refresh', group = 'misc',   label = 'Refresh'},
	{idx = 57, key = 'regain',  group = 'misc',   label = 'Regain'},
	{idx = 58, key = 'th',      group = 'misc',   label = 'TH'},
	{idx = 59, key = 'petdt',   group = 'pet',    label = 'Pet DT'},	-- (v1.12) one card for every pet type
	{idx = 60, key = 'petregen', group = 'pet',   label = 'Pet Regen'},	-- (v1.17)
}
-- settings: <cards><da>false</da>...</cards> in each character's settings file, all off to start
if defaults and defaults.player then
	defaults.player.cards = defaults.player.cards or {}
	for _, c in ipairs(extra_cards) do
		if defaults.player.cards[c.key] == nil then defaults.player.cards[c.key] = false end
	end
end

-- the extra cards become groups too, after the main ones (melee, ranged, magic, tank, misc)
for _, g in ipairs(extra_card_groups) do
	local blocks = {}
	for _, c in ipairs(extra_cards) do if c.group == g.key then blocks[#blocks + 1] = c.idx end end
	card_groups[#card_groups + 1] = {key = 'extra_' .. g.key, blocks = blocks}
end

-- caption colour (r, g, b) per block; numbers are white, or card_alert when over the cap
local haste, dt, melee = {240, 128, 114}, {176, 164, 255}, {232, 214, 110}
local ranged, def, speed, misc = {130, 215, 150}, {226, 220, 196}, {140, 190, 245}, {170, 175, 185}
card_caption_colors = {
	[1] = haste, [2] = haste, [3] = haste, [4] = haste,
	[5] = dt, [6] = dt, [7] = dt, [8] = dt,
	[9] = melee, [10] = melee, [11] = melee, [12] = melee, [13] = melee, [14] = melee, [15] = melee,
	[16] = ranged, [17] = ranged, [18] = ranged, [19] = ranged, [21] = ranged,
	[22] = def, [23] = def, [28] = def, [30] = {120, 215, 200},
	[24] = speed, [25] = speed, [26] = speed, [27] = speed,
	[29] = misc,
}
do	-- extra cards take their group's colour
	local group_color = {}
	for _, g in ipairs(extra_card_groups) do group_color[g.key] = g.color end
	for _, c in ipairs(extra_cards) do card_caption_colors[c.idx] = group_color[c.group] end
end
card_alert = {240, 110, 95}

-- sizes at scale 1: 4 cards of 54 x 38 px make a 228 px wide panel, the same width as the original display
-- (v1.14) two card sizes, //ig size normal|small (settings: display.size). Sizes in pixels and font sizes in points
-- at scale 1; caption_y / value_y = where the caption and the number start, as a fraction of the card height.
card_sizes = {
	normal = {w = 54, h = 38, gap = 2, pad = 3, caption = 7, value = 11, caption_y = 0.10, value_y = 0.40},
	small  = {w = 44, h = 30, gap = 2, pad = 3, caption = 6, value = 9,  caption_y = 0.07, value_y = 0.40},
}

function layout_current_size()
	local name = settings and settings.display and settings.display.size
	name = type(name) == 'string' and name:lower() or 'normal'
	if not card_sizes[name] then name = 'normal' end
	return name, card_sizes[name]
end

-------------------------------------------------------------------------------------------------------------
-- the layout
-------------------------------------------------------------------------------------------------------------
function layout_card_caption_color(idx)
	return card_caption_colors[idx] or misc
end

-- (v1.8) columns for this character: display.columns in the settings file, 4 to 6
function layout_current_columns()
	local c = tonumber(settings and settings.display and settings.display.columns) or card_columns
	c = math.floor(c)
	if c < 4 then c = 4 elseif c > 6 then c = 6 end
	return c
end

function layout_current_scale()
	local s = tonumber(settings and settings.display and settings.display.scale) or 1
	if s < 0.5 then s = 0.5 elseif s > 2 then s = 2 end
	return s
end

-- Rounds the edges (not position and size separately), so neighbours never overlap at any scale.
local function rect(x, y, w, h)
	local x0, y0 = R(x), R(y)
	return {x = x0, y = y0, w = R(x + w) - x0, h = R(y + h) - y0}
end

-- (v1.9) Packs the present blocks of each group into rows of `columns`. Returns a list of rows, each a list of
-- block numbers, left to right.
function layout_rows(present, columns)
	local has, used = {}, {}
	for _, idx in ipairs(present) do has[idx] = true end
	local groups = {}
	for _, g in ipairs(card_groups) do
		local list = {}
		for _, idx in ipairs(g.blocks) do
			if has[idx] and not used[idx] and idx ~= card_last then list[#list + 1] = idx; used[idx] = true end
		end
		if #list > 0 then groups[#groups + 1] = list end
	end
	local others = {}
	for _, idx in ipairs(present) do
		if not used[idx] and idx ~= card_last then others[#others + 1] = idx end
	end
	if #others > 0 then groups[#groups + 1] = others end
	
	local rows = {}
	local function first_fit(n)	-- first row with room for n more cards
		for _, row in ipairs(rows) do
			if #row + n <= columns then return row end
		end
		local row = {}
		rows[#rows + 1] = row
		return row
	end
	for _, list in ipairs(groups) do
		if #list <= columns then
			local row = first_fit(#list)
			for _, idx in ipairs(list) do row[#row + 1] = idx end
		else
			-- too big for one row: full rows from a new row, the rest starts the next row
			local row
			for i, idx in ipairs(list) do
				if (i - 1) % columns == 0 then row = {}; rows[#rows + 1] = row end
				row[#row + 1] = idx
			end
		end
	end
	if has[card_last] then	-- UGS: in the last row if there's room, else in the first gap, else a row of its own
		local last = rows[#rows]
		if not last or #last >= columns then last = first_fit(1) end
		last[#last + 1] = card_last
	end
	return rows
end

-- `present`: sorted list of existing block numbers.
function layout_plan(present, scale)
	local s = scale or layout_current_scale()
	local _, size = layout_current_size()
	local cw, ch, g, pad = size.w * s, size.h * s, size.gap * s, size.pad * s
	local columns = layout_current_columns()
	local rows = layout_rows(present, columns)
	
	local plan = {s = s, blocks = {}, alert = card_alert,
		caption = size.caption, value = size.value, caption_y = size.caption_y, value_y = size.value_y}
	local widest = 1
	for r, row in ipairs(rows) do
		if #row > widest then widest = #row end
		for c, idx in ipairs(row) do
			plan.blocks[idx] = rect(pad + (c - 1) * (cw + g), pad + (r - 1) * (ch + g), cw, ch)
		end
	end
	local nrows = math.max(1, #rows)
	plan.w = R(2 * pad + widest * cw + (widest - 1) * g)
	plan.h = R(2 * pad + nrows * ch + (nrows - 1) * g)
	return plan
end

-------------------------------------------------------------------------------------------------------------
-- //ig scale [n]
-------------------------------------------------------------------------------------------------------------
-- (v1.14) //ig size [normal|small]
function size_command(args)
	local wanted = args[1] and tostring(args[1]):lower()
	if not wanted then
		log('Card size: ' .. layout_current_size() .. '. Use //ig size normal or //ig size small.')
		return
	end
	if not card_sizes[wanted] then
		log('Card size can be normal or small.')
		return
	end
	settings.display.size = wanted
	settings:save('all')
	if check_positions then check_positions() end
	log('Card size -> ' .. wanted)
end

-- (v1.8) //ig columns [4|5|6]
function columns_command(args)
	local n = tonumber(args[1])
	if not n then
		log('Columns: ' .. layout_current_columns() .. '. Use //ig columns 4, 5 or 6.')
		return
	end
	n = math.floor(n)
	if n < 4 or n > 6 then
		log('Columns can be 4, 5 or 6.')
		return
	end
	settings.display.columns = n
	settings:save('all')
	if check_positions then check_positions() end
	log('Columns -> ' .. n)
end

function scale_command(args)
	local n = tonumber(args[1])
	if not n then
		log('Scale is ' .. layout_current_scale() .. '. Use //ig scale <0.5 - 2>, e.g. //ig scale 0.8 (1 = normal size).')
		return
	end
	if n < 0.5 then n = 0.5 elseif n > 2 then n = 2 end
	settings.display.scale = n
	settings:save('all')
	if check_positions then check_positions() end
	log('Scale -> ' .. n)
end

-------------------------------------------------------------------------------------------------------------
-- (v1.7) //ig show <card | group>, //ig cards
-------------------------------------------------------------------------------------------------------------
-- Returns true when `name` is an extra card or group (and toggles it), false otherwise.
function extra_card_toggle(name)
	settings.player.cards = settings.player.cards or {}
	local cards = settings.player.cards
	for _, c in ipairs(extra_cards) do
		if c.key == name then
			cards[c.key] = not (cards[c.key] == true)
			log('Show ' .. c.label .. ' = ' .. tostring(cards[c.key]))
			return true
		end
	end
	for _, g in ipairs(extra_card_groups) do
		if g.key == name then
			-- if any card of the group is off, turn them all on; if all are on, turn them all off
			local all_on = true
			for _, c in ipairs(extra_cards) do
				if c.group == g.key and cards[c.key] ~= true then all_on = false end
			end
			local labels = {}
			for _, c in ipairs(extra_cards) do
				if c.group == g.key then cards[c.key] = not all_on; labels[#labels + 1] = c.label end
			end
			log('Show ' .. g.key .. ' (' .. table.concat(labels, ', ') .. ') = ' .. tostring(not all_on))
			return true
		end
	end
	return false
end

function extra_cards_list()
	local cards = settings.player.cards or {}
	log('Extra cards: //ig show <name> for one, //ig show <group> for a whole group. (* = shown)')
	for _, g in ipairs(extra_card_groups) do
		local parts = {}
		for _, c in ipairs(extra_cards) do
			if c.group == g.key then parts[#parts + 1] = c.key .. (cards[c.key] == true and '*' or '') end
		end
		log(string.format('  %-6s %s', g.key, table.concat(parts, ' ')))
	end
end
