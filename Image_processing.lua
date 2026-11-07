local dragged

math.randomseed(os.clock())

imageColors = L{'red','blue','green','dark-blue','grey','light-green','orange','pink','purple','yellow'}

--[[ui scaling shrinks display 
	x_res = 1920
	y_res = 1080
	ui_x_res = 1476
	ui_y_res = 830
	settings = ui scale 1.3
	ui_x_res = x_res / ui scale 
]]--
-- image / icon Block Class
ImageBlock = {
	x = 0,
	y = 0,
	width = 228,
	height = 42,
	alpha = 255,
	red = 255,
	green = 255,
	blue = 255,
	visible = true,
	draggable = false,
	fit = true,

	New = function(order, image_type, image_color, text1, text2)
		local o = {}
		for k, v in pairs(ImageBlock) do
			o[k] = v
		end
		local order_exists = false
		if table.length(sections) > 0 then
			if sections[image_type] and image_type == 'background' then
				return error('can only have 1 background!')
			elseif image_type == 'background' then 
				order = 0 
			end
			if image_type == 'block' and table.length(sections.block) > 0 then
				for k, v in pairs(sections.block)  do
					if sections[image_type][k] and sections[image_type][k].order == order then
						order_exists = true
					end
				end
				if order_exists == false then
					o.order = order
				else
					return error('order magnitude ' .. order .. ' is already assigned!')
				end
			elseif image_type == 'block' and table.length(sections.block) == 0 then
				o.order = order
			end
		end
		
		if image_type == 'background' then
			o.width = 228
			o.height = 42
			o.image_path = windower.addon_path..'textures/cards/panel.png'	-- the dark panel behind the cards
			o.dragable = true
			o.fit = false
			o.alpha = 255
			o.red = 255
			o.green = 255
			o.blue = 255
			o.type = image_type
			o.color = image_color
			o.name = (_addon and _addon.name or 'image') .. '_gensym_' .. tostring(t):sub(8) .. '_%.8x':format(16^8 * math.random()):sub(3)
			o.x = settings.display.pos.x
			o.y = settings.display.pos.y
		elseif image_type == 'block' then
			if imageColors:contains(image_color) then
				o.width = 57
				o.height = 42
				o.type = image_type
				o.color = image_color
				o.image_path = windower.addon_path..'textures/cards/card.png'
				o.fit = false
				o.name = (_addon and _addon.name or 'image') .. '_gensym_' .. tostring(t):sub(8) .. '_%.8x':format(16^8 * math.random()):sub(3)
				o.x, o.y = get_position(o)
				o.text = {}
				
	
				o.text[1] = {name = 'text1'..o.name, text = text1, offset_x = 3 , offset_y = 3}
				
				windower.text.create(o.text[1].name)
				windower.text.set_text(o.text[1].name, o.text[1].text)
				--windower.text.set_color(o.text[1].name, 255, 0, 0, 0)
				windower.text.set_color(o.text[1].name, 255, 150,150,235)
				windower.text.set_font_size(o.text[1].name, 9)
				windower.text.set_visibility(o.text[1].name, true)
				windower.text.set_font(o.text[1].name,'Tahoma') --'Verdana'
				windower.text.set_stroke_width(o.text[1].name, 0)
				windower.text.set_stroke_color(o.text[1].name, 255, 0, 0, 0)
				--windower.text.set_stroke_color(o.text[1].name, 255, 247,243,195)
				windower.text.set_location(o.text[1].name, o.text[1].offset_x + o.x, o.text[1].offset_y + o.y)
				windower.text.set_bold(o.text[1].name, true)
				
				--print(windower.text.get_extents(o.text[1].name))
				
				o.text[2] = {name = 'text2'..o.name, text = text2, offset_x = 3 , offset_y = 20}
				
				windower.text.create(o.text[2].name)
				windower.text.set_text(o.text[2].name, o.text[2].text)
				windower.text.set_bold(o.text[2].name, false)
				windower.text.set_color(o.text[2].name, 255, 255, 255, 255)
				windower.text.set_font_size(o.text[2].name, 12)
				windower.text.set_visibility(o.text[2].name, true)
				windower.text.set_font(o.text[2].name,'Tahoma') --'Verdana'
				windower.text.set_stroke_width(o.text[2].name, 0)
				windower.text.set_stroke_color(o.text[2].name, 255, 0, 0, 0)
				windower.text.set_location(o.text[2].name, o.text[2].offset_x + o.x, o.text[2].offset_y + o.y)
				
			else
				return error('Wrong color type')
			end
		else
			return error('Wrong image type!')
		end

		windower.prim.create(o.name)
		windower.prim.set_color(o.name, o.alpha, o.red, o.green, o.blue)
		windower.prim.set_texture(o.name, o.image_path)
		windower.prim.set_fit_to_texture(o.name, o.fit)
		windower.prim.set_size(o.name, o.width, o.height)
		windower.prim.set_visibility(o.name, o.visible)
		windower.prim.set_position(o.name, o.x, o.y)
		
		return o
	end,
	
	-- Makes the primitive visible
	show = function(self)
		windower.prim.set_visibility(self.name, true)
		self.visible = true
	end,

	-- Makes the primitive invisible
	hide = function(self)
		windower.prim.set_visibility(self.name, false)
		self.visible = false
	end,
	
	-- Returns whether or not the image object is visible
	visible = function(self, visible)
		if visible == nil then
			return self.visible
		end
		windower.prim.set_visibility(self.name, visible)
	end,
	
	position = function(self, new_x, new_y)
		if new_x == nil then
			return self.x, self.y
		end
		self.x = new_x
		self.y = new_y
		windower.prim.set_position(self.name, new_x, new_y)
		if self.type == 'block' then
			windower.text.set_location(self.text[1].name, new_x + self.text[1].offset_x , new_y + self.text[1].offset_y)
			windower.text.set_location(self.text[2].name, new_x + self.text[2].offset_x , new_y + self.text[2].offset_y)
		end
	end,
	
	position_x = function(self, new_x)
		if new_x == nil then
			return self.x
		end
		self:position(new_x, self.y)
		if self.type == 'block' then
			windower.text.set_location(self.text[1].name, new_x + self.text[1].offset_x , self.y + self.text[1].offset_y)
			windower.text.set_location(self.text[2].name, new_x + self.text[2].offset_x , self.y + self.text[2].offset_y)
		end
	end,
	
	position_y = function(self, new_y)
		if new_y == nil then
			return self.y
		end
		self:position(self.x, new_y)
		if self.type == 'block' then
			windower.text.set_location(self.text[1].name, self.x + self.text[1].offset_x , new_y + self.text[1].offset_y)
			windower.text.set_location(self.text[2].name, self.x + self.text[2].offset_x , new_y + self.text[2].offset_y)
		end
	end,
	
	image_size = function(self, width, height)
		if width == nil then
			return self.width, self.height
		end

		windower.prim.set_size(self.name, width, height)
		self.width = width
		self.height = height
	end,
	
	image_width = function(self, width)
		if width == nil then
			return self.width
		end

		self:size(width, self.height)
	end,
	
	image_height = function(self, height)
		if height == nil then
			return self.height
		end

		self:size(self.width, height)
	end,
	
	get_extents = function(self)
		
		local ext_x = self.x + self.width
		local ext_y = self.y + self.height

		return ext_x, ext_y
	end,
	
	hover = function(self, mouse_x, mouse_y)
		if not self:visible() then
			return false
		end
		
		local x_bool = false
		local y_bool = false
		local pos_x, pos_y = self:position()
		local off_x, off_y = self:get_extents()
		
		if mouse_x >= pos_x and mouse_x <= (pos_x + self.width) then
			x_bool = true
			--log('x hit ' .. tostring(x_bool))
		end
		if mouse_y > pos_y and mouse_y < (pos_y + self.height) then
			y_bool = true
			--log('y hit ' .. tostring(y_bool))
		end
		if x_bool == true and y_bool == true then
			return true
		else
			return false
		end
		
	end,
	
	draggable = function(self, drag)
		if drag == nil then
			return self.draggable
		end

		self.draggable = drag
	end,
	
	image_color = function(self, red, green, blue)
		if red == nil then
			return self.red, self.green, self.blue
		end

		windower.prim.set_color(self.name, self.alpha, red, green, blue)
		self.red = red
		self.green = green
		self.blue = blue
	end,
	
	image_alpha = function(self, alpha)
		if alpha == nil then
			return self.alpha
		end

		windower.prim.set_color(self.name, alpha, self.red, self.green, self.blue)
		self.alpha = alpha
	end,
	
	pos_diff = function (self, t)
		local self_x, self_y = self:position()
		local bg_x, bg_y = t:position()
		
		return self_x - bg_x , self_y - bg_y
	end,
	
	delete = function(self)
		windower.prim.delete(self.name)
		for k, v in pairs(sections) do
			if k ~= 'block' then
				if v.name == self.name then
					sections[k] = nil
					check_positions()
				end
			else
				for i, j in pairs(v) do
					if j.name == self.name then	
						--notice('Delete '..k..' of color '..j.color.. '  '..j.name)
						windower.text.delete(self.text[1].name)
						windower.text.delete(self.text[2].name)
						sections[k][i] = nil
						check_positions()
					end
				end
			end
		end
	end,
	
}

