local Animation = require"src/animation"
local Timeline = require"src/editor/timeline"
local Animations = require"src/editor/animations"
local Properties = require"src/editor/properties"
local Events = require"src/editor/events"

---@param self EditorState
---@param value boolean
local function set_playing(self, value)
	if value then self.lock_selection_to_frame = true end
	self.playing = value
end

---@param animations table<string, Animation>
---@param palette userdata
---@return EditorState
local function new_state(animations, palette)
	local current_anim_key = next(animations) or "new_1"
	
	---@class EditorState
	---@field show_pivot_state
	---|0: Show
	---|1: Show when paused
	---|2: Hide
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
		
		set_playing = set_playing,
		
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
		
		initialize_events = Events.initialize_events,
		clean_events = Events.clean_events,
		get_event_strings = Events.get_event_strings,
		create_event = Events.create_event,
		remove_event = Events.remove_event,
		rename_event = Events.rename_event,
		set_event_by_string = Events.set_event_by_string,
		
		on_animations_changed = nil, ---@type function
		on_frames_changed = nil, ---@type function
		on_frame_change = nil, ---@type function
		on_properties_changed = nil, ---@type function
		on_selection_changed = nil, ---@type function
		on_events_changed = nil, ---@type function
	}
	return state
end

return {
	new_state = new_state,
}
