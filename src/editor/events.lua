local StringUtils = require"src/string_utils"

---@param self EditorState
local function initialize_events(self)
	local animation = self.animations[self.current_anim_key]
	if animation.events then return end
	
	local events = {}
	for i = 1, #animation.duration do
		events[i] = {}
	end
	animation.events = events
end

---@param self EditorState
local function clean_events(self)
	local animation = self.animations[self.current_anim_key]
	local events = animation.events
	if not events then return end
	
	local event_found = false
	for i = 1, #animation.duration do
		if events[i] and next(events[i]) then
			event_found = true
			break
		end
	end
	
	if event_found then
		for i = 1, #animation.duration do
			if not events[i] then
				events[i] = {}
			end
		end
	else
		animation.events = nil
	end
end

---@param self EditorState
local function get_event_strings(self)
	local events = self.animations[self.current_anim_key].events
	if not events then return {} end
	
	local event_strings = {}
	local frame_events = events[self.timeline_selection.first]
	if not frame_events then return {} end
	
	for k, v in pairs(frame_events) do
		add(event_strings, {key = k, value = StringUtils.value_to_string(v)})
	end
	return event_strings
end

---@param self EditorState
local function create_event(self)
	local animation = self.animations[self.current_anim_key]
	if not animation.events then self:initialize_events() end
	local events = animation.events ---@cast events [table<string, any>]
	
	local key = StringUtils.next_name("new", function(key)
		for i in self:iterate_selection() do
			local frame_events = events[i]
			if frame_events and frame_events[key] then return true end
		end
	end)
	
	for i in self:iterate_selection() do
		if not events[i] then events[i] = {} end
		local frame_events = events[i]
		frame_events[key] = true
	end
	
	self:on_events_changed()
	return key
end

---@param self EditorState
---@param key string
local function remove_event(self, key)
	local events = self.animations[self.current_anim_key].events
	if not events then return end
	
	for i in self:iterate_selection() do
		local frame_events = events[i]
		if frame_events and frame_events[key] then
			frame_events[key] = nil
		end
	end
	
	self:clean_events()
	
	self:on_events_changed()
end

---@param self EditorState
---@param key string
---@param new_key string
local function rename_event(self, key, new_key)
	local events = self.animations[self.current_anim_key].events
	if not events then return end
	
	--Double loop to prevent mutation if the rename fails.
	for i in self:iterate_selection() do
		local frame_events = events[i]
		if frame_events and frame_events[key] and frame_events[new_key] then
			notify("The " .. new_key .. " event already exists somewhere in the selection.")
			return
		end
	end
	
	for i in self:iterate_selection() do
		local frame_events = events[i]
		if frame_events and frame_events[key] then
			frame_events[new_key] = frame_events[key]
			frame_events[key] = nil
		end
	end
	
	self:on_events_changed()
end

---@param self EditorState
---@param key string
---@param str string
local function set_event_by_string(self, key, str)
	local events = self.animations[self.current_anim_key].events
	if not events then return end
	
	local value = StringUtils.string_to_value(str)
	if value == nil then return end
	
	for i in self:iterate_selection() do
		local frame_events = events[i]
		if frame_events and frame_events[key] then
			frame_events[key] = value
		end
	end
	
	self:on_events_changed()
end

return {
	initialize_events = initialize_events,
	clean_events = clean_events,
	get_event_strings = get_event_strings,
	create_event = create_event,
	remove_event = remove_event,
	rename_event = rename_event,
	set_event_by_string = set_event_by_string,
}