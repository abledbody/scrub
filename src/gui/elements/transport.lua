local Utils = require"src/gui/utils"

local function attach(self, editor, el)
	el = self:attach(el)
	el.first_frame_button = el:attach{
		x = 3, y = 3,
		width = 11, height = 11,
		cursor = "pointer",
		draw = function(self)
			Utils.draw_panel(self)
			spr(14, 2, 2)
		end,
		click = function(self)
			editor:first_frame()
		end,
	}
	
	el.prev_frame_button = el:attach{
		x = el.first_frame_button.x + el.first_frame_button.width + 1, y = 3,
		width = 11, height = 11,
		cursor = "pointer",
		draw = function(self)
			Utils.draw_panel(self)
			spr(22, 2, 2)
		end,
		click = function(self)
			editor:previous_frame()
		end,
	}
	
	el.play_button = el:attach{
		x = el.prev_frame_button.x + el.prev_frame_button.width + 1, y = 3,
		width = 11, height = 11,
		cursor = "pointer",
		draw = function(self)
			Utils.draw_panel(self)
			local sprite = editor.playing and 7 or 6
			spr(sprite, 2, 2)
		end,
		click = function(self)
			editor:set_playing(not editor.playing)
		end,
	}
	
	el.next_frame_button = el:attach{
		x = el.play_button.x + el.play_button.width + 1, y = 3,
		width = 11, height = 11,
		cursor = "pointer",
		draw = function(self)
			Utils.draw_panel(self)
			spr(23, 2, 2)
		end,
		click = function(self)
			editor:next_frame()
		end,
	}
	
	el.last_frame_button = el:attach{
		x = el.next_frame_button.x + el.next_frame_button.width + 1, y = 3,
		width = 11, height = 11,
		cursor = "pointer",
		draw = function(self)
			Utils.draw_panel(self)
			spr(15, 2, 2)
		end,
		click = function(self)
			editor:last_frame()
		end,
	}
end

return {
	attach = attach,
}
