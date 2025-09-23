--[[pod_format="raw",created="2025-04-08 23:03:23",modified="2025-04-08 23:03:23",revision=0]]
include"src/require.lua"

-- Constants
DT = 1/60

-- Dependencies
local Animation = require"src/animation"
local Gui = require"src/gui"
local Utils = require"src/utils"
local FileOps = require"src/file_ops"
local SpriteUtils = require"src/sprite_utils"
local AnimationManager = require"src/animation_manager"
local PropertyManager = require"src/property_manager"
local EventManager = require"src/event_manager"
local Playback = require"src/playback"

-- Editor state
ScreenSize = nil --- @type userdata
Lightest = 7
Darkest = 0

local animator --- @type Animator
local animations --- @type table<string,Animation>
local current_anim_key --- @type string
local gui_data
local gfx_cache --- @type table<number, [{bmp:userdata}]>
local palette --- @type userdata
local playing --- @type boolean
local timeline_selection --- @type {first:integer,last:integer}
local lock_selection_to_frame --- @type boolean

local on_animations_changed --- @type function
local on_frames_changed --- @type function
local on_frame_change --- @type function
local on_properties_changed --- @type function
local on_selection_changed --- @type function
local on_events_changed --- @type function

-- File operations moved to file_ops module

-- Palette and color utilities moved to sprite_utils module
-- Note: set_scanline_palette is kept as global function

-- Utility functions moved to utils module

-- Event functions moved to event_manager module

-- Accessors

-- Animation management functions moved to animation_manager module

-- Property management functions moved to property_manager module

-- Event management functions moved to event_manager module

-- Playback functions moved to playback module

-- Sprite functions moved to sprite_utils module

