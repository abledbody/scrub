# Scrub - Modular Architecture

This document describes the modular structure of the Scrub animation editor after the modularization refactoring.

## Module Overview

The main.lua file has been refactored from 706 lines to 257 lines (64% reduction) by extracting functionality into 7 focused modules:

### Core Modules

#### `src/utils.lua` (107 lines)
**Purpose**: Common utility functions for string/value conversion and iteration helpers.

**Exports**:
- `string_to_value(str)` - Converts string to appropriate data type (number, boolean, vector, etc.)
- `value_to_string(value)` - Converts values back to string representation
- `iterate_selection(timeline_selection)` - Iterator for selected timeline frames
- `next_name(basis, fetch)` - Generates unique names for new items
- `remove_trailing_zeros(str)` - String formatting utility

#### `src/file_ops.lua` (20 lines)
**Purpose**: Handles save/load operations for working files.

**Exports**:
- `save_working_file(animations)` - Saves animation data to file
- `load_working_file(item)` - Loads animation data from file with validation

#### `src/sprite_utils.lua` (76 lines)
**Purpose**: Graphics and sprite management utilities.

**Exports**:
- `set_scanline_palette()` - Sets palette for scanline ranges (global function)
- `find_binary_cols(palette)` - Finds lightest/darkest colors in palette
- `get_indexed_gfx(index, cache, DATP)` - Loads graphics files with caching
- `get_sprite(anim_spr, cache, DATP)` - Gets sprite bitmap data

### Manager Modules

#### `src/animation_manager.lua` (168 lines)
**Purpose**: Manages animation lifecycle, frames, and timeline selection.

**Exports**:
- `set_timeline_selection(first, last)` - Updates timeline selection
- `set_frame(frame_i)` - Sets current frame
- `select_frame(frame_i)` - Selects frame with keyboard modifiers
- `insert_frame()` - Adds new frame after selection
- `remove_frame()` - Removes selected frames
- `set_animation(key)` - Switches to different animation
- `rename_animation(name)` - Renames current animation
- `create_animation()` - Creates new animation with unique name
- `remove_animation(key)` - Deletes animation

#### `src/property_manager.lua` (82 lines)
**Purpose**: Manages animation frame properties (sprite, pivot, etc.).

**Exports**:
- `get_property_strings()` - Gets all properties for current frame
- `rename_property(key, new_key)` - Renames property
- `set_property_by_string(key, str)` - Sets property value from string
- `create_property()` - Creates new property
- `remove_property(key)` - Removes property

#### `src/event_manager.lua` (152 lines)
**Purpose**: Manages animation events that trigger at specific frames.

**Exports**:
- `get_event_strings()` - Gets events for current frame
- `create_event()` - Creates new event on selected frames
- `remove_event(key)` - Removes event from selected frames
- `rename_event(key, new_key)` - Renames event
- `set_event_by_string(key, str)` - Sets event value
- `initialize_events()` - Sets up event system for animation
- `clean_events()` - Removes empty event data

#### `src/playback.lua` (43 lines)
**Purpose**: Controls animation playback and frame navigation.

**Exports**:
- `set_playing(value)` - Start/stop animation playback
- `previous_frame()` - Navigate to previous frame
- `next_frame()` - Navigate to next frame
- `first_frame()` - Jump to first frame
- `last_frame()` - Jump to last frame

## Architecture Benefits

### Before Modularization
- Single 706-line main.lua file
- Mixed concerns and responsibilities
- Difficult to navigate and maintain
- Hard to test individual components

### After Modularization
- **Separation of Concerns**: Each module has a single, clear responsibility
- **Maintainability**: Much easier to locate and modify specific functionality
- **Testability**: Individual modules can be tested independently
- **Readability**: Smaller, focused files are easier to understand
- **Reusability**: Modules can potentially be reused in other projects

## Module Dependencies

```
main.lua
├── utils.lua (no dependencies)
├── file_ops.lua (no dependencies)
├── sprite_utils.lua (no dependencies)
├── animation_manager.lua → utils.lua
├── property_manager.lua → utils.lua
├── event_manager.lua → utils.lua
└── playback.lua → animation_manager.lua (via state)
```

## Integration Pattern

All modules follow a consistent pattern:
1. **Factory Functions**: Modules export factory functions that create manager instances
2. **Shared State**: Managers operate on shared state objects passed during creation
3. **Callback Integration**: Managers integrate with the GUI system via callback functions
4. **API Preservation**: The original API used by GUI components is maintained

This modular architecture makes the Scrub animation editor much more maintainable while preserving all existing functionality.