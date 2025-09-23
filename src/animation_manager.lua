-- Animation management for scrub
local Utils = require"src/utils"

local function create_animation_manager(state)
	local animations = state.animations
	local current_anim_key = state.current_anim_key
	local animator = state.animator
	local timeline_selection = state.timeline_selection
	local playing = state.playing
	
	-- Callbacks
	local on_animations_changed = state.on_animations_changed
	local on_frames_changed = state.on_frames_changed
	local on_frame_change = state.on_frame_change
	local on_selection_changed = state.on_selection_changed

	local function set_timeline_selection(first,last)
		local length = #animations[current_anim_key].duration
		first = mid(1,first,length)
		last = mid(1,last,length)

		if first == timeline_selection.first
			and last == timeline_selection.last
		then return end

		timeline_selection.first = first
		timeline_selection.last = last
		on_selection_changed()
	end

	local function set_frame(frame_i)
		animator:reset(mid(1,frame_i,#animations[current_anim_key].duration))
		on_frame_change()
	end

	local function select_frame(frame_i)
		if not playing then
			set_frame(frame_i)
		end
		
		if key("shift") then
			local sel_first = timeline_selection.first
			set_timeline_selection(sel_first,frame_i)
		else
			set_timeline_selection(frame_i,frame_i)
		end
		state.lock_selection_to_frame = false
	end

	local function insert_frame()
		if playing then return end
		local animation = animations[current_anim_key]

		local sel_last = timeline_selection.last

		for k,v in pairs(animation) do
			if k == "events" then
				add(v,{},sel_last+1)
			else
				add(v,v[sel_last],sel_last+1)
			end
		end

		select_frame(sel_last+1)
		on_frames_changed()
	end

	local function remove_frame()
		if playing then return end
		local animation = animations[current_anim_key]
		
		local sel_first,sel_last = timeline_selection.first,timeline_selection.last
		if sel_first > sel_last then
			sel_first,sel_last = sel_last,sel_first
		end

		for _,v in pairs(animation) do
			for i = sel_last,sel_first,-1 do
				if #v == 1 then break end
				deli(v,i)
			end
		end

		-- Clean events if we have an event manager reference
		if state.event_manager then
			state.event_manager.clean_events()
		end
		
		state.playing = false
		playing = false

		select_frame(sel_first)
		-- Have to trigger this manually, because technically the selection is still
		-- pointing to the same indices.
		on_selection_changed()

		on_frames_changed()
	end

	--- @param key string The key of the animation to switch to.
	local function set_animation(key)
		animator.anim = animations[key]
		state.current_anim_key = key
		current_anim_key = key
		set_timeline_selection(1,1)
		on_selection_changed()
		set_frame(1)
		on_frames_changed()
	end

	--- Renames the current animation to the given name.
	--- @param name string The new name for the current animation.
	local function rename_animation(name)
		if animations[name] then return end
		animations[name],animations[current_anim_key] = animations[current_anim_key],nil
		state.current_anim_key = name
		current_anim_key = name

		on_animations_changed()
	end

	--- Creates a new animation with a unique name and sets it as the current animation.
	--- @return string anim_name The name of the newly created animation.
	local function create_animation()
		local anim_name = Utils.next_name("new",function(key) return animations[key] end)

		animations[anim_name] = {sprite = {0}, duration = {0.1}}
		set_animation(anim_name)

		on_animations_changed()
		return anim_name
	end

	--- Removes the animation with the given key.
	--- @param key string The key of the animation to remove.
	local function remove_animation(key)
		if not animations[key] then return end

		if key == current_anim_key then
			local next_key = next(animations,key) or next(animations)
			animations[key] = nil
			if next_key and next_key ~= current_anim_key then
				set_animation(next_key)
			else
				set_animation(create_animation())
			end
		else
			animations[key] = nil
		end

		on_animations_changed()
	end

	return {
		set_timeline_selection = set_timeline_selection,
		set_frame = set_frame,
		select_frame = select_frame,
		insert_frame = insert_frame,
		remove_frame = remove_frame,
		set_animation = set_animation,
		rename_animation = rename_animation,
		create_animation = create_animation,
		remove_animation = remove_animation,
	}
end

return {
	create_animation_manager = create_animation_manager,
}