local Graphics = require"src/graphics"
local Utils = require"src/gui/utils"

local Field = require"src/gui/elements/field"
local Viewport = require"src/gui/elements/viewport"
local Timeline = require"src/gui/elements/timeline"
local Scrollbars = require"src/gui/elements/scrollbars"
local Dictionary = require"src/gui/elements/dictionary"
local Transport = require"src/gui/elements/transport"

local BLINKER_SPEED <const> = 1 * DT
local PANEL_HEIGHT <const> = 100
local ANIMATIONS_PANEL_WIDTH <const> = 100
local PROPERTIES_WIDTH <const> = 160
local TIMELINE_HEIGHT <const> = 29
local TRANSPORT_HEIGHT <const> = 17
local TRANSPORT_WIDTH <const> = 12 * 5 + 5

local blinker = {t = 0}

local function draw_dictionary(self)
	Utils.draw_panel(self)
	line(2, self.height - 11, self.width - 11, self.height - 11, 33)
end

local function draw_add_button(self) spr(2) end
local function draw_remove_button(self) spr(3) end
local function draw_swap_button(self) spr(27) end

---@param editor EditorState
local function initialize(editor, gfx_cache)
	-- This one's 269 because the scanlines don't care about window size.
	Graphics.set_scanline_palette(1, 11, 269 - PANEL_HEIGHT)
	
	local gui = create_gui{
		update = function()
			blinker.t = (blinker.t + BLINKER_SPEED) % 1
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
		draw = Utils.border,
	}
	
	local animation_list = animations_panel:attach{
		x = 2, y = 2,
		width = animations_panel.width - 4, height = animations_panel.height - 16,
	}
	
	local animation_list_container = animation_list:attach{
		x = 0, y = 0,
		width = animation_list.width - 9, height = animation_list.height,
		populate = Utils.populate,
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
				blinker = blinker,
				
				get = function(self) return self.item end,
				set = function(self, value)
					editor:rename_animation(value)
					self.item = value
				end,
				release = function(self, ctx)
					if editor.current_anim_key == self.item then
						Field.release(self, ctx)
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
	
	---@diagnostic disable-next-line undefined-field
	animation_list_container:populate()
	
	local add_animation_button = animations_panel:attach{
		x = animations_panel.width - 10, y = animations_panel.height - 10,
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
			Utils.draw_panel(self)
			spr(24, self.width * 0.5 - 32, 4)
		end,
	}
	
	local timeline = Timeline.attach(gui, editor, {
		x = 0,
		y = ScreenSize.y - TIMELINE_HEIGHT,
		width = ScreenSize.x,
		height = TIMELINE_HEIGHT,
		draw = Utils.draw_panel,
	})
	
	local transport = Transport.attach(gui, editor, {
		x = 0, y = timeline.y - TRANSPORT_HEIGHT,
		width = TRANSPORT_WIDTH, height = TRANSPORT_HEIGHT,
		draw = Utils.draw_panel,
	})
	
	local show_pivot_button = gui:attach{
		x = ScreenSize.x - PROPERTIES_WIDTH * 2 - 11,
		y = viewport.height,
		width = 11, height = 11,
		draw = function(self)
			Utils.draw_panel(self)
			
			local state = editor.show_pivot_state
			local sprite
			if state == 0 then
				sprite = 29
			elseif state == 1 then
				sprite = 30
			elseif state == 2 then
				sprite = 31
			end
			
			spr(sprite, 2, 2)
		end,
		click = function(self)
			editor.show_pivot_state = (editor.show_pivot_state + 1) % 3
		end,
	}
	
	local properties = Dictionary.attach(gui, {
		x = ScreenSize.x - PROPERTIES_WIDTH,
		y = viewport.height,
		width = PROPERTIES_WIDTH,
		height = panel.height,
		label = "Properties",
		blinker = blinker,
		
		draw = draw_dictionary,
		draw_add_button = draw_add_button,
		draw_remove_button = draw_remove_button,
		draw_swap_button = draw_swap_button,
		
		get_dictionary = function() return editor:get_property_strings() end,
		set_key = function(key, value) editor:rename_property(key, value) end,
		set_value = function(key, value) editor:set_property_by_string(key, value) end,
		get_removable = function(key) return key != "duration" end,
		get_reorderable = function(i)
			local order = editor.property_orders[editor.current_anim_key]
			return i <= #order.keys and order.keys[i] != "duration"
		end,
		create = function() return editor:create_property() end,
		remove = function(key) editor:remove_property(key) end,
		reorder = function(key, dir) editor:reorder_property(key, dir) end,
		
		factory = Dictionary.factory,
	})
	
	local events = Dictionary.attach(gui, {
		x = ScreenSize.x - PROPERTIES_WIDTH * 2,
		y = viewport.height,
		width = PROPERTIES_WIDTH,
		height = panel.height,
		label = "Events",
		blinker = blinker,
		
		draw = draw_dictionary,
		draw_add_button = draw_add_button,
		draw_remove_button = draw_remove_button,
		
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
			---@diagnostic disable-next-line undefined-field
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
