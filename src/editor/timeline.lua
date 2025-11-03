---@param self EditorState
---@return function
local function iterate_selection(self)
	local sel_first, sel_last = self.timeline_selection.first, self.timeline_selection.last
	if sel_first > sel_last then
		sel_first, sel_last = sel_last, sel_first
	end
	
	local i = sel_first
	return function()
		if i > sel_last then return nil end
		local frame = i
		i += 1
		return frame
	end
end

---@param self EditorState
---@param first integer
---@param last integer
local function set_timeline_selection(self, first, last)
	local length = #self.animations[self.current_anim_key].duration
	first = mid(1, first, length)
	last = mid(1, last, length)
	
	if first == self.timeline_selection.first
		and last == self.timeline_selection.last
	then
		return
	end
	
	self.timeline_selection = {first = first, last = last}
	self:on_selection_changed()
end

---@param self EditorState
---@param frame_i integer
local function set_frame(self, frame_i)
	self.animator:reset(mid(1, frame_i, #self.animations[self.current_anim_key].duration))
	self:on_frame_change()
end

---@param self EditorState
---@param frame_i integer
local function select_frame(self, frame_i)
	if not self.playing then
		self:set_frame(frame_i)
	end
	
	if key("shift") then
		local sel_first = self.timeline_selection.first
		self:set_timeline_selection(sel_first, frame_i)
	else
		self:set_timeline_selection(frame_i, frame_i)
	end
	self.lock_selection_to_frame = false
end

---@param self EditorState
local function insert_frame(self)
	if self.playing then return end
	local animation = self.animations[self.current_anim_key]
	
	local sel_last = self.timeline_selection.last
	
	for k, v in pairs(animation) do
		if k == "events" then
			add(v, {}, sel_last + 1)
		else
			add(v, v[sel_last], sel_last + 1)
		end
	end
	
	self:select_frame(sel_last + 1)
	self:on_frames_changed()
end

---@param self EditorState
local function remove_frame(self)
	if self.playing then return end
	local animation = self.animations[self.current_anim_key]
	
	local sel_first, sel_last = self.timeline_selection.first, self.timeline_selection.last
	if sel_first > sel_last then
		sel_first, sel_last = sel_last, sel_first
	end
	
	for _, v in pairs(animation) do
		for i = sel_last, sel_first, -1 do
			if #v == 1 then break end
			deli(v, i)
		end
	end
	
	self:clean_events()
	self.playing = false
	
	self:select_frame(sel_first)
	--Have to trigger this manually, because technically the selection is still
	--pointing to the same indices.
	self:on_selection_changed()
	
	self:on_frames_changed()
end

---@param self EditorState
local function previous_frame(self)
	self:set_playing(false)
	local duration_count = #self.animations[self.current_anim_key].duration
	self:select_frame((self.animator.frame_i - 2) % duration_count + 1)
end

---@param self EditorState
local function next_frame(self)
	self:set_playing(false)
	local duration_count = #self.animations[self.current_anim_key].duration
	self:select_frame((self.animator.frame_i % duration_count) + 1)
end

---@param self EditorState
local function first_frame(self)
	self:set_playing(false)
	self:select_frame(1)
end

---@param self EditorState
local function last_frame(self)
	self:set_playing(false)
	local duration_count = #self.animations[self.current_anim_key].duration
	self:select_frame(duration_count)
end

return {
	iterate_selection = iterate_selection,
	set_timeline_selection = set_timeline_selection,
	
	set_frame = set_frame,
	select_frame = select_frame,
	insert_frame = insert_frame,
	remove_frame = remove_frame,
	
	previous_frame = previous_frame,
	next_frame = next_frame,
	first_frame = first_frame,
	last_frame = last_frame
}