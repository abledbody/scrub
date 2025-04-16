local Viewport = require"src/viewport"
local Timeline = require"src/timeline"

local BLINKER_SPEED <const> = 1*DT
local PANEL_HEIGHT <const> = 100
local ANIMATIONS_PANEL_WIDTH <const> = 100
local PROPERTIES_WIDTH <const> = 160
local TIMELINE_HEIGHT <const> = 29
local TRANSPORT_HEIGHT <const> = 17
local TRANSPORT_WIDTH <const> = 13*4+4

local blinker = 0

--- Draws a beveled panel.
local function draw_panel(self)
	local col = self.col or 34
	local high = self.high or 35
	local shade = self.shadow or 33

	rectfill(0,0,self.width,self.height,col)
	line(0,0,self.width-1,0,high)
	line(0,0,0,self.height-1,high)
	line(0,self.height-1,self.width-1,self.height-1,shade)
	line(self.width-1,0,self.width-1,self.height-1,shade)
end

--- Draws a rectangle across the whole element
local function fill(self)
	local col = self.col or 34
	rectfill(0,0,self.width-1,self.height-1,col)
end

local function border(self)
	local col = self.col or 34
	rect(0,0,self.width-1,self.height-1,col)
end

local function field_draw(self)
	local has_keyboard_focus = self:has_keyboard_focus()
		
	local str = has_keyboard_focus and self.str or self:get()
	
	local fill_col = has_keyboard_focus and self.fill_col_focused or self.fill_col
	local text_col = has_keyboard_focus and self.text_col_focused or self.text_col

	rectfill(0,0,self.width-1,self.height-1,fill_col)

	local offset = has_keyboard_focus and self.offset or 0
	print(str,1-offset,1,text_col)
	
	if has_keyboard_focus and blinker < 0.5 then
		local x = self.curs_pos-offset
		line(x,1,x,8,text_col)
	end

	if self.label then
		clip()
		local ww = print(self.label,0,-1000)
		print(self.label,-ww,1,text_col)
	end
end

