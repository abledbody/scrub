local function attach(self,accessors,el)
	el = self:attach(el)

	el.container = el:attach{
		x = 2,
		y = 2,
		width = el.width-4,
		height = el.height-4,
	}

	el.frames = el.container:attach{
		x = 4,
		y = el.container.height-8,
		width = el.container.width-10,
		height = 8,
	}

	function el.frames:draw()
		local animation = accessors.get_animation()
		local animator = accessors.animator
		local durations = animation.duration

		poke(0x5f36,0x2)
		for i = 1,#durations do
			local oval_func = i == animator.frame_i and ovalfill or oval
			oval_func((i-1)*8+1,1,(i-1)*8+6,6,36)
		end
		poke(0x5f36,0x0)
	end

	function el.frames:drag(msg)
		accessors.set_frame(
			mid(1,msg.mx\8+1,#accessors.get_animation().duration)
		)
	end

	function el.container:fit()
		self.width = #accessors.get_animation().duration*8+10
	end

	el.insert_button = el.container:attach{
		x = 0,y = el.container.height-16,
		width = 7,height = 7,
		draw = function(_) spr(2,0,0) end,
		click = function(_) accessors.insert_frame() end,
	}

	el.remove_button = el.container:attach{
		x = 0,y = el.container.height-16,
		width = 7,height = 7,
		draw = function(_) spr(3,0,0) end,
		click = function(_) accessors.remove_frame() end,
	}

	function el:align_buttons()
		el.remove_button.x = (accessors.animator.frame_i-1)*8
		el.insert_button.x = (accessors.animator.frame_i-1)*8+8
	end

	el:align_buttons()

	return el
end

return {
	attach = attach,
}