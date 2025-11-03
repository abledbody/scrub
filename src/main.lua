--[[pod_format="raw",created="2025-04-08 23:03:23",modified="2025-04-08 23:03:23",revision=0]]
include"src/require.lua"

------------------------------------Constants-------------------------------------
DT = 1 / 60

-----------------------------------Dependencies-----------------------------------

local EditorGui = require"src/gui/editor"
local Editor = require"src/editor/state"
local Graphics = require"src/graphics"

-----------------------------------Editor state-----------------------------------
ScreenSize = nil ---@type userdata
Lightest = 7
Darkest = 0

local state

---@return AppState
local function new_app_state(editor_state, gfx_cache)
	local gui_data = EditorGui.initialize(editor_state, gfx_cache)
	
	editor_state.on_animations_changed = gui_data.on_animations_changed
	editor_state.on_frames_changed = function(self)
		self:set_timeline_selection(self.timeline_selection.first, self.timeline_selection.last)
		gui_data.on_frames_changed()
	end
	editor_state.on_frame_change = gui_data.on_frame_change
	editor_state.on_properties_changed = gui_data.on_properties_changed
	editor_state.on_selection_changed = gui_data.on_selection_changed
	editor_state.on_events_changed = gui_data.on_events_changed
	
	---@class AppState
	local state = {
		editor = editor_state,
		gui_data = gui_data,
	}
	return state
end

--------------------------------Picotron callbacks--------------------------------
function _init()
	window{
		tabbed = true,
		icon = --[[pod_type="gfx"]] unpod("b64:bHo0ACkAAAAsAAAA8AJweHUAQyAICASABwAHAAcgFwYAYQA3AAcARwoAARAAcCAHAAcAB4A=")
	}
	
	local sw, sh = get_display():attribs()
	ScreenSize = vec(sw, sh)
	
	mkdir("/ram/cart/anm")
	
	local palette = fetch("/ram/cart/pal/0.pal")
	if palette then
		poke4(0x5100, palette:get())
		Graphics.find_binary_cols(palette)
	end
	poke4(0x5000, fetch(DATP .. "pal/0.pal"):get())
	
	local editor_state
	local gfx_cache = {}

	---@return table<string, Animation>
	local function save_working_file()
		return editor_state.animations
	end

	---@param item_1 table<string, Animation>?
	local function load_working_file(item_1)
		if item_1 and type(item_1) ~= "table" then
			notify("Failed to load working file.")
			item_1 = nil
		end
		editor_state = Editor.new_state(item_1 or {animation_1 = {sprite = {0}, duration = {0.1}}}, palette)
		state = new_app_state(editor_state, gfx_cache)
		editor_state:clean_events()
	end
	
	wrangle_working_file(
		save_working_file,
		load_working_file,
		"/ram/cart/anm/0.anm"
	)
	
	on_event("gained_focus", function()
		--There's a chance the gfx or pal files have been updated.
		gfx_cache = {}
		poke4(0x5000, fetch(DATP .. "pal/0.pal"):get())
	end)
end

function _update()
	state.gui_data.gui:update_all()
	local editor = state.editor
	local animator = editor.animator
	
	if state.editor.playing then
		local last_frame = animator.frame_i
		animator:advance(DT)
		if animator.frame_i ~= last_frame then
			editor:on_frame_change()
		end
	end
	
	if not state.gui_data.gui:get_keyboard_focus_element() then
		if keyp("left") then
			editor:previous_frame()
		end
		if keyp("right") then
			editor:next_frame()
		end
		if keyp("space") then
			editor:set_playing(not editor.playing)
		end
		if keyp("insert") then
			editor:insert_frame()
		end
		if keyp("delete") then
			editor:remove_frame()
		end
	end
	
	if editor.lock_selection_to_frame then
		editor:set_timeline_selection(animator.frame_i, animator.frame_i)
	end
end

function _draw()
	cls()
	state.gui_data.gui:draw_all()
end

include"src/error_explorer.lua"
