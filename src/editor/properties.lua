local StringUtils = require"src/string_utils"

---@param self EditorState
---@return [{key: string, value: string}]
local function get_property_strings(self)
	local properties = {}
	local source_frame = self.timeline_selection.first
	for k, v in pairs(self.animations[self.current_anim_key]) do
		if k ~= "events" then
			add(properties, {key = k, value = StringUtils.value_to_string(v[source_frame])})
		end
	end
	return properties
end

---@param self EditorState
---@param key string
---@param new_key string
local function rename_property(self, key, new_key)
	local animation = self.animations[self.current_anim_key]
	if not animation[key] or key == "events" then return end
	if key == "duration" then
		notify("You cannot rename the duration property.")
		return
	end
	if new_key == "events" then
		notify("'events' is a reserved property name.")
		return
	end
	if animation[new_key] then
		notify("The " .. new_key .. " property already exists.")
		return
	end
	
	animation[new_key] = animation[key]
	animation[key] = nil
	
	self:on_properties_changed()
end

---@param self EditorState
---@param key string
---@param str string
local function set_property_by_string(self, key, str)
	local value = StringUtils.string_to_value(str)
	if key == "duration" and (type(value) ~= "number" or value <= 0) then
		notify("Duration must be a positive number.")
		return
	end
	
	local animation = self.animations[self.current_anim_key]
	for i in self:iterate_selection() do
		animation[key][i] = value
	end
	
	self:on_properties_changed()
end

---@param self EditorState
---@return string
local function create_property(self)
	local animation = self.animations[self.current_anim_key]
	
	local key = StringUtils.next_name("new", function(key) return animation[key] end)
	
	animation[key] = {}
	
	self:on_properties_changed()
	return key
end

---@param self EditorState
---@param key string
local function remove_property(self, key)
	if key == "duration" or key == "events" then return end
	
	local animation = self.animations[self.current_anim_key]
	if not animation[key] then return end
	animation[key] = nil
	
	self:on_properties_changed()
end

return {
	get_property_strings = get_property_strings,
	rename_property = rename_property,
	set_property_by_string = set_property_by_string,
	create_property = create_property,
	remove_property = remove_property,
}