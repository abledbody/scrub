local function attach_timeline(self,accessors,el)
	el = self:attach(el)

	el.container = el:attach{
		x = 1,
		y = 1,
		width = el.width,
		height = el.height,
	}

	function el.container:draw()
		local animation = accessors.get_animation()
		local animator = accessors.animator
		local durations = animation.duration

		for i = 1,#durations do
			local sprite = i == animator.frame_i and 4 or 5
			spr(sprite,(i-1)*8,0)
		end
	end

	return el
end

return {
	attach_timeline = attach_timeline,
}