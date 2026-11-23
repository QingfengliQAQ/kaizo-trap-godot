extends Node
## Deterministic frame-input recorder & TAS playback engine.
## Serves BOTH:
## 1) Headless automated verification (proving every Kaizo room is 100% beatable)
## 2) In-game Ghost / Death Montage & Input Display (homage to 3:32 TAS menu easter egg)

var is_playing_tas: bool = false
var tas_frames: Array = [] # Array of Dictionary {left, right, up, down, jump, slide, interact}
var tas_cursor: int = 0
var current_frame_input: Dictionary = {}

var is_recording: bool = false
var recorded_frames: Array = []


func start_tas(frames: Array) -> void:
	tas_frames = frames
	tas_cursor = 0
	is_playing_tas = true
	current_frame_input = {}


func stop_tas() -> void:
	is_playing_tas = false
	tas_cursor = 0
	current_frame_input = {}


func step_tas_frame() -> Dictionary:
	if not is_playing_tas:
		return {}
	if tas_cursor < tas_frames.size():
		current_frame_input = tas_frames[tas_cursor]
		tas_cursor += 1
	else:
		current_frame_input = {}
	return current_frame_input


func get_action_pressed(action_name: String) -> bool:
	if is_playing_tas:
		return bool(current_frame_input.get(action_name, false))
	return Input.is_action_pressed(action_name)


func get_action_just_pressed(action_name: String, prev_state: Dictionary) -> bool:
	if is_playing_tas:
		var now := bool(current_frame_input.get(action_name, false))
		var before := bool(prev_state.get(action_name, false))
		return now and not before
	return Input.is_action_just_pressed(action_name)


func get_action_just_released(action_name: String, prev_state: Dictionary) -> bool:
	if is_playing_tas:
		var now := bool(current_frame_input.get(action_name, false))
		var before := bool(prev_state.get(action_name, false))
		return (not now) and before
	return Input.is_action_just_released(action_name)


func sample_current_inputs() -> Dictionary:
	var actions := ["move_left", "move_right", "move_up", "crouch", "jump", "slide", "interact"]
	var snap := {}
	for a in actions:
		snap[a] = get_action_pressed(a)
	if is_recording:
		recorded_frames.append(snap)
	return snap