--ImageBlock.mt.__index = ImageBlock
-- ImageBlock.mt.__newindex = function(self,k,v)
	-- error('cannot change '.. k.. ' to ' .. v.. ' in table ' ..tostring(self))
-- end

-- Handle drag and drop
windower.register_event('mouse', function(type, x, y, delta, blocked)
    if blocked then
        return
    end

    -- Mouse drag
    if type == 0 then
        if dragged then
			update_all(x - dragged.x, y - dragged.y, dragged.image )
			centre_all_text()
            dragged.image:position(x - dragged.x, y - dragged.y)
            return true
        end

    -- Mouse left click
    elseif type == 1 then
		if sections.background.draggable and sections.background:hover(x, y) then
			local pos_x, pos_y =sections.background:position()
			dragged = {image = sections.background, x = x - pos_x, y = y - pos_y}
			return true
		end
    -- Mouse left release
    elseif type == 2 then
        if dragged then
            dragged = nil
			settings.display.pos.x = sections.background:position_x()
			settings.display.pos.y = sections.background:position_y()
			settings:save('all')
            return true
        end
    end

    return false
end)

-------------------------------------------------------------------------------------------------------------
-- Layout: where the cards go. The rectangles come from Layouts.lua (layout_plan); this part only applies them.
-- current_plan is kept so dragging can move everything without recalculating.
-------------------------------------------------------------------------------------------------------------
local current_plan = nil
alert_color = {255, 0, 0}	-- colour of values over their cap (Display.set_value); set from the plan

