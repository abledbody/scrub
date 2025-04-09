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

		local selection = accessors.get_timeline_selection()
		local sel_first,sel_last = selection.first,selection.last
		if sel_first > sel_last then
			sel_first,sel_last = sel_last,sel_first
		end

		rectfill((sel_first-1)*8,0,(sel_last-1)*8+7,7,24)
		for i = 1,#durations do
			local oval_func = i == animator.frame_i and ovalfill or oval
			oval_func((i-1)*8+1,1,(i-1)*8+6,6,36)
		end
	end

	function el.frames:drag(msg)
		local i = mid(1,msg.mx\8+1,#accessors.get_animation().duration)
		if not accessors.get_playing() then
			accessors.set_frame(i)
		end
		
		if key("shift") then
			local sel_first = accessors.get_timeline_selection().first
			accessors.set_timeline_selection(sel_first,i)
		else
			accessors.set_timeline_selection(i,i)
		end
		accessors.set_lock_selection_to_frame(false)
	end

	function el.container:fit()
		self.width = #accessors.get_animation().duration*8+10
	end

	el.insert_button = el.container:attach{
		x = 0,y = el.container.height-16,
		width = 7,height = 7,
		draw = function(_) spr(2,0,0) end,
		click = function(_)
			accessors.insert_frame()

			local i = accessors.animator.frame_i
			if key("shift") then
				local sel_first = accessors.get_timeline_selection().first
				accessors.set_timeline_selection(sel_first,i)
			else
				accessors.set_timeline_selection(i,i)
			end
		end,
	}

	el.remove_button = el.container:attach{
		x = 0,y = el.container.height-16,
		width = 7,height = 7,
		draw = function(_) spr(3,0,0) end,
		click = function(_)
			accessors.remove_frame()
			
			local i = accessors.animator.frame_i
			accessors.set_timeline_selection(i,i)
		end,
	}

	function el:align_buttons()
		local sel_last = accessors.get_timeline_selection().last
		el.remove_button.x = (sel_last-1)*8
		el.insert_button.x = (sel_last-1)*8+8
	end

	el:align_buttons()

	return el
end

return {
	attach = attach,
}