-- Playback controls for scrub

local function create_playback_manager(state)
	local animator = state.animator
	local playing = state.playing
	local on_frame_change = state.on_frame_change
	local animation_manager = state.animation_manager

	local function set_playing(value)
		state.playing = value
		playing = value
	end

	local function previous_frame()
		animation_manager.select_frame(animator.frame_i-1)
	end

	local function next_frame()
		animation_manager.select_frame(animator.frame_i+1)
	end

	local function first_frame()
		animation_manager.select_frame(1)
	end

	local function last_frame()
		local current_animation = animator.anim
		if current_animation then
			animation_manager.select_frame(#current_animation.duration)
		end
	end

	return {
		set_playing = set_playing,
		previous_frame = previous_frame,
		next_frame = next_frame,
		first_frame = first_frame,
		last_frame = last_frame,
	}
end

return {
	create_playback_manager = create_playback_manager,
}