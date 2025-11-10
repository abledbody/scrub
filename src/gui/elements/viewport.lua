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
			pal(1, Darkest)
			
			for v in all(vectors) do
				spr(19, self.zoom * v.x - 5, self.zoom * v.y - 5)
			end
			spr(20, -4, -4)
			
			pal(0)
		end
	end
	
	local function clamp_view(self)
		local pivot = editor.animator.pivot or vec(0, 0)
		
		local low_x, low_y = -self.width * 0.5, -self.height * 0.5
		local high_x, high_y = -low_x, -low_y
		
		local sprite_i = editor.animator.sprite
		if type(sprite_i) == "number" then
			local sprite = Graphics.get_sprite(editor.gfx_cache, sprite_i)
			if sprite then
				low_x = min(low_x, low_x - pivot.x * self.zoom)
				low_y = min(low_y, low_y - pivot.y * self.zoom)
				high_x = max(high_x, high_x + (sprite:width() - pivot.x) * self.zoom)
				high_y = max(high_y, high_y + ((sprite:height() or 1) - pivot.y) * self.zoom)
			end
		end
		self.scroll.x = mid(low_x, self.scroll.x, high_x)
		self.scroll.y = mid(low_y, self.scroll.y, high_y)
	end
	
	function el:drag(msg)
		self.scroll -= vec(msg.dx, msg.dy)
		clamp_view(self)
	end
	
	function el:hover(msg)
		self.hover_called = true
		
		local _, _, _, _, wy = mouse()
		
		if wy == 0 then return end
		
		local new_zoom = mid(0.25, self.zoom * 2 ^ wy, 16)
		local m_pos = vec(msg.mx, msg.my)
		local center = vec(self.width, self.height) * 0.5
		local mouse_offset = m_pos - center
		self.scroll = (self.scroll + mouse_offset) / self.zoom * new_zoom - mouse_offset
		
		self.zoom = new_zoom
		clamp_view(self)
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
