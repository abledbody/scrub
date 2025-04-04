local Viewport = require"src/viewport"

local BLINKER_SPEED <const> = 1*DT
local PANEL_HEIGHT <const> = 60

local blinker = 0

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

local function fill(self)
	local col = self.col or 34
	rectfill(0,0,self.width-1,self.height-1,col)
end

local function get_offset(self)
	local pos = vec(self.x,self.y)
	if not self.parent then return pos end
	return pos+get_offset(self.parent)
end

local function attach_field(self,el)
	el = self:attach(el)
	el.offset = 0
	el.str = el:get()

	function el:draw()
		local has_keyboard_focus = self:has_keyboard_focus()
		
		local str = has_keyboard_focus and self.str or self:get()

		rectfill(0,0,self.width-1,self.height-1,
			has_keyboard_focus and self.focus_col or self.fill_col
		)

		local offset = has_keyboard_focus and self.offset or 0
		print(str,1-offset,1,self.text_col)
		
		if has_keyboard_focus and blinker < 0.5 then
			local x = self.curs_pos-offset
			line(x,1,x,8,self.text_col)
		end

		if self.label then
			clip()
			local ww = print(self.label,0,-1000)
			print(self.label,-ww,1,13)
		end
	end

	function el:click()
		self:set_keyboard_focus(true)
		self.str = self:get()
		self:update_cursor(#self.str)
	end

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

	function el:update()
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

	return el
end

local function attach_dropdown_label_button(self, el)
	local el = self:attach(el)
	el.hovering = false
	el.hover_called = false

	function el:update()
		self.hovering = self.hover_called
		self.hover_called = false
	end

	function el:draw()
		if self.hovering then
			rectfill(0,0,self.width,self.height,35)
		end

		print(self.label,1,1,self.col)
	end

	function el:hover()
		self.hover_called = true
	end

	return el
end

function attach_animation_dropdown(self, el)
	local el = self:attach(el)

	
end

local function populate_mutable_list(self)
	local items = self:get()

	local max_height = ScreenSize.y-get_offset(self).y
	self.height = min(#items*10+2,max_height)

	for i,item in ipairs(items) do
		attach_dropdown_label_button(self,{
			x = 1,y = (i-1)*10+1,
			width = self.width-10,height = 10,
			col = 7,
			click = function() self:select(item) self.hidden = true end,
			label = item,
		})
	end
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
		width = ScreenSize.x,
		height = ScreenSize.y-PANEL_HEIGHT
	})

	local panel = gui:attach{
		x=0,y=ScreenSize.y-PANEL_HEIGHT,
		width = 480,height = PANEL_HEIGHT,
	}

	local toolbar = panel:attach{
		x=0,y=0,
		width = 480,height = 12,
		draw = draw_panel,
	}

	local animation_key_field = attach_field(toolbar,{
		x=1,y=1,
		width = 90,height = 10,
		fill_col = 0,
		focus_col = 19,
		text_col = 7,
		get = function() return accessors.get_animation_key() end,
		set = function(_,key) accessors.set_animation_key(key) end,
	})

	local dropdown_container

	local dropdown_button = toolbar:attach{
		x=animation_key_field.x+animation_key_field.width+1,
		y=animation_key_field.y,
		width = 8,height = 8,
		
		click = function(self)
			dropdown_container.hidden = not dropdown_container.hidden
			if not dropdown_container.hidden then
				dropdown_container:populate()
			end
		end,
		draw = function()
			spr(1,1,1)
		end
	}

	dropdown_container = panel:attach{
		x = dropdown_button.x, y = dropdown_button.y + dropdown_button.height,
		width = 150,
		height = 10,
		draw = draw_panel,
		hidden = true,
		get = function() return accessors.get_animation_keys() end,
		select = function(_,key) accessors.set_animation(key) end,
		populate = populate_mutable_list
	}

	dropdown_container:attach{
		x = 0,y = 0,
		width = 10,height = 100
	}

	dropdown_container:attach_scrollbars()
	

	return {
		gui = gui,
		panel = panel
	}
end

return {
	initialize = initialize
}