local function field_click(self)
	self:set_keyboard_focus(true)
	self.str = self:get()
	self:update_cursor(#self.str)
	readtext(true)
end

local function field_update(self)
	if not self:has_keyboard_focus() then return end

	local first = string.sub(self.str,1,self.curs)
	local last = string.sub(self.str,self.curs+1)
	while (peektext()) do
		local txt = readtext()
		self.str = first..txt..last
		self:update_cursor(self.curs+#txt)
	end

	if keyp("enter") then
		if (type(self.set) == "function") then self:set(self.str) end
		self:set_keyboard_focus(false)
	end

	if keyp("backspace") then
		self.str = string.sub(first,1,self.curs-1)..last
		self:update_cursor(self.curs-1)
	end
	if keyp("delete") then
		self.str = first..string.sub(last,2)
	end

	if keyp("left") then
		self:update_cursor(self.curs-1)
	end
	if keyp("right") then
		self:update_cursor(self.curs+1)
	end
end

local function attach_field(self,el)
	-- Draw gets set during attach. I don't know why, but to be on the safe side,
	-- we handle the other defaulted functions here too.
	local draw = el.draw or field_draw
	local click = el.click or field_click
	local update = el.update or field_update

	el = self:attach(el)
	el.offset = 0
	el.str = el:get()
	el.draw = draw
	el.click = click
	el.update = update
	el.cursor = "pointer"

	function el:update_cursor(val)
		self.curs = mid(0,val,#self.str)
		self.curs_pos = print(string.sub(self.str,1,self.curs),0,-1000)
		local max_width = print(self.str,0,-1000)

		self.offset = mid(
			0,
			self.curs_pos-mid(0,self.curs_pos-self.offset,self.width-1),
			max_width-self.width+1
		)

		blinker = 0
	end
	el:update_cursor(#el.str)

	return el
end

function attach_better_scrollbars(self,attribs)
	local container = self
	local bar_short = self.bar_short or 8
	
	local attribs = attribs or {}
	local widthwise = attribs.widthwise or false -- Eh, why not?
	
	-- pick out only attributes relevant to scrollbar (autohide)
	-- caller could adjust them after though -- to do: perhaps should just spill everything in attribs as starting values
	local scrollbar = {
		x = 0, justify = not widthwise and "right",
		y = 0, vjustify = widthwise and "bottom",
		widthwise = widthwise,
		width = widthwise and container.width or bar_short,
		height = widthwise and bar_short or container.height,
		long_rel = 1.0,
		autohide = attribs.autohide,
		bar_offset = 0,
		bar_length = 0,
		cursor = "grab",
		fgcol = attribs.fgcol or 35,
		bgcol = attribs.bgcol or 33,

		update = function(self, msg)
			local container = self.parent
			local contents  = container.child[1]
			local l0 = self.widthwise and self.width or self.height
			local l1 = self.widthwise and contents.width or contents.height
			local l2 = self.widthwise and container.width or container.height
			local bar_length = max(9, l0 / l1 * l0)\1  -- bar length; minimum 9 pixels
			local emp_l = l0 - bar_length - 1          -- empty length (-1 for 1px boundary at bottom)
			local max_offset = max(0, l1 - l2)

			self.scroll_spd = max_offset / emp_l

			local contents_offset = self.widthwise and contents.x or contents.y
			if max_offset > 0 then
				self.bar_offset = flr(-emp_l * contents_offset / max_offset)
				self.bar_length = bar_length
			else
				self.bar_offset = 0
				self.bar_length = 0
			end

			if self.autohide then
				self.hidden = l1 <= l2
			end

			-- hack: match update height same frame 
			-- otherwise /almost/ works because gets squashed by virtue of height being relative to container, but a frame behind
			-- (doesn't work in some cases! to do: nicer way to solve this?)
			-- self.squash_to_clip = container.squash_to_clip 

			-- 0.1.1e: always clamp
			contents.x = mid(0, contents.x, container.width  - contents.width)
			contents.y = mid(0, contents.y, container.height - contents.height)

		end,
		
		draw = function(self, msg)
			local bgcol = self.bgcol
			local fgcol = self.fgcol
			
			rectfill(0, 0, self.width-1, self.height-1, bgcol | (fgcol << 8)) 
			if self.bar_length > 0 then
				if self.widthwise then
					rectfill(self.bar_offset+1, 1, self.bar_offset + self.bar_length-1, self.height-2, fgcol)
				else
					rectfill(1, self.bar_offset+1, self.width-2, self.bar_offset + self.bar_length-1, fgcol)
				end
			end

			-- lil grip thing; same colour as background
			local ll = self.bar_offset + self.bar_length/2
			if self.widthwise then
				line(ll-1, 2, ll-1, self.height-3, bgcol)
				line(ll+1, 2, ll+1, self.height-3, bgcol)
				
				pset(self.bar_offset + 1, 1, bgcol)
				pset(self.bar_offset + self.bar_length-1, 1, bgcol)
				pset(self.bar_offset + 1, self.height-2, bgcol)
				pset(self.bar_offset + self.bar_length-1, self.height-2, bgcol)
			else
				line(2, ll-1, self.width-3, ll-1, bgcol)
				line(2, ll+1, self.width-3, ll+1, bgcol)

				pset(1,self.bar_offset + 1,bgcol)
				pset(self.width-2, self.bar_offset + 1, bgcol)
				pset(1,self.bar_offset + self.bar_length-1,bgcol)
				pset(self.width-2, self.bar_offset + self.bar_length-1,bgcol)
			end
			
		end,
		drag = function(self, msg)
			local content = self.parent.child[1]
			local delta = (widthwise and msg.dx or msg.dy) * self.scroll_spd
			if self.widthwise then
				content.x -= delta
				content.x = mid(0, content.x, -max(0, content.width - container.width))
			else
				content.y -= delta
				content.y = mid(0, content.y, -max(0, content.height - container.height))
			end

		end,
		click = function(self, msg)
			local content = self.parent.child[1]
			
			-- click above / below to pageup / pagedown
			local mouse_delta = self.widthwise and msg.mx or msg.my
			local sign = 0
			if (mouse_delta < self.bar_offset) then
				sign += 1
			end
			if (mouse_delta > self.bar_offset + self.bar_length) then
				sign -= 1
			end
			if self.widthwise then
				content.x += self.parent.width*sign
			else
				content.y += self.parent.height*sign
			end
		end
	}

	-- standard mousewheel support when attach scroll bar
	-- speed: 32 pixels // to do: maybe should be a system setting?
	function container:mousewheel(msg)
		local content = self.child[1]
		if not content then return end

		if (key("ctrl")) then
			content.x += msg.wheel_y * 32 
		else
			content.y += msg.wheel_y * 32 
		end

		-- clamp
		content.y = mid(0, content.y, -max(0, content.height - container.height))
		content.x = mid(0, content.x, -max(0, content.width - container.width))

		-- 0.1.1e: consume event (e.g. for nested scrollables)
		return true

		-- experimental: consume only if scrolled
		--if (old_x ~= content.x or old_y ~= content.y) return true 
		
	end

	return container:attach(scrollbar)
end

local function populate(self)
	assert(self.get,"populate() requires a get() function")
	assert(self.factory,"populate() requires a factory() function")
	
	self.items = self.items or {}
	for i=#self.items,1,-1 do
		self:detach(self.items[i])
		deli(self.items,i)
	end

	local items = self:get()

	for i,item in ipairs(items) do
		local value = self:factory(i,item)
		assert(value,"factory must return a value")
		self.items[i] = value
	end

	if self.height_equation then
		self.height = self:height_equation(#items)
	end
	if self.width_equation then
		self.width = self:width_equation(#items)
	end
end

local function attach_dictionary(self,accessors,el)
	el = self:attach(el)

	el.selected_property = 1

	el.list = el:attach{
		x = 1,y = 1,
		width = el.width-2,height = el.height-13,
	}

	el.container = el.list:attach{
		x = 0,
		y = 0,
		width = el.list.width,
		height = el.list.height,
		
		populate = populate,
		height_equation = function(_,len) return len*10 end,

		get = el.get_dictionary,
		set_key = el.set_key,
		set_value = el.set_value,
		get_removable = el.get_removable,
		remove = el.remove,

		factory = function(self,i,item)
			local key = item.key

			local row = self:attach{
				x = 0,y = (i-1)*10,
				width = self.width-9,height = 10,
			}

			local field_width = (row.width-8)*0.5

			attach_field(row,{
				x = 0,y = 0,
				width = field_width,height = 10,
				fill_col = 0,
				text_col = 7,
				fill_col_focused = 19,
				text_col_focused = 7,
				get = function() return key end,
				set = function(_,value) self.set_key(key,value) end,
			})

			attach_field(row,{
				x = field_width,y = 0,
				width = field_width,height = 10,
				fill_col = 0,
				text_col = 7,
				fill_col_focused = 19,
				text_col_focused = 7,
				get = function() return item.value end,
				set = function(_,value) self.set_value(key,value) end,
			})

			if self.get_removable and self.get_removable(key) then
				row:attach{
					x = row.width-7,y = 2,
					width = 7,height = 7,
					cursor = "pointer",
					draw = function(self) spr(3) end,
					click = function() self.remove(key) end,
				}
			end

			return row
		end
	}

	el.add_button = el:attach{
		x = el.width-17,y = el.height-9,
		width = 8,height = 8,
		cursor = "pointer",
		draw = function() spr(2,0,0) end,
		click = function() el.create() end,
	}

	el:attach{
		x = 2,y = el.height-9,
		width = el.add_button.x-3,height = 8,
		label = el.label,
		col = el.col,
		draw = function(self) print(self.label,0,0,36) end,
	}

	function el:draw()
		draw_panel(self)
		line(2,el.height-11,self.width-11,el.height-11,33)
	end

	attach_better_scrollbars(el.list)
	el.container:populate()

	return el
end

local function initialize(accessors)
	-- This one's 269 because the scanlines don't care about window size.
	set_scanline_palette(1,11,269-PANEL_HEIGHT)
	
	local gui = create_gui{
		update = function()
			blinker = (blinker+BLINKER_SPEED)%1
		end
	}

	local viewport = Viewport.attach_viewport(gui,accessors,{
		x=0,y=0,
		width = ScreenSize.x-ANIMATIONS_PANEL_WIDTH,
		height = ScreenSize.y-PANEL_HEIGHT
	})

	local animations_panel = gui:attach{
		x = viewport.width,y = 0,
		width = ANIMATIONS_PANEL_WIDTH,height = viewport.height,
		col = Lightest,
		draw = border,
	}

	local animation_list = animations_panel:attach{
		x = 2,y = 2,
		width = animations_panel.width-4,height = animations_panel.height-16,
	}

	local animation_list_container = animation_list:attach{
		x = 0,y = 0,
		width = animation_list.width-9,height = animation_list.height,
		populate = populate,
		height_equation = function(_,len) return len*12 end,
		get = accessors.get_animation_keys,
		factory = function(self,i,item)
			local row = self:attach{
				x = 0,y = (i-1)*12,
				width = self.width,height = 12,
				draw = function(self)
					if accessors.get_animation_key() == item then
						rect(0,0,self.width-1,self.height-1,Lightest)
					end
				end,
			}

			attach_field(row,{
				x = 1,y = 1,
				width = row.width-11,height = row.height-2,
				item = item,
				fill_col = Darkest,
				text_col = Lightest,
				fill_col_focused = Lightest,
				text_col_focused = Darkest,
				
				get = function(self) return self.item end,
				set = function(self,value)
					accessors.set_animation_key(value)
					self.item = value
				end,
				click = function(self)
					if accessors.get_animation_key() == self.item then
						field_click(self)
					else
						accessors.set_animation(self.item)
					end
				end,
			})

			row:attach{
				x = row.width-9,y = 2,
				width = 7,height = 7,
				cursor = "pointer",
				draw = function(self)
					pal(7,Lightest) pal(1,Darkest)
					spr(11,0,0)
					pal(7,7) pal(1,1)
				end,
				click = function(self) accessors.remove_animation(item) end,
			}

			return row
		end
	}

	attach_better_scrollbars(animation_list,{
		fgcol = Darkest,
		bgcol = Lightest,
	})

	animation_list_container:populate()

	local add_animation_button = animations_panel:attach{
		x = 2,y = animations_panel.height-9,
		width = 8,height = 8,
		col = Lightest,
		cursor = "pointer",
		draw = function(self)
			pal(7,Lightest) pal(1,Darkest)
			spr(10,0,0)
			pal(7,7) pal(1,1)
		end,
		click = function(_) accessors.create_animation() end,
	}

	local panel = gui:attach{
		x = 0,y = viewport.height,
		width = ScreenSize.x-PROPERTIES_WIDTH*2,height = PANEL_HEIGHT-TIMELINE_HEIGHT,
		draw = function(self) draw_panel(self) spr(24,self.width*0.5-32,4) end,
	}
	
	local timeline = Timeline.attach(gui,accessors,{
		x = 0,y = ScreenSize.y-TIMELINE_HEIGHT,
		width = ScreenSize.x,height = TIMELINE_HEIGHT,
		draw = draw_panel,
	})
	
	local transport = gui:attach{
		x = 0,y = timeline.y-TRANSPORT_HEIGHT,
		width = TRANSPORT_WIDTH,height = TRANSPORT_HEIGHT,
		draw = draw_panel,
	}

	local play_button = transport:attach{
		x = 3,y = 3,
		width = 11,height = 11,
		cursor = "pointer",
		draw = function(self)
			draw_panel(self)
			local sprite = accessors.get_playing() and 7 or 6
			spr(sprite,2,2)
		end,
		click = function(self)
			accessors.set_playing(not accessors.get_playing())
		end,
	}

	local properties = attach_dictionary(gui,accessors,{
		x = ScreenSize.x-PROPERTIES_WIDTH,y = viewport.height,
		width = PROPERTIES_WIDTH,height = panel.height,
		label = "Properties",
		get_dictionary = accessors.get_property_strings,
		set_key = accessors.rename_property,
		set_value = accessors.set_property_by_string,
		get_removable = function(key) return key ~= "duration" end,
		create = accessors.create_property,
		remove = accessors.remove_property,
	})

	local events = attach_dictionary(gui,accessors,{
		x = ScreenSize.x-PROPERTIES_WIDTH*2,y = viewport.height,
		width = PROPERTIES_WIDTH,height = panel.height,
		label = "Events",
		get_dictionary = accessors.get_event_strings,
		set_key = accessors.rename_event,
		set_value = accessors.set_event_by_string,
		get_removable = function() return true end,
		create = accessors.create_event,
		remove = accessors.remove_event,
	})

	return {
		gui = gui,
		on_animations_changed = function()
			animation_list_container:populate()
		end,
		on_frames_changed = function()
			timeline.container:fit()
		end,
		on_frame_change = function()
			timeline:align_buttons()
		end,
		on_properties_changed = function()
			properties.container:populate()
		end,
		on_events_changed = function()
			events.container:populate()
		end,
		on_selection_changed = function()
			timeline:align_buttons()
			properties.container:populate()
			events.container:populate()
		end,
	}
end

return {
	initialize = initialize
}