local Viewport = require"src/viewport"
local Timeline = require"src/timeline"
local Graphics = require"src/graphics"

local Field = require"src/gui_elements/field"
local Scrollbars = require"src/gui_elements/scrollbars"

local BLINKER_SPEED <const> = 1 * DT
local PANEL_HEIGHT <const> = 100
local ANIMATIONS_PANEL_WIDTH <const> = 100
local PROPERTIES_WIDTH <const> = 160
local TIMELINE_HEIGHT <const> = 29
local TRANSPORT_HEIGHT <const> = 17
local TRANSPORT_WIDTH <const> = 12 * 5 + 5

local blinker = 0

--- Draws a beveled panel.
local function draw_panel(self)
	local col = self.col or 34
	local high = self.high or 35
	local shade = self.shadow or 33
	
	rectfill(0, 0, self.width, self.height, col)
	line(0, 0, self.width - 1, 0, high)
	line(0, 0, 0, self.height - 1, high)
	line(0, self.height - 1, self.width - 1, self.height - 1, shade)
	line(self.width - 1, 0, self.width - 1, self.height - 1, shade)
end

--- Draws a rectangle across the whole element
local function fill(self)
	local col = self.col or 34
	rectfill(0, 0, self.width - 1, self.height - 1, col)
end

local function border(self)
	local col = self.col or 34
	rect(0, 0, self.width - 1, self.height - 1, col)
end

