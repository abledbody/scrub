local Graphics = require"src/graphics"
local Utils = require"src/gui/utils"

local Field = require"src/gui/elements/field"
local Viewport = require"src/gui/elements/viewport"
local Timeline = require"src/gui/elements/timeline"
local Scrollbars = require"src/gui/elements/scrollbars"
local Dictionary = require"src/gui/elements/dictionary"
local Transport = require"src/gui/elements/transport"

local new_style = Utils.new_style

local BLINKER_SPEED <const> = 1 * DT
local PANEL_HEIGHT <const> = 100
local ANIMATIONS_PANEL_WIDTH <const> = 100
local PROPERTIES_WIDTH <const> = 160
local TIMELINE_HEIGHT <const> = 29
local TRANSPORT_HEIGHT <const> = 17
local TRANSPORT_WIDTH <const> = 12 * 5 + 5

local blinker = {t = 0}

local function draw_add_button(self) spr(2) end
local function draw_remove_button(self) spr(3) end
local function draw_swap_button(self) spr(27) end

---@param editor EditorState
local function initialize(editor, gfx_cache)
	-- This one's 269 because the scanlines don't care about window size.
	Graphics.set_scanline_palette(1, 11, 269 - PANEL_HEIGHT)
	
	local get_lightest = function() return Lightest end
	local get_darkest = function() return Darkest end
	
	local binary_style = new_style{
		border_col = get_lightest,
		text_col = get_lightest,
		divider_col = get_lightest,
	}
		:child("field", new_style{
			fill_col = get_darkest,
			text_col = get_lightest,
			fill_col_focused = get_lightest,
			text_col_focused = get_darkest,
		})
		:child("viewport", new_style{
			pivot_col = get_lightest,
			pivot_outline_col = get_darkest,
			vector_col = get_lightest,
			vector_outline_col = get_darkest,
		})
		:child("button", new_style{
			fill_col = get_lightest,
			symbol_col = get_darkest
		})
		:child("scrollbar", new_style{
			fill_col = get_lightest,
			symbol_col = get_darkest,
			indent_col = get_lightest,
		})
	
	local style = new_style{
		text_col = 36,
		divider_col = 33,
	}
		:child("field", new_style{
			fill_col = 0,
			text_col = 7,
			fill_col_focused = 19,
			text_col_focused = 7,
		})
		:child("panel", new_style{
			col = 34,
			bevel_highlight = 35,
			bevel_shadow = 33,
		})
		:child("dictionary", new_style{})
		:child("scrollbar", new_style{
			fill_col = 33,
			symbol_col = 35,
			indent_col = 34,
		})
	
	local gui = create_gui{
		update = function()
			blinker.t = (blinker.t + BLINKER_SPEED) % 1
		end
	}
	
	local viewport = Viewport.attach_viewport(gui, editor, gfx_cache, {
		x = 0,
		y = 0,
		width = ScreenSize.x - ANIMATIONS_PANEL_WIDTH,
		height = ScreenSize.y - PANEL_HEIGHT,
		style = binary_style:get"viewport"
	})
	
	local animations_panel = gui:attach{
		x = viewport.width, y = 0,
		width = ANIMATIONS_PANEL_WIDTH, height = viewport.height,
		style = binary_style,
		label = "Animations",
		draw = function(self)
			Utils.border(self)
			line(2, self.height - 12, self.width - 12, self.height - 12, self.style:get"divider_col")
			print(self.label, 2, self.height - 10, self.style:get"text_col")
		end,
	}
	
	local animation_list = animations_panel:attach{
		x = 2, y = 2,
		width = animations_panel.width - 4, height = animations_panel.height - 16,
	}
	
	local animation_list_container = animation_list:attach{
		x = 0, y = 0,
		width = animation_list.width - 9, height = animation_list.height,
		style = binary_style,
		populate = Utils.populate,
		height_equation = function(_, len) return len * 12 end,
		get = function() return editor:get_animation_keys() end,
		factory = function(self, i, item)
			local row = self:attach{
				x = 0, y = (i - 1) * 12,
				width = self.width, height = 12,
				style = self.style,
				draw = function(self)
					if editor.current_anim_key == item then
						rect(0, 0, self.width - 1, self.height - 1, self.style:get"border_col")
					end
				end,
			}
			
			Field.attach(row, {
				x = 1,
				y = 1,
				width = row.width - 11,
				height = row.height - 2,
				style = self.style:get"field",
				item = item,
				blinker = blinker,
				
				get = function(self) return self.item end,
				set = function(self, value)
					editor:rename_animation(self.item, value)
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
				style = self.style:get"button",
				cursor = "pointer",
				draw = function(self)
					local style = self.style
					pal(1, style:get"fill_col")
					pal(7, style:get"symbol_col")
					spr(11, 0, 0)
					pal(0)
				end,
				click = function(self) editor:remove_animation(item) end,
			}
			
			return row
		end
	}
	
	Scrollbars.attach(animation_list, {
		style = binary_style:get"scrollbar"
	})
	
	---@diagnostic disable-next-line undefined-field
	animation_list_container:populate()
	
	local add_animation_button = animations_panel:attach{
		x = animations_panel.width - 10, y = animations_panel.height - 10,
		width = 8, height = 8,
		style = binary_style:get"button",
		cursor = "pointer",
		draw = function(self)
			local style = self.style
			pal(1, style:get"fill_col")
			pal(7, style:get"symbol_col")
			spr(10, 0, 0)
			pal(0)
		end,
		click = function(_) editor:create_animation() end,
	}
	
	local panel = gui:attach{
		x = 0, y = viewport.height,
		width = ScreenSize.x - PROPERTIES_WIDTH * 2, height = PANEL_HEIGHT - TIMELINE_HEIGHT,
		style = style,
		draw = function(self)
			Utils.draw_panel(self)
			spr(24, self.width * 0.5 - 32, 4)
		end,
	}
	
	local timeline = Timeline.attach(gui, editor, {
		x = 0,
		y = ScreenSize.y - TIMELINE_HEIGHT,
		width = ScreenSize.x, height = TIMELINE_HEIGHT,
		style = style,
		draw = Utils.draw_panel,
	})
	
	local transport = Transport.attach(gui, editor, {
		x = 0, y = timeline.y - TRANSPORT_HEIGHT,
		width = TRANSPORT_WIDTH, height = TRANSPORT_HEIGHT,
		style = style,
		draw = Utils.draw_panel,
	})
	
	local show_pivot_button = gui:attach{
		x = ScreenSize.x - PROPERTIES_WIDTH * 2 - 11,
		y = viewport.height,
		width = 11, height = 11,
		style = style,
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
		style = style:get"dictionary",
		label = "Properties",
		blinker = blinker,
		
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
		style = style:get"dictionary",
		label = "Events",
		blinker = blinker,
		
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
