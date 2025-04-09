local function attach_viewport(self,accessors,el)
	el = self:attach(el)
	el.scroll = vec(0,0)
	el.zoom = 1
	el.hovering = false
	el.hover_called = false

	function el:update()
		self.hovering = self.hover_called
		self.hover_called = false
	end

	function el:draw()
		camera(self.scroll.x,self.scroll.y)

		local anim_spr = accessors.animator.spr
		if type(anim_spr) ~= "number" then return end
		local spr_dat = accessors.get_sprite(anim_spr)
		if not spr_dat then return end
		local spr_w,spr_h = spr_dat:attribs()

		if not spr_dat then return end
		sspr(spr_dat,0,0,spr_w,spr_h,0,0,spr_w*self.zoom,spr_h*self.zoom)
	end

	function el:drag(msg)
		self.scroll -= vec(msg.dx, msg.dy)
	end

	function el:hover(msg)
		self.hover_called = true

		local _,_,_,_,wy = mouse()

		if wy == 0 then return end

		local last_zoom = self.zoom
		
		self.zoom += wy
		self.zoom = mid(1,self.zoom,32)
		
		local delta = self.zoom-last_zoom

		local anim_spr = accessors.animator.spr
		local spr_dat = accessors.get_sprite(anim_spr)
		local spr_w,spr_h = spr_dat:attribs()

		self.scroll.x += delta*spr_w*0.5
		self.scroll.y += delta*spr_h*0.5
	end

	function el:viewport_to_local()
		--WARNING: UNTESTED
		local mx, my = mouse()
		local rx = (mx-self.scroll.x)/self.zoom
		local ry = (my-self.scroll.y)/self.zoom

		return vec(rx, ry)
	end

	return el
end

return {
	attach_viewport = attach_viewport,
}