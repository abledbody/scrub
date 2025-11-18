local function attach(self, attribs)
	local container = self
	local bar_short = self.bar_short or 8
	
	local attribs = attribs or {}
	local widthwise = attribs.widthwise or false -- Eh, why not?
	
	-- pick out only attributes relevant to scrollbar (autohide)
	-- caller could adjust them after though -- to do: perhaps should just spill everything in attribs as starting values
	local scrollbar = {
		x = 0,
		justify = not widthwise and "right",
		y = 0,
		vjustify = widthwise and "bottom",
		widthwise = widthwise,
		width = widthwise and container.width or bar_short,
		height = widthwise and bar_short or container.height,
		long_rel = 1.0,
		autohide = attribs.autohide,
		bar_offset = 0,
		bar_length = 0,
		cursor = "grab",
		style = attribs.style,
		
		update = function(self, msg)
			local container       = self.parent
			local contents        = container.child[1]
			local l0              = self.widthwise and self.width or self.height
			local l1              = self.widthwise and contents.width or contents.height
			local l2              = self.widthwise and container.width or container.height
			local bar_length      = max(9, l0 / l1 * l0) // 1 -- bar length; minimum 9 pixels
			local emp_l           = l0 - bar_length - 1 -- empty length (-1 for 1px boundary at bottom)
			local max_offset      = max(0, l1 - l2)
			
			self.scroll_spd       = max_offset / emp_l
			
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
			contents.x = mid(0, contents.x, container.width - contents.width)
			contents.y = mid(0, contents.y, container.height - contents.height)
		end,
		
		draw = function(self, msg)
			local fill_col = self.style:get"fill_col"
			local symbol_col = self.style:get"symbol_col"
			local indent_col = self.style:get"indent_col"
			
			rectfill(0, 0, self.width - 1, self.height - 1, fill_col | (symbol_col << 8))
			if self.bar_length <= 0 then return end
			
			if self.widthwise then
				rectfill(self.bar_offset + 1, 1, self.bar_offset + self.bar_length - 1, self.height - 2, symbol_col)
			else
				rectfill(1, self.bar_offset + 1, self.width - 2, self.bar_offset + self.bar_length - 1, symbol_col)
			end
		
			local ll = self.bar_offset + self.bar_length / 2
			if self.widthwise then
				line(ll - 1, 2, ll - 1, self.height - 3, indent_col)
				line(ll + 1, 2, ll + 1, self.height - 3, indent_col)
				
				pset(self.bar_offset + 1, 1, fill_col)
				pset(self.bar_offset + self.bar_length - 1, 1, fill_col)
				pset(self.bar_offset + 1, self.height - 2, fill_col)
				pset(self.bar_offset + self.bar_length - 1, self.height - 2, fill_col)
			else
				line(2, ll - 1, self.width - 3, ll - 1, indent_col)
				line(2, ll + 1, self.width - 3, ll + 1, indent_col)
				
				pset(1, self.bar_offset + 1, fill_col)
				pset(self.width - 2, self.bar_offset + 1, fill_col)
				pset(1, self.bar_offset + self.bar_length - 1, fill_col)
				pset(self.width - 2, self.bar_offset + self.bar_length - 1, fill_col)
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
				content.x += self.parent.width * sign
			else
				content.y += self.parent.height * sign
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

return {
	attach = attach
}