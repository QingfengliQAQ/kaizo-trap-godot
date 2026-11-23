extends Node
## Global game state, Celeste-style Assist Mode (Game Speed 50%-100% + Invincibility),
## persistent death splatter registry, stage progression, and Arrange Mode (2nd Loop).

signal death_recorded(pos: Vector2, death_type: String, total_deaths: int)
signal mode_changed(mode_name: String)
signal room_changed(stage_id: String, room_id: String)
signal arrange_mode_toggled(enabled: bool)
signal assist_changed()

enum DifficultyMode {
	CLASSIC,   # Authentic brutal Kaizo Trap experience
	ASSIST     # Celeste-style Assist Mode (Game Speed 50-100%, Invincibility, Hidden Blocks, Save States)
}

const GAME_SPEED_STEPS: Array[int] = [100, 90, 80, 70, 60, 50]

var difficulty: DifficultyMode = DifficultyMode.CLASSIC
var arrange_mode: bool = false
var current_stage: String = "stage1_overworld"
var current_room: String = "room_00"
var playable_character: String = "kai" # "kai" or "zo"

# Stats
var total_deaths: int = 0
var stage_deaths: int = 0
var run_elapsed_sec: float = 0.0
var is_timer_running: bool = false
var keys_collected: Dictionary = {}

# Persistent blood/splat decals per room (Super Meat Boy / Kaizo Trap death montage homage)
var room_splats: Dictionary = {}
const MAX_SPLATS_PER_ROOM := 180

# Celeste-style Assist Mode & TAS Practice toggles
var assist_game_speed_pct: int = 100 # 100, 90, 80, 70, 60, 50
var assist_invincible: bool = false
var assist_infinite_stamina: bool = false
var assist_air_dashes: int = 1 # 1 = normal, 2 = double dash, 99 = infinite air dashes
var assist_show_hidden_blocks: bool = false
var assist_show_input_display: bool = false
var assist_crt_enabled: bool = false # Default OFF for ultra-crisp 120Hz+ smoothness; toggleable in F2!

# Quick Save-State (F5 / F7)
var saved_state: Dictionary = {}

# Death Montage log
var death_history: Array[Dictionary] = []
const MAX_DEATH_HISTORY := 64


func _process(delta: float) -> void:
	if is_timer_running:
		run_elapsed_sec += delta


func start_new_run(enable_arrange: bool = false) -> void:
	arrange_mode = enable_arrange
	stage_deaths = 0
	run_elapsed_sec = 0.0
	is_timer_running = true
	keys_collected.clear()
	saved_state.clear()
	arrange_mode_toggled.emit(arrange_mode)


func set_difficulty(mode: DifficultyMode) -> void:
	difficulty = mode
	if mode == DifficultyMode.CLASSIC:
		assist_game_speed_pct = 100
		assist_invincible = false
		assist_infinite_stamina = false
		assist_air_dashes = 1
		assist_show_hidden_blocks = false
		Engine.time_scale = 1.0
	else:
		_apply_game_speed()
	mode_changed.emit("CLASSIC" if mode == DifficultyMode.CLASSIC else "ASSIST")
	assist_changed.emit()


func toggle_infinite_stamina() -> bool:
	if difficulty != DifficultyMode.ASSIST:
		set_difficulty(DifficultyMode.ASSIST)
	assist_infinite_stamina = not assist_infinite_stamina
	assist_changed.emit()
	return assist_infinite_stamina


func cycle_air_dashes() -> int:
	if difficulty != DifficultyMode.ASSIST:
		set_difficulty(DifficultyMode.ASSIST)
	match assist_air_dashes:
		1: assist_air_dashes = 2
		2: assist_air_dashes = 99
		_: assist_air_dashes = 1
	assist_changed.emit()
	return assist_air_dashes


func toggle_playable_character() -> String:
	playable_character = "zo" if playable_character == "kai" else "kai"
	assist_changed.emit()
	return playable_character


func get_max_dashes() -> int:
	if difficulty == DifficultyMode.ASSIST:
		return assist_air_dashes
	return 1


func has_infinite_stamina() -> bool:
	return difficulty == DifficultyMode.ASSIST and assist_infinite_stamina


func cycle_game_speed(step_dir: int = 1) -> int:
	if difficulty != DifficultyMode.ASSIST:
		set_difficulty(DifficultyMode.ASSIST)
	var idx: int = GAME_SPEED_STEPS.find(assist_game_speed_pct)
	if idx == -1:
		idx = 0
	idx = wrapi(idx + step_dir, 0, GAME_SPEED_STEPS.size())
	assist_game_speed_pct = GAME_SPEED_STEPS[idx]
	_apply_game_speed()
	assist_changed.emit()
	return assist_game_speed_pct


func set_game_speed_pct(pct: int) -> void:
	assist_game_speed_pct = clampi(pct, 50, 100)
	if assist_game_speed_pct < 100 and difficulty != DifficultyMode.ASSIST:
		difficulty = DifficultyMode.ASSIST
	_apply_game_speed()
	assist_changed.emit()


func toggle_invincibility() -> bool:
	if difficulty != DifficultyMode.ASSIST:
		set_difficulty(DifficultyMode.ASSIST)
	assist_invincible = not assist_invincible
	assist_changed.emit()
	return assist_invincible


func _apply_game_speed() -> void:
	Engine.time_scale = float(assist_game_speed_pct) / 100.0


func is_invincible() -> bool:
	return difficulty == DifficultyMode.ASSIST and assist_invincible


func record_death(room_key: String, world_pos: Vector2, death_type: String = "spike") -> void:
	total_deaths += 1
	stage_deaths += 1

	var splat_color := Color(0.76, 0.11, 0.21, 0.85)
	match death_type:
		"lava":
			splat_color = Color(0.96, 0.34, 0.21, 0.85)
		"electric", "laser":
			splat_color = Color(0.95, 0.96, 1.0, 0.75)
		"glitch":
			splat_color = Color(0.60, 0.24, 0.88, 0.85)
		"coconut":
			splat_color = Color(0.57, 0.37, 0.22, 0.9)

	if not room_splats.has(room_key):
		room_splats[room_key] = []
	var arr: Array = room_splats[room_key]
	arr.append({"pos": world_pos, "color": splat_color, "kind": death_type})
	if arr.size() > MAX_SPLATS_PER_ROOM:
		arr.pop_front()

	death_history.append({
		"room": room_key,
		"pos": world_pos,
		"kind": death_type,
		"time": run_elapsed_sec,
		"death_num": total_deaths
	})
	if death_history.size() > MAX_DEATH_HISTORY:
		death_history.pop_front()

	death_recorded.emit(world_pos, death_type, total_deaths)


func get_splats(room_key: String) -> Array:
	return room_splats.get(room_key, [])


func clear_splats() -> void:
	room_splats.clear()


func collect_key(key_id: String) -> void:
	keys_collected[key_id] = true


func has_key(key_id: String) -> bool:
	return bool(keys_collected.get(key_id, false))


func format_clock(seconds: float = -1.0) -> String:
	var s: float = run_elapsed_sec if seconds < 0.0 else seconds
	var mins := int(s) / 60
	var secs := int(s) % 60
	var cs := int((s - floor(s)) * 100.0)
	return "%02d:%02d.%02d" % [mins, secs, cs]