-- Picotron hooks
function _init()
	window{
		tabbed = true,
		icon = --[[pod_type="gfx"]]unpod("b64:bHo0ACkAAAAsAAAA8AJweHUAQyAICASABwAHAAcgFwYAYQA3AAcARwoAARAAcCAHAAcAB4A=")
	}
	
	on_event("gained_focus",function()
		-- There's a chance the gfx or pal files have been updated.
		gfx_cache = {}
		poke4(0x5000,fetch(DATP.."pal/0.pal"):get())
	end)

	local sw,sh = get_display():attribs()
	ScreenSize = vec(sw,sh)

	mkdir("/ram/cart/anm")

	-- File operations using modules
	local file_ops = FileOps
	local save_working_file = function() return file_ops.save_working_file(animations) end
	local load_working_file = function(item_1) 
		animations = file_ops.load_working_file(item_1)
	end

	wrangle_working_file(
		save_working_file,
		load_working_file,
		"/ram/cart/anm/0.anm"
	)

	current_anim_key = next(animations) or "new_1"
	animator = Animation.new_animator(animations[current_anim_key])
	playing = false
	timeline_selection = {first = 1,last = 1}
	
	-- Initialize managers with shared state
	local state = {
		animations = animations,
		current_anim_key = current_anim_key,
		animator = animator,
		timeline_selection = timeline_selection,
		playing = playing,
		lock_selection_to_frame = lock_selection_to_frame,
		on_animations_changed = function() end, -- will be set below
		on_frames_changed = function() end,
		on_frame_change = function() end,
		on_properties_changed = function() end,
		on_selection_changed = function() end,
		on_events_changed = function() end,
	}

	local animation_manager = AnimationManager.create_animation_manager(state)
	local property_manager = PropertyManager.create_property_manager(state)
	local event_manager = EventManager.create_event_manager(state)
	
	-- Update state with manager references
	state.animation_manager = animation_manager
	state.event_manager = event_manager
	local playback_manager = Playback.create_playback_manager(state)

	-- Clean events using the event manager
	event_manager.clean_events()

	palette = fetch("/ram/cart/pal/0.pal")
	if palette then
		poke4(0x5100,palette:get())
		SpriteUtils.find_binary_cols(palette)
	end
	poke4(0x5000,fetch(DATP.."pal/0.pal"):get())

	gfx_cache = {}
	
	local accessors = {
		-- Animation management
		set_frame = animation_manager.set_frame,
		insert_frame = animation_manager.insert_frame,
		remove_frame = animation_manager.remove_frame,

		get_animation_key = function() return current_anim_key end,
		set_animation_key = animation_manager.rename_animation,
		get_animation_keys = function()
			local keys = {}
			for k in pairs(animations) do
				add(keys,k)
			end
			return keys
		end,
		
		set_animation = animation_manager.set_animation,
		get_animation = function() return animations[current_anim_key] end,
		create_animation = animation_manager.create_animation,
		remove_animation = animation_manager.remove_animation,

		-- Property management
		get_property_strings = property_manager.get_property_strings,
		rename_property = property_manager.rename_property,
		set_property_by_string = property_manager.set_property_by_string,
		create_property = property_manager.create_property,
		remove_property = property_manager.remove_property,

		-- Event management
		get_event_strings = event_manager.get_event_strings,
		rename_event = event_manager.rename_event,
		set_event_by_string = event_manager.set_event_by_string,
		create_event = event_manager.create_event,
		remove_event = event_manager.remove_event,

		-- Playback controls
		get_playing = function() return playing end,
		set_playing = playback_manager.set_playing,
		get_timeline_selection = function() return timeline_selection end,
		set_timeline_selection = animation_manager.set_timeline_selection,
		select_frame = animation_manager.select_frame,
		
		previous_frame = playback_manager.previous_frame,
		next_frame = playback_manager.next_frame,
		first_frame = playback_manager.first_frame,
		last_frame = playback_manager.last_frame,

		-- Sprite utilities
		get_sprite = function(anim_spr) return SpriteUtils.get_sprite(anim_spr, gfx_cache, DATP) end,

		animator = animator,
	}

	gui_data = Gui.initialize(
		accessors
	)

	-- Connect callbacks to managers
	state.on_animations_changed = gui_data.on_animations_changed
	state.on_frames_changed = function()
		animation_manager.set_timeline_selection(timeline_selection.first,timeline_selection.last)
		gui_data.on_frames_changed()
	end
	state.on_frame_change = gui_data.on_frame_change
	state.on_properties_changed = gui_data.on_properties_changed
	state.on_selection_changed = gui_data.on_selection_changed
	state.on_events_changed = gui_data.on_events_changed

	-- Store manager references for use in _update
	local animation_manager_ref = animation_manager
	local playback_manager_ref = playback_manager
	
	-- Store manager functions in main scope for _update
	_G.animation_manager = animation_manager_ref
	_G.playback_manager = playback_manager_ref
	on_animations_changed = gui_data.on_animations_changed
	on_frames_changed = function()
		animation_manager.set_timeline_selection(timeline_selection.first,timeline_selection.last)
		gui_data.on_frames_changed()
	end
	on_frame_change = gui_data.on_frame_change
	on_properties_changed = gui_data.on_properties_changed
	on_selection_changed = gui_data.on_selection_changed
	on_events_changed = gui_data.on_events_changed
end

function _update()
	gui_data.gui:update_all()
	if playing then
		local last_frame = animator.frame_i
		animator:advance(DT)
		if animator.frame_i ~= last_frame then
			on_frame_change()
		end
	end

	if not gui_data.gui:get_keyboard_focus_element() then
		if keyp("left") then
			playback_manager.previous_frame()
		end
		if keyp("right") then
			playback_manager.next_frame()
		end
		if keyp("space") then
			playback_manager.set_playing(not playing)
		end
		if keyp("insert") then
			animation_manager.insert_frame()
		end
		if keyp("delete") then
			animation_manager.remove_frame()
		end
	end
	
	if lock_selection_to_frame then
		animation_manager.set_timeline_selection(animator.frame_i,animator.frame_i)
	end
end

function _draw()
	cls()
	gui_data.gui:draw_all()
end

include"src/error_explorer.lua"