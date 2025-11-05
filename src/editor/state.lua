local Animation = require"src/animation"
local Timeline = require"src/editor/timeline"
local Animations = require"src/editor/animations"
local Properties = require"src/editor/properties"
local Events = require"src/editor/events"
local new_index_map = require"src/index_map"

---@param imported_property_orders table<string, [string]>
---@param animations table<string, Animation>
local function import_property_orders(imported_property_orders, animations)
	local function get_arbitrary_property_order(animation)
		local keys = {"duration"}
		
		for k, _ in pairs(animation) do
			if not (k == "duration" or k == "events") then
				add(keys, k)
			end
		end
		
		return new_index_map(keys)
	end
	
	local index_maps = {}
	
	if type(imported_property_orders) != "table" then
		for anim_key, anim_value in pairs(animations) do
			index_maps[anim_key] = get_arbitrary_property_order(anim_value)
		end
		return index_maps
	end
	
	for anim_key, anim_value in pairs(animations) do
		local anim_order = imported_property_orders[anim_key]
		 
		if type(anim_order) != "table" then
			index_maps[anim_key] = get_arbitrary_property_order(anim_value)
			goto continue
		end
		
		local index_map = new_index_map()
		index_map:insert("duration")
		
		-- Ordered
		for _, k in ipairs(anim_order) do
			if not (k == "duration" or k == "events") and anim_value[k] then
				index_map:insert(k)
			end
		end
		
		-- Unordered
		for k, _ in pairs(anim_value) do
			if not (k == "duration" or k == "events" or index_map.indices[k]) then
				index_map:insert(k)
			end
		end
		
		index_maps[anim_key] = index_map
		::continue::
	end
	
	return index_maps
end

---@class EditorState
local m_editor_state = {
	iterate_selection      = Timeline.iterate_selection,
	set_timeline_selection = Timeline.set_timeline_selection,
	set_frame              = Timeline.set_frame,
	select_frame           = Timeline.select_frame,
	insert_frame           = Timeline.insert_frame,
	remove_frame           = Timeline.remove_frame,
	previous_frame         = Timeline.previous_frame,
	next_frame             = Timeline.next_frame,
	first_frame            = Timeline.first_frame,
	last_frame             = Timeline.last_frame,

	set_animation      = Animations.set_animation,
	rename_animation   = Animations.rename_animation,
	create_animation   = Animations.create_animation,
	remove_animation   = Animations.remove_animation,
	get_animation_keys = Animations.get_animation_keys,
	get_animation      = Animations.get_animation,

	get_property_strings   = Properties.get_property_strings,
	rename_property        = Properties.rename_property,
	set_property_by_string = Properties.set_property_by_string,
	create_property        = Properties.create_property,
	remove_property        = Properties.remove_property,

	initialize_events   = Events.initialize_events,
	clean_events        = Events.clean_events,
	get_event_strings   = Events.get_event_strings,
	create_event        = Events.create_event,
	remove_event        = Events.remove_event,
	rename_event        = Events.rename_event,
	set_event_by_string = Events.set_event_by_string,
}
m_editor_state.__index = m_editor_state

---@param value boolean
function m_editor_state:set_playing(value)
	if value then self.lock_selection_to_frame = true end
	self.playing = value
end

function m_editor_state:export_metadata()
	local exported_property_orders = {}
	for anim_key, order in pairs(self.property_orders) do
		exported_property_orders[anim_key] = order.keys
	end
	
	---@class EditorMetadata
	---@field property_orders table<string, [string]>
	return {
		property_orders = exported_property_orders
	}
end

---@param animations table<string, Animation>
---@param palette userdata
---@param metadata EditorMetadata
---@return EditorState
local function new_state(animations, palette, metadata)
	local current_anim_key = next(animations) or "new_1"
	
	local property_orders = import_property_orders(
		metadata and metadata.property_orders,
		animations
	)
	
	---@class EditorState
	---@field show_pivot_state
	---|0: Show
	---|1: Show when paused
	---|2: Hide
	---@field property_orders table<string, IndexMap>
	---@field on_animations_changed function?
	---@field on_frames_changed function?
	---@field on_frame_change function?
	---@field on_properties_changed function?
	---@field on_selection_changed function?
	---@field on_events_changed function?
	local state = {
		animator = Animation.new_animator(animations[current_anim_key]), ---@type Animator
		animations = animations, ---@type table<string, Animation>
		current_anim_key = current_anim_key, ---@type string
		gfx_cache = {}, ---@type table<number, [{bmp:userdata}]>
		palette = palette, ---@type userdata
		playing = false, ---@type boolean
		timeline_selection = {first = 1, last = 1}, ---@type {first:integer, last:integer}
		lock_selection_to_frame = false, ---@type boolean
		show_pivot_state = 0,
		property_orders = property_orders,
		drag_start = vec(0,0),
		dragging = 0,
		
		on_animations_changed = nil, ---@type function?
		on_frames_changed = nil, ---@type function?
		on_frame_change = nil, ---@type function?
		on_properties_changed = nil, ---@type function?
		on_selection_changed = nil, ---@type function?
		on_events_changed = nil, ---@type function?
	}
	return setmetatable(state, m_editor_state)
end

return {
	new_state = new_state,
}
