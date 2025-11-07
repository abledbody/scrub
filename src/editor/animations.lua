local StringUtils = require"src/string_utils"
local new_index_map = require"src/index_map"

---Sets the current animation to the one with the given key.
---@param self EditorState
---@param key string The key of the animation to switch to.
local function set_animation(self, key)
	self.animator.anim = self.animations[key]
	self.current_anim_key = key
	self:set_timeline_selection(1, 1)
	self:on_selection_changed()
	self:set_frame(1)
	self:on_frames_changed()
end

---Renames the current animation to the given name.
---@param self EditorState
---@param name string The new name for the current animation.
local function rename_animation(self, name)
	if self.animations[name] then return end
	self.animations[name], self.animations[self.current_anim_key] = self.animations[self.current_anim_key], nil
	self.current_anim_key = name
	
	self:on_animations_changed()
	self.undo_stack:checkpoint()
end

---Creates a new animation with a unique name and sets it as the current animation.
---@param self EditorState
---@return string anim_name The name of the newly created animation.
local function create_animation(self)
	local anim_name = StringUtils.next_name("new", function(key) return self.animations[key] end)
	
	self.animations[anim_name] = {sprite = {0}, duration = {0.1}}
	self.property_orders[anim_name] = new_index_map({"duration", "sprite"})
	self.animation_order:insert(anim_name)
	self:set_animation(anim_name)
	
	self:on_animations_changed()
	self.undo_stack:checkpoint()
	return anim_name
end

---Removes the animation with the given key.
---@param self EditorState
---@param key string The key of the animation to remove.
local function remove_animation(self, key)
	if not self.animations[key] then return end
	
	local deleting_current = key == self.current_anim_key
	local next_key
	if deleting_current then
		local next_index = self.animation_order.indices[key] + 1
		if next_index > #self.animation_order.keys then next_index -= 2 end
		next_key = self.animation_order.keys[next_index]
	end
	
	self.animations[key] = nil
	self.property_orders[key] = nil
	self.animation_order:remove(key)
	
	if deleting_current then
		if next_key and next_key ~= self.current_anim_key then
			self:set_animation(next_key)
		else
			self:set_animation(self:create_animation())
		end
	end
	
	self:on_animations_changed()
	self.undo_stack:checkpoint()
end

local function get_animation_keys(self)
	local keys = {}
	for i, k in ipairs(self.animation_order.keys) do
		keys[i] = k
	end
	return keys
end

local function get_animation(self) return self.animations[self.current_anim_key] end

return {
	set_animation = set_animation,
	rename_animation = rename_animation,
	create_animation = create_animation,
	remove_animation = remove_animation,
	get_animation_keys = get_animation_keys,
	get_animation = get_animation,
}
