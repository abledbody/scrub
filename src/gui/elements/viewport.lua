local Graphics = require"src/graphics"

---@param self EditorState
---@return [userdata]
local function get_2d_vectors(self)
	local vectors = {}
	local source_frame = self.timeline_selection.first
	for k, v in pairs(self.animations[self.current_anim_key]) do
		if k == "events" then
			local events = v[source_frame]
			for _, event_v in pairs(events) do
				if type(event_v) == "userdata" and #event_v >= 2 then
					add(vectors, event_v)
				end
			end
		elseif k != "pivot" then
			local value = v[source_frame]
			if type(value) == "userdata" and #value >= 2 then
				add(vectors, value)
			end
		end
	end
	return vectors
end

---@param editor EditorState
local function attach_viewport(self, editor, gfx_cache, el)
	el = self:attach(el)
	el.scroll = vec(0, 0)
	el.zoom = 1
	el.hovering = false
	el.hover_called = false
	
	function el:update()
		self.hovering = self.hover_called
		self.hover_called = false
	end
	
	function el:draw()
		camera(self.scroll.x - self.width * 0.5, self.scroll.y - self.height * 0.5)
		
		local anim_spr = editor.animator.sprite
		if type(anim_spr) ~= "number" then return end
		local spr_dat = Graphics.get_sprite(gfx_cache, anim_spr)
		if not spr_dat then return end
		local spr_w, spr_h = spr_dat:attribs()
		local pivot = editor.animator.pivot
		if type(pivot) ~= "userdata" or #pivot < 2 then pivot = vec(0, 0) end
		
		sspr(spr_dat, 0, 0, spr_w, spr_h, -pivot.x * self.zoom, -pivot.y * self.zoom,
			spr_w * self.zoom, spr_h * self.zoom)
		
		local vectors = get_2d_vectors(editor)
		
		if editor.show_pivot_state == 1 and not editor.playing or editor.show_pivot_state == 0 then
			pal(7, Lightest)
			
			spr(20, -4, -4)
			for v in all(vectors) do
				spr(19, self.zoom * v.x - 4, self.zoom * v.y - 4)
			end
			
			pal(7)
		end
	end
	
	function el:drag(msg)
		self.scroll -= vec(msg.dx, msg.dy)
		self.scroll.x = mid(-self.width * 0.5, self.scroll.x, self.width * 0.5)
		self.scroll.y = mid(-self.height * 0.5, self.scroll.y, self.height * 0.5)
	end
	
	function el:hover(msg)
		self.hover_called = true
		
		local _, _, _, _, wy = mouse()
		
		if wy == 0 then return end
		
		self.zoom += wy
		self.zoom = mid(1, self.zoom, 32)
	end
	
	function el:viewport_to_local()
		local mx, my = mouse()
		local rx = (mx - self.scroll.x) / self.zoom
		local ry = (my - self.scroll.y) / self.zoom
		
		return vec(rx, ry)
	end
	
	return el
end

return {
	attach_viewport = attach_viewport,
}