local function round(v) return math.floor(v + 0.5) end

-- Puts every card at its place in current_plan, with the panel's top-left corner at (x, y).
local function position_all(x, y)
	local plan = current_plan
	if not plan then return end
	for idx, b in pairs(sections.block) do
		local r = plan.blocks[idx]
		if r then b:position(x + r.x, y + r.y) end
	end
end

-- Recalculates the layout. Called whenever a card is created or deleted, and when the scale changes.
function check_positions()
	if not sections.background or not settings then return end
	local present = {}
	for idx in pairs(sections.block) do present[#present + 1] = idx end
	table.sort(present)
	
	local plan = layout_plan(present)
	current_plan = plan
	local s = plan.s
	
	for idx, b in pairs(sections.block) do
		local r = plan.blocks[idx]
		if r then
			if b.width ~= r.w or b.height ~= r.h or not b.sized then
				windower.prim.set_fit_to_texture(b.name, false)
				windower.prim.set_size(b.name, r.w, r.h)
				b.width, b.height, b.sized = r.w, r.h, true
			end
			local cap, val = round(plan.caption * s), round(plan.value * s)
			if b.font_caption ~= cap then windower.text.set_font_size(b.text[1].name, cap); b.font_caption = cap end
			if b.font_value ~= val then windower.text.set_font_size(b.text[2].name, val); b.font_value = val end
			-- plain coloured caption, bold number
			if not b.styled then
				local cc = layout_card_caption_color(idx)
				windower.text.set_color(b.text[1].name, 255, cc[1], cc[2], cc[3])
				windower.text.set_bold(b.text[1].name, false)
				windower.text.set_bold(b.text[2].name, true)
				b.styled = true
			end
		end
	end
	
	alert_color = plan.alert or {255, 0, 0}
	local bg = sections.background
	windower.prim.set_fit_to_texture(bg.name, false)
	bg:image_size(math.max(plan.w, 1), math.max(plan.h, 1))
	position_all(bg:position_x(), bg:position_y())
end

-- New cards start at the panel's corner; check_positions() (called right after they are stored) moves them.
function get_position(this_image)
	if sections.background then
		return sections.background:position_x(), sections.background:position_y()
	end
	return 0, 0
end

-- Used while dragging: moves everything to follow the background.
function update_all(x, y, background)
	position_all(x, y)
end

-- Text placement inside each card. Runs every couple of frames because the text width is only known once
-- Windower has drawn it.
function centre_all_text()
	for k, b in pairs(sections.block) do
		local w1 = windower.text.get_extents(b.text[1].name)
		local w2 = windower.text.get_extents(b.text[2].name)
		local bw, bh = b.width or 54, b.height or 38
		local cy = current_plan and current_plan.caption_y or 0.10
		local vy = current_plan and current_plan.value_y or 0.40
		windower.text.set_location(b.text[1].name, b.x + round(bw / 2 - w1 / 2), b.y + round(bh * cy))
		windower.text.set_location(b.text[2].name, b.x + round(bw / 2 - w2 / 2), b.y + round(bh * vy))
	end
end
