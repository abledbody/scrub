local GuiUtils = require"src/gui/utils"
local Scrollbars = require"src/gui/elements/scrollbars"
local Field = require"src/gui/elements/field"

local function attach(self, el)
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
		
		populate = function(self)
			for i = 1, #self.reorder_buttons do
				self:detach(self.reorder_buttons[i])
			end
			self.reorder_buttons = {}
			return GuiUtils.populate(self)
		end,
		height_equation = function(_, len) return len * 11 end,
		reorder_buttons = {},
		
		get = el.get_dictionary,
		set_key = el.set_key,
		set_value = el.set_value,
		get_removable = el.get_removable,
		get_reorderable = el.get_reorderable,
		remove = el.remove,
		reorder = el.reorder,
		
		factory = function(self, i, item)
			local key = item.key
			
			local room_for_reorder_buttons = (self.get_reorderable and 7 or 0)
			
			local row = self:attach{
				x = 1 + room_for_reorder_buttons, y = (i - 1) * 11,
				width = self.width - 10 - room_for_reorder_buttons, height = 10,
			}
			
			local field_width = (row.width - 9) * 0.5
			
			Field.attach(row, {
				x = 0,
				y = 0,
				width = field_width,
				height = 10,
				fill_col = 0,
				text_col = 7,
				fill_col_focused = 19,
				text_col_focused = 7,
				blinker = el.blinker,
				get = function() return key end,
				set = function(_, value) self.set_key(key, value) end,
			})
			
			Field.attach(row, {
				x = 1 + field_width,
				y = 0,
				width = field_width,
				height = 10,
				fill_col = 0,
				text_col = 7,
				fill_col_focused = 19,
				text_col_focused = 7,
				blinker = el.blinker,
				get = function() return item.value end,
				set = function(_, value) self.set_value(key, value) end,
			})
			
			if self.get_removable and self.get_removable(key) then
				row:attach{
					x = row.width - 7, y = 2,
					width = 7, height = 7,
					cursor = "pointer",
					draw = el.draw_remove_button,
					click = function() self.remove(key) end,
				}
			end
			
			if self.get_reorderable
				and self.get_reorderable(i)
				and self.get_reorderable(i + 1)
			then
				add(self.reorder_buttons, el.container:attach{
					x = 1, y = row.y + 6,
					width = 5, height = 8,
					cursor = "pointer",
					draw = el.draw_swap_button,
					click = function() self.reorder(key, 1) end,
				})
			end
			
			return row
		end
	}
	
	el.add_button = el:attach{
		x = el.width - 17, y = el.height - 9,
		width = 8, height = 8,
		cursor = "pointer",
		draw = el.draw_add_button,
		click = function() el.create() end,
	}
	
	el:attach{
		x = 2, y = el.height - 9,
		width = el.add_button.x - 3, height = 8,
		label = el.label,
		col = el.col,
		draw = function(self) print(self.label, 0, 0, 36) end,
	}
	
	Scrollbars.attach(el.list)
	el.container:populate()
	
	return el
end

return {
	attach = attach,
}