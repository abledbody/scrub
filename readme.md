# Scrub
Scrub is an animation data editor for Picotron which allows you to make and preview `.anm` files.

## File format
The `.anm` file format consists of a table with string keys and values containing animations. Each animation contains string keys with arrays of data, each the same length. The only required key in an animation is `duration`, which is a series of numbers indicating the amount of time it takes for each frame to elapse. There is an optional `events` key, where the value is a dictionary of strings keys and arbitrary values, representing each event that occurs at the start of its respective frame.

Within the Scrub cart, the script src/animation.lua contains everything you need to play the animations in the `.anm` files in your own projects.

## Features
Scrub will automatically detect the properties `sprite` and `pivot`, and will show a sprite in the viewport that reflects them. It will also show any vectors with at least two dimensions as crosshairs.

Scrub supports properties and events with values that are:
- numbers, such as `3.5`
- userdata vectors, such as `(3.5,8)`
- strings, such as `foo`
- booleans, written as `true` or `false`
- nil, written as `nil` (properties only)

Scrub supports custom palettes in the same format that OkPal uses.

## Hotkeys
- `Space` - Play
- `Left` - Select last frame
- `Right` - Select next frame
- `Insert` - Insert a new frame
- `Delete` - Delete selected frames
- `Shift+Click` - Frame multi-select

## Planned features
- Automatic sprite sequences
- Allow editing 2D vectors and the pivot from the viewport
- Undo
- Custom playback preview speed
- Specify which properties are the sprite/pivot
- Show multiple sprites on the same frame