local GuiUtils = require"src/gui/utils"
local Scrollbars = require"src/gui/elements/scrollbars"
local Field = require"src/gui/elements/field"

---@param key string
---@param pad_left integer
---@param pad_right integer
local function attach_fields(self, row, item, key, pad_left, pad_right)
	local field_width = (row.width - pad_right - pad_left - 1) * 0.5
	
	local left_width = field_width // 1
	Field.attach(row, {
		x = pad_left,
		y = 0,
		width = left_width,
		height = 10,
		style = self.style:get"field",
		blinker = self.blinker,
		get = function() return key end,
		set = function(_, value) self.set_key(key, value) end,
	})
	
	local right_width = -(field_width // -1)
	Field.attach(row, {
		x = row.width - pad_right - right_width,
		y = 0,
		width = right_width,
		height = 10,
		style = self.style:get"field",
		blinker = self.blinker,
		get = function() return item.value end,
		set = function(_, value) self.set_value(key, value) end,
	})
end

---@param key string
local function attach_remove_button(self, row, key, x)
	if self.get_removable and self.get_removable(key) then
		return row:attach{
			x = x, y = 2,
			width = 7, height = 7,
			cursor = "pointer",
			draw = self.draw_remove_button,
			click = function() self.remove(key) end,
		}
	end
end

---@param i integer
---@param key string
local function attach_reorder_button(self, row, i, key)
	if self.get_reorderable
		and self.get_reorderable(i)
		and self.get_reorderable(i + 1)
	then
		local button = self:attach{
			x = 1, y = row.y + 6,
			width = 5, height = 8,
			cursor = "pointer",
			draw = self.draw_swap_button,
			click = function() self.reorder(key, 1) end,
		}
		add(self.reorder_buttons, button)
		return button
	end
end

---@param i integer
---@param pad_left integer
---@param pad_right integer
local function attach_row(self, i, pad_left, pad_right)
	return self:attach{
		x = pad_left, y = (i - 1) * 11,
		width = self.width - pad_right - pad_left, height = 10,
	}
end

---@param i integer
local function factory(self, i, item)
	local key = item.key
	
	local room_for_reorder_buttons = (self.get_reorderable and 7 or 0)
	
	local row = attach_row(self, i, room_for_reorder_buttons, 8)
	
	attach_remove_button(self, row, key, row.width - 8)
	attach_fields(self, row, item, key, 0, 9)
	attach_reorder_button(self, row, i, key)
	
	return row
end

local function draw(self)
	GuiUtils.draw_panel(self)
	line(2, self.height - 11, self.width - 11, self.height - 11, self.style:get"divider_col")
end

local function attach(self, el)
	local draw = el.draw or draw
	el = self:attach(el)
	
	el.draw = draw
	
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
		style = el.style,
		
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
		blinker = el.blinker,
		draw_remove_button = el.draw_remove_button,
		draw_swap_button = el.draw_swap_button,
		
		factory = el.factory or factory,
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
		style = el.style,
		draw = function(self) print(self.label, 0, 0, self.style:get"text_col") end,
	}
	
	Scrollbars.attach(el.list, {
		style = el.style:get"scrollbar"
	})
	el.container:populate()
	
	return el
end

return {
	attach = attach,
	factory = factory,
	attach_fields = attach_fields,
	attach_remove_button = attach_remove_button,
	attach_reorder_button = attach_reorder_button,
	attach_row = attach_row,
	draw = draw,
}