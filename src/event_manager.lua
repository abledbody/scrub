-- Event management for scrub
local Utils = require"src/utils"

local function create_event_manager(state)
	local animations = state.animations
	local current_anim_key = state.current_anim_key
	local timeline_selection = state.timeline_selection
	local on_events_changed = state.on_events_changed

	local function initialize_events()
		local animation = animations[current_anim_key]
		if animation.events then return end

		local events = {}
		for i = 1,#animation.duration do
			events[i] = {}
		end
		animation.events = events
	end

	local function clean_events()
		local animation = animations[current_anim_key]
		local events = animation.events
		if not events then return end

		local event_found = false
		for i = 1,#animation.duration do
			if events[i] and next(events[i]) then event_found = true break end
		end

		if event_found then
			for i = 1,#animation.duration do
				if not events[i] then
					events[i] = {}
				end
			end
		else
			animation.events = nil
		end
	end

	local function get_event_strings()
		local events = animations[current_anim_key].events
		if not events then return {} end

		local event_strings = {}
		local frame_events = events[timeline_selection.first]
		if not frame_events then return {} end

		for k,v in pairs(frame_events) do
			add(event_strings,{key = k,value = Utils.value_to_string(v)})
		end
		return event_strings
	end

	local function create_event()
		local animation = animations[current_anim_key]
		if not animation.events then initialize_events() end
		local events = animation.events

		local key = Utils.next_name("new",function(key)
			for i in Utils.iterate_selection(timeline_selection) do
				local frame_events = events[i]
				if frame_events and frame_events[key] then return true end
			end
		end)

		for i in Utils.iterate_selection(timeline_selection) do
			if not events[i] then events[i] = {} end
			local frame_events = events[i]
			frame_events[key] = true
		end

		on_events_changed()
		return key
	end

	--- @param key string
	local function remove_event(key)
		local events = animations[current_anim_key].events
		if not events then return end

		for i in Utils.iterate_selection(timeline_selection) do
			local frame_events = events[i]
			if frame_events and frame_events[key] then
				frame_events[key] = nil
			end
		end

		clean_events()

		on_events_changed()
	end

	--- @param key string
	--- @param new_key string
	local function rename_event(key,new_key)
		local events = animations[current_anim_key].events
		if not events then return end

		-- Double loop to prevent mutation if the rename fails.
		for i in Utils.iterate_selection(timeline_selection) do
			local frame_events = events[i]
			if frame_events and frame_events[key] and frame_events[new_key] then
				notify("The "..new_key.." event already exists somewhere in the selection.")
				return
			end
		end

		for i in Utils.iterate_selection(timeline_selection) do
			local frame_events = events[i]
			if frame_events and frame_events[key] then
				frame_events[new_key] = frame_events[key]
				frame_events[key] = nil
			end
		end

		on_events_changed()
	end

	--- @param key string
	--- @param str string
	local function set_event_by_string(key,str)
		local events = animations[current_anim_key].events
		if not events then return end

		local value = Utils.string_to_value(str)
		if value == nil then return end

		for i in Utils.iterate_selection(timeline_selection) do
			local frame_events = events[i]
			if frame_events and frame_events[key] then
				frame_events[key] = value
			end
		end

		on_events_changed()
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
end

return {
	create_event_manager = create_event_manager,
}