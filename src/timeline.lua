local function attach_frame(self,el)
	el = self:attach(el)

	el.width,el.height = 8,8
	function el:draw()
		spr(4)
	end

	return el
end

local function attach_timeline(self,accessors,el)
	el = self:attach(el)

	el.container = el:attach{
		x = 0,
		y = 0,
		width = 9,
		height = el.height,
		items = {},
	}

	function el:populate()
		local frame_count = #accessors.animator.anim.duration
		local container = self.container

		for i = #container.items,1,-1 do
			container:detach(container.items[i])
			deli(container.items,i)
		end

		for i = 1,frame_count do
			local item = attach_frame(self,{
				x = (i-1)*9,
				y = 0,
			})

			container.items[i] = item
		end

		container.width = frame_count*10
	end

	return el
end

return {
	attach_timeline = attach_timeline,
}