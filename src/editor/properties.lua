local StringUtils = require"src/string_utils"

-- It's important that the order of each property be preserved.

---@param self EditorState
---@return [{key: string, value: string, order: integer}]
local function get_property_strings(self)
	local source_frame = self.timeline_selection.first
	local anim = self.animations[self.current_anim_key]
	local keys = self.property_orders[self.current_anim_key].keys
	
	local properties = {}
	for i, k in ipairs(keys) do
		if k ~= "events" then
			properties[i] = {
				key = k,
				value = StringUtils.value_to_string(anim[k][source_frame])
			}
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
	self.property_orders[self.current_anim_key]:replace_key(key, new_key)
	
	self:on_properties_changed()
	self.undo_stack:checkpoint()
end

---@param self EditorState
---@param key string
---@param str string
local function set_property_by_string(self, key, str)
	local value, valid = StringUtils.string_to_value(str)
	if not valid then
		notify("Not a valid value. If you're trying to write a string, use quotation marks.")
		return
	end
	if key == "duration" and (type(value) ~= "number" or value <= 0) then
		notify("Duration must be a positive number.")
		return
	end
	
	local animation = self.animations[self.current_anim_key]
	for i in self:iterate_selection() do
		animation[key][i] = value
	end
	
	self:on_properties_changed()
	self.undo_stack:checkpoint()
end

---@param self EditorState
---@return string
local function create_property(self)
	local animation = self.animations[self.current_anim_key]
	
	local key = StringUtils.next_name("new", function(key) return animation[key] end)
	
	animation[key] = {}
	self.property_orders[self.current_anim_key]:insert(key)
	
	self:on_properties_changed()
	self.undo_stack:checkpoint()
	return key
end

---@param self EditorState
---@param key string
local function remove_property(self, key)
	if key == "duration" or key == "events" then return end
	
	local animation = self.animations[self.current_anim_key]
	if not animation[key] then return end
	animation[key] = nil
	assert(self.property_orders[self.current_anim_key]:remove(key))
	
	self:on_properties_changed()
	self.undo_stack:checkpoint()
end

return {
	get_property_strings = get_property_strings,
	rename_property = rename_property,
	set_property_by_string = set_property_by_string,
	create_property = create_property,
	remove_property = remove_property,
}