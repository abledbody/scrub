--- @class Animation A table containing a timing array and an arbitrary number of
--- other arrays from which to pull animation data. The indices of each array
--- correspond to a particular frame. If any data is at frame index -1, it will
--- be used for every frame of the animation.
--- @field duration [number] An array indicating how long it takes for each frame to elapse. Does not support index -1.
--- @field events [table<string,any>]? A table of events that occur at each frame. The keys are the event names, and the values are the data associated with that event.

--- @alias FrameEvents table<string,any> A table of events that occur at a specific frame.

--- Advances the time of the animator by dt.
--- @param self Animator The animator.
--- @param dt number The time to advance by.
local function advance(self, dt)
	self.frame_advances = 0
	self.ended = false
	
	local anim = self.anim
	if not self.anim then return end
	---@cast anim Animation
	
	local durations = anim.duration
	if self.frame_i > #durations then
		self.frame_i = 1
		self.ended = true
	end
	
	local events = {}
	
	self.frame_t += dt
	local duration = durations[self.frame_i] or durations[1]
	
	while self.frame_t > duration do
		self.frame_t -= duration
		
		self.frame_i += 1
		self.frame_advances += 1
		if self.frame_i > #durations then
			self.frame_i = 1
			self.ended = true
		end
		
		local frame_events = anim.events and anim.events[self.frame_i]
		if frame_events then add(events, frame_events) end
		
		duration = durations[self.frame_i]
	end
	
	self.events = events
end

--- Fetches the data in the current frame of the current animation for the given key.
--- If there is data at index -1 of the array at that key, that is returned regardless of the current frame index.
--- @param self Animator The animator.
--- @param key any The key to index the animation by.
--- @return any value The value fetched by the key.
local function fetch(self, key)
	local anim = self.anim
	if not anim then return nil end
	
	local arr = anim[key]
	if not arr then return nil end
	
	return arr[self.frame_i] or arr[-1]
end

--- Resets the animator to a specific frame.
--- @param self Animator The animator.
--- @param frame number? The frame to reset to. Defaults to 1.
local function reset(self, frame)
	self.frame_i = frame or 1
	self.frame_t = 0
	self.frame_advances = 0
	self.ended = false
	self.events = {self.anim.events and self.anim.events[self.frame_i]}
end

local c_animator = {
	__index = fetch,
}

--- Creates a new animator.
--- @param anim Animation? The animation to initialize this animator with.
--- @return Animator animator The newly created animator.
local function new_animator(anim)
	--- @class Animator Responsible for handling animation playback state and frame data access.
	--- @field anim Animation? The current animation, which indicates the timing and indexing.
	--- @field frame_i integer The index of the current frame.
	--- @field frame_t number The time that has elapsed since entering the current frame in seconds.
	--- @field frame_advances integer How many times the frame index has incremented during the last call to `advance`.
	--- @field ended boolean Whether or not the last call to `advance` advanced past the end of the animation.
	--- @field events [FrameEvents] An array of all events that have occurred since the last call to `advance`.
	--- @field [string] any Any value which is present in the current animation and frame, with a key that doesn't match any of Animator's fields or methods.
	local animator = {
		anim = anim,
		frame_i = 1,
		frame_t = 0,
		frame_advances = 0,
		ended = false,
		events = {},
		
		advance = advance, ---@type fun(self:Animator, dt:number)
		reset = reset, ---@type fun(self:Animator, frame?:number)
	}
	return setmetatable(animator, c_animator)
end

--- Generates an animation by a rule function.
--- @param length integer The number of frames to add to the animation.
--- @param rule fun(frame_i:integer):{duration:number} A function which takes in a frame index and returns a table with all the keys and values for that frame. The `duration` key is always required.
--- @return Animation animation An Animation generated via the provided rule.
local function animation_by_rule(length, rule)
	local animation = {}
	for frame_i = 1, length do
		for k, v in pairs(rule(frame_i)) do
			animation[k] = animation[k] or {}
			animation[k][frame_i] = v
		end
	end
	
	return animation
end

return {
	new_animator = new_animator,
	animation_by_rule = animation_by_rule,
}
