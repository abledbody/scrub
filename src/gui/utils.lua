--- Draws a beveled panel.
local function draw_panel(self)
	local style = self.style:get"panel"
	local col = style:get"col"
	local high = style:get"bevel_highlight"
	local shade = style:get"bevel_shadow"
	
	rectfill(0, 0, self.width, self.height, col)
	line(0, 0, self.width - 1, 0, high)
	line(0, 0, 0, self.height - 1, high)
	line(0, self.height - 1, self.width - 1, self.height - 1, shade)
	line(self.width - 1, 0, self.width - 1, self.height - 1, shade)
end

--- Draws a rectangle across the whole element
local function fill(self)
	local col = self.style:get"fill_col"
	rectfill(0, 0, self.width - 1, self.height - 1, col)
end

local function border(self)
	local col = self.style:get"border_col"
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

local m_style = {}
m_style.__index = m_style

function m_style:get(key)
	local haver = self
	local value
	repeat 
		value = haver[key]
		haver = haver.parent
	until (value != nil) or not haver
	
	if type(value) == "function" then return value() end
	
	return value
end

function m_style:child(key, style)
	style.parent = self
	self[key] = style
	return self
end

local function new_style(style)
	return setmetatable(style, m_style)
end

return {
	new_style = new_style,
	draw_panel = draw_panel,
	fill = fill,
	border = border,
	populate = populate,
}