local function populate(self)
	assert(self.get, "populate() requires a get() function")
	assert(self.factory, "populate() requires a factory() function")
	
	self.items = self.items or {}
	for i = #self.items, 1, -1 do
		self:detach(self.items[i])
		deli(self.items, i)
	end
	
	local items = self:get()
	
	for i, item in ipairs(items) do
		local value = self:factory(i, item)
		assert(value, "factory must return a value")
		self.items[i] = value
	end
	
	if self.height_equation then
		self.height = self:height_equation(#items)
	end
	if self.width_equation then
		self.width = self:width_equation(#items)
	end
end

local function attach_dictionary(self, el)
	el = self:attach(el)
	
	el.selected_property = 1
	
	el.list = el:attach{
		x = 1, y = 1,
		width = el.width - 2, height = el.height - 13,
	}
	
	el.container = el.list:attach{
		x = 0,
		y = 0,
		width = el.list.width,
		height = el.list.height,
		
		populate = populate,
		height_equation = function(_, len) return len * 10 end,
		
		get = el.get_dictionary,
		set_key = el.set_key,
		set_value = el.set_value,
		get_removable = el.get_removable,
		remove = el.remove,
		
		factory = function(self, i, item)
			local key = item.key
			
			local row = self:attach{
				x = 0, y = (i - 1) * 10,
				width = self.width - 9, height = 10,
			}
			
			local field_width = (row.width - 8) * 0.5
			
			Field.attach(row, {
				x = 0,
				y = 0,
				width = field_width,
				height = 10,
				fill_col = 0,
				text_col = 7,
				fill_col_focused = 19,
				text_col_focused = 7,
				get = function() return key end,
				set = function(_, value) self.set_key(key, value) end,
			})
			
			Field.attach(row, {
				x = field_width,
				y = 0,
				width = field_width,
				height = 10,
				fill_col = 0,
				text_col = 7,
				fill_col_focused = 19,
				text_col_focused = 7,
				get = function() return item.value end,
				set = function(_, value) self.set_value(key, value) end,
			})
			
			if self.get_removable and self.get_removable(key) then
				row:attach{
					x = row.width - 7, y = 2,
					width = 7, height = 7,
					cursor = "pointer",
					draw = function(self) spr(3) end,
					click = function() self.remove(key) end,
				}
			end
			
			return row
		end
	}
	
	el.add_button = el:attach{
		x = el.width - 17, y = el.height - 9,
		width = 8, height = 8,
		cursor = "pointer",
		draw = function() spr(2, 0, 0) end,
		click = function() el.create() end,
	}
	
	el:attach{
		x = 2, y = el.height - 9,
		width = el.add_button.x - 3, height = 8,
		label = el.label,
		col = el.col,
		draw = function(self) print(self.label, 0, 0, 36) end,
	}
	
	function el:draw()
		draw_panel(self)
		line(2, el.height - 11, self.width - 11, el.height - 11, 33)
	end
	
	Scrollbars.attach(el.list)
	el.container:populate()
	
	return el
end

---@param editor EditorState
local function initialize(editor, gfx_cache)
	-- This one's 269 because the scanlines don't care about window size.
	Graphics.set_scanline_palette(1, 11, 269 - PANEL_HEIGHT)
	
	local gui = create_gui{
		update = function()
			blinker = (blinker + BLINKER_SPEED) % 1
		end
	}
	
	local viewport = Viewport.attach_viewport(gui, editor, gfx_cache, {
		x = 0,
		y = 0,
		width = ScreenSize.x - ANIMATIONS_PANEL_WIDTH,
		height = ScreenSize.y - PANEL_HEIGHT
	})
	
	local animations_panel = gui:attach{
		x = viewport.width, y = 0,
		width = ANIMATIONS_PANEL_WIDTH, height = viewport.height,
		col = Lightest,
		draw = border,
	}
	
	local animation_list = animations_panel:attach{
		x = 2, y = 2,
		width = animations_panel.width - 4, height = animations_panel.height - 16,
	}
	
	local animation_list_container = animation_list:attach{
		x = 0, y = 0,
		width = animation_list.width - 9, height = animation_list.height,
		populate = populate,
		height_equation = function(_, len) return len * 12 end,
		get = function() return editor:get_animation_keys() end,
		factory = function(self, i, item)
			local row = self:attach{
				x = 0, y = (i - 1) * 12,
				width = self.width, height = 12,
				draw = function(self)
					if editor.current_anim_key == item then
						rect(0, 0, self.width - 1, self.height - 1, Lightest)
					end
				end,
			}
			
			Field.attach(row, {
				x = 1,
				y = 1,
				width = row.width - 11,
				height = row.height - 2,
				item = item,
				fill_col = Darkest,
				text_col = Lightest,
				fill_col_focused = Lightest,
				text_col_focused = Darkest,
				
				get = function(self) return self.item end,
				set = function(self, value)
					editor:rename_animation(value)
					self.item = value
				end,
				click = function(self)
					if editor.current_anim_key == self.item then
						Field.click(self)
					else
						editor:set_animation(self.item)
					end
				end,
			})
			
			row:attach{
				x = row.width - 9, y = 2,
				width = 7, height = 7,
				cursor = "pointer",
				draw = function(self)
					pal(7, Lightest)
					pal(1, Darkest)
					spr(11, 0, 0)
					pal(7, 7)
					pal(1, 1)
				end,
				click = function(self) editor:remove_animation(item) end,
			}
			
			return row
		end
	}
	
	Scrollbars.attach(animation_list, {
		fgcol = Darkest,
		bgcol = Lightest,
	})
	
	animation_list_container:populate()
	
	local add_animation_button = animations_panel:attach{
		x = 2, y = animations_panel.height - 9,
		width = 8, height = 8,
		col = Lightest,
		cursor = "pointer",
		draw = function(self)
			pal(7, Lightest)
			pal(1, Darkest)
			spr(10, 0, 0)
			pal(7, 7)
			pal(1, 1)
		end,
		click = function(_) editor:create_animation() end,
	}
	
	local panel = gui:attach{
		x = 0, y = viewport.height,
		width = ScreenSize.x - PROPERTIES_WIDTH * 2, height = PANEL_HEIGHT - TIMELINE_HEIGHT,
		draw = function(self)
			draw_panel(self)
			spr(24, self.width * 0.5 - 32, 4)
		end,
	}
	
	local timeline = Timeline.attach(gui, editor, {
		x = 0,
		y = ScreenSize.y - TIMELINE_HEIGHT,
		width = ScreenSize.x,
		height = TIMELINE_HEIGHT,
		draw = draw_panel,
	})
	
	local transport = gui:attach{
		x = 0, y = timeline.y - TRANSPORT_HEIGHT,
		width = TRANSPORT_WIDTH, height = TRANSPORT_HEIGHT,
		draw = draw_panel,
	}
	
	local first_frame_button = transport:attach{
		x = 3, y = 3,
		width = 11, height = 11,
		cursor = "pointer",
		draw = function(self)
			draw_panel(self)
			spr(14, 2, 2)
		end,
		click = function(self)
			editor:first_frame()
		end,
	}
	
	local prev_frame_button = transport:attach{
		x = first_frame_button.x + first_frame_button.width + 1, y = 3,
		width = 11, height = 11,
		cursor = "pointer",
		draw = function(self)
			draw_panel(self)
			spr(22, 2, 2)
		end,
		click = function(self)
			editor:previous_frame()
		end,
	}
	
	local play_button = transport:attach{
		x = prev_frame_button.x + prev_frame_button.width + 1, y = 3,
		width = 11, height = 11,
		cursor = "pointer",
		draw = function(self)
			draw_panel(self)
			local sprite = editor.playing and 7 or 6
			spr(sprite, 2, 2)
		end,
		click = function(self)
			editor:set_playing(not editor.playing)
		end,
	}
	
	local next_frame_button = transport:attach{
		x = play_button.x + play_button.width + 1, y = 3,
		width = 11, height = 11,
		cursor = "pointer",
		draw = function(self)
			draw_panel(self)
			spr(23, 2, 2)
		end,
		click = function(self)
			editor:next_frame()
		end,
	}
	
	local last_frame_button = transport:attach{
		x = next_frame_button.x + next_frame_button.width + 1, y = 3,
		width = 11, height = 11,
		cursor = "pointer",
		draw = function(self)
			draw_panel(self)
			spr(15, 2, 2)
		end,
		click = function(self)
			editor:last_frame()
		end,
	}
	
	local properties = attach_dictionary(gui, {
		x = ScreenSize.x - PROPERTIES_WIDTH,
		y = viewport.height,
		width = PROPERTIES_WIDTH,
		height = panel.height,
		label = "Properties",
		get_dictionary = function() return editor:get_property_strings() end,
		set_key = function(key, value) editor:rename_property(key, value) end,
		set_value = function(key, value) editor:set_property_by_string(key, value) end,
		get_removable = function(key) return key ~= "duration" end,
		create = function() return editor:create_property() end,
		remove = function(key) editor:remove_property(key) end,
	})
	
	local events = attach_dictionary(gui, {
		x = ScreenSize.x - PROPERTIES_WIDTH * 2,
		y = viewport.height,
		width = PROPERTIES_WIDTH,
		height = panel.height,
		label = "Events",
		get_dictionary = function() return editor:get_event_strings() end,
		set_key = function(key, value) editor:rename_event(key, value) end,
		set_value = function(key, value) editor:set_event_by_string(key, value) end,
		get_removable = function() return true end,
		create = function() return editor:create_event() end,
		remove = function(key) editor:remove_event(key) end,
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
