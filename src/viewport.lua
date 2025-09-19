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
		camera(self.scroll.x-self.width*0.5,self.scroll.y-self.height*0.5)

		local anim_spr = accessors.animator.sprite
		if type(anim_spr) ~= "number" then return end
		local spr_dat = accessors.get_sprite(anim_spr)
		if not spr_dat then return end
		local spr_w,spr_h = spr_dat:attribs()
		local pivot = accessors.animator.pivot
		if type(pivot) ~= "userdata" or #pivot < 2 then pivot = vec(0,0) end
		
		sspr(spr_dat,0,0,spr_w,spr_h,(-0.5-pivot.x)*self.zoom+0.5,(-0.5-pivot.y)*self.zoom+0.5,spr_w*self.zoom,spr_h*self.zoom)
		
		if not accessors.get_playing() then
			pal(7,Lightest)
			spr(20,-4,-4)
			pal(7,7)
		end
	end

	function el:drag(msg)
		self.scroll -= vec(msg.dx, msg.dy)
		self.scroll.x = mid(-self.width*0.5,self.scroll.x,self.width*0.5)
		self.scroll.y = mid(-self.height*0.5,self.scroll.y,self.height*0.5)
	end

	function el:hover(msg)
		self.hover_called = true

		local _,_,_,_,wy = mouse()

		if wy == 0 then return end
		
		self.zoom += wy
		self.zoom = mid(1,self.zoom,32)
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