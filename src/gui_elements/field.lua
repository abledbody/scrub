local function draw(self)
	local has_keyboard_focus = self:has_keyboard_focus()
	
	local str = has_keyboard_focus and self.str or self:get()
	
	local fill_col = has_keyboard_focus and self.fill_col_focused or self.fill_col
	local text_col = has_keyboard_focus and self.text_col_focused or self.text_col
	
	rectfill(0, 0, self.width - 1, self.height - 1, fill_col)
	
	local offset = has_keyboard_focus and self.offset or 0
	print(str, 1 - offset, 1, text_col)
	
	if has_keyboard_focus and blinker < 0.5 then
		local x = self.curs_pos - offset
		line(x, 1, x, 8, text_col)
	end
	
	if self.label then
		clip()
		local ww = print(self.label, 0, -1000)
		print(self.label, -ww, 1, text_col)
	end
end

local function field_click(self)
	self:set_keyboard_focus(true)
	self.str = self:get()
	self:update_cursor(#self.str)
	readtext(true)
end

local function update(self)
	if not self:has_keyboard_focus() then return end
	
	local first = string.sub(self.str, 1, self.curs)
	local last = string.sub(self.str, self.curs + 1)
	while (peektext()) do
		local txt = readtext()
		self.str = first .. txt .. last
		self:update_cursor(self.curs + #txt)
	end
	
	if keyp("enter") then
		if (type(self.set) == "function") then self:set(self.str) end
		self:set_keyboard_focus(false)
	end
	
	if keyp("backspace") then
		self.str = string.sub(first, 1, self.curs - 1) .. last
		self:update_cursor(self.curs - 1)
	end
	if keyp("delete") then
		self.str = first .. string.sub(last, 2)
	end
	
	if keyp("left") then
		self:update_cursor(self.curs - 1)
	end
	if keyp("right") then
		self:update_cursor(self.curs + 1)
	end
end

local function attach(self, el)
	-- Draw gets set during attach. I don't know why, but to be on the safe side,
	-- we handle the other defaulted functions here too.
	local draw = el.draw or draw
	local click = el.click or field_click
	local update = el.update or update
	
	el = self:attach(el)
	el.offset = 0
	el.str = el:get()
	el.draw = draw
	el.click = click
	el.update = update
	el.cursor = "pointer"
	
	function el:update_cursor(val)
		self.curs = mid(0, val, #self.str)
		self.curs_pos = print(string.sub(self.str, 1, self.curs), 0, -1000)
		local max_width = print(self.str, 0, -1000)
		
		self.offset = mid(
			0,
			self.curs_pos - mid(0, self.curs_pos - self.offset, self.width - 1),
			max_width - self.width + 1
		)
		
		blinker = 0
	end
	
	el:update_cursor(#el.str)
	
	return el
end

return {
	click = click,
	attach = attach,
}