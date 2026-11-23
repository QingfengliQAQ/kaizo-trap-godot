extends Node2D
## Root Game Orchestrator for Kaizo Trap (孔明の罠) - Godot 4.
## Connects Title/CRT frame, active KaizoRoom, KaiPlayer, Shader overlays
## (CRT / Blizzard / Glitch VRAM), Interactive Manual, ZhugeDOS 14, and Multi-Ending screens.

var current_room: KaizoRoom
var player: KaiPlayer
var cam: Camera2D
var hud: HudOverlay
var manual_ui: ManualOverlay
var terminal_ui: ZhugeDOSTerminal

# Shader overlay nodes
var shader_layer: CanvasLayer
var blizzard_rect: ColorRect
var glitch_rect: ColorRect
var crt_rect: ColorRect

# Ending / Title overlay
var overlay_layer: CanvasLayer
var title_panel: Control
var ending_panel: Control
var ending_title_lbl: Label
var ending_desc_lbl: Label

var shake_amount: float = 0.0
var glitch_burst: float = 0.0
var hitstop_timer: float = 0.0
var is_in_title: bool = true


func _ready() -> void:
	_setup_world()
	_setup_ui()
	_setup_shaders()
	_setup_title_and_ending_screens()

	# Load Stage 0 Living Room behind the title screen
	load_room("room_00")
	GameState.is_timer_running = false
	if DisplayServer.get_name() == "headless":
		_start_game(false)


func _setup_world() -> void:
	current_room = KaizoRoom.new()
	current_room.room_exit_reached.connect(_on_room_exit_reached)
	current_room.good_ending_triggered.connect(func(): _show_ending("good"))
	current_room.short_ending_triggered.connect(func(): _show_ending("short"))
	current_room.heart_cable_severed.connect(_on_heart_cable_severed)
	add_child(current_room)

	player = KaiPlayer.new()
	player.add_to_group("player")
	player.died.connect(_on_player_died)
	player.respawned.connect(_on_player_respawned)
	player.hitstop_requested.connect(_on_hitstop_requested)
	add_child(player)

	cam = Camera2D.new()
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	cam.position = Vector2(160, 90)
	cam.enabled = true
	add_child(cam)


func _setup_ui() -> void:
	hud = HudOverlay.new()
	hud.request_toggle_crt.connect(func(en): _set_crt_enabled(en))
	hud.request_save_state.connect(_save_assist_state)
	hud.request_load_state.connect(_load_assist_state)
	hud.request_toggle_arrange.connect(_toggle_arrange_mode)
	add_child(hud)

	manual_ui = ManualOverlay.new()
	manual_ui.annotation_701_clicked.connect(func():
		hud.show_toast("7M01S PRIMED! Right-click or touch Key Block in 1-3!", 4.0)
	)
	add_child(manual_ui)

	terminal_ui = ZhugeDOSTerminal.new()
	terminal_ui.warp_requested.connect(_on_terminal_warp)
	add_child(terminal_ui)


func _setup_shaders() -> void:
	shader_layer = CanvasLayer.new()
	shader_layer.layer = 15
	add_child(shader_layer)

	blizzard_rect = ColorRect.new()
	blizzard_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	blizzard_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blizzard_rect.color = Color(1, 1, 1, 0)
	if ResourceLoader.exists("res://shaders/blizzard.gdshader"):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/blizzard.gdshader")
		mat.set_shader_parameter("intensity", 0.0)
		blizzard_rect.material = mat
	shader_layer.add_child(blizzard_rect)

	glitch_rect = ColorRect.new()
	glitch_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glitch_rect.color = Color(1, 1, 1, 0)
	if ResourceLoader.exists("res://shaders/glitch_vram.gdshader"):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/glitch_vram.gdshader")
		mat.set_shader_parameter("glitch_intensity", 0.0)
		glitch_rect.material = mat
	shader_layer.add_child(glitch_rect)

	crt_rect = ColorRect.new()
	crt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_rect.color = Color(1, 1, 1, 0)
	if ResourceLoader.exists("res://shaders/crt_screen.gdshader"):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/crt_screen.gdshader")
		mat.set_shader_parameter("enable_crt", GameState.assist_crt_enabled)
		crt_rect.material = mat
	shader_layer.add_child(crt_rect)


func _setup_title_and_ending_screens() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 30
	add_child(overlay_layer)

	# Title Screen Overlay
	title_panel = Control.new()
	title_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tbg := ColorRect.new()
	tbg.color = Color(0.05, 0.05, 0.10, 0.86)
	tbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_panel.add_child(tbg)

	var t_jp := Label.new()
	t_jp.text = "孔明の罠  //  ZHUGEDOS_14"
	t_jp.position = Vector2(20, 26)
	t_jp.size = Vector2(280, 14)
	t_jp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_jp.add_theme_font_size_override("font_size", 8)
	t_jp.add_theme_color_override("font_color", Color("#ffd41c"))
	title_panel.add_child(t_jp)

	var t_main := Label.new()
	t_main.text = "KAIZO TRAP"
	t_main.position = Vector2(20, 42)
	t_main.size = Vector2(280, 28)
	t_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_main.add_theme_font_size_override("font_size", 20)
	t_main.add_theme_color_override("font_color", Color("#f6f8ff"))
	title_panel.add_child(t_main)

	var t_sub := Label.new()
	t_sub.text = "Godot 4 Playable Homage & Interactive ARG"
	t_sub.position = Vector2(20, 72)
	t_sub.size = Vector2(280, 12)
	t_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_sub.add_theme_font_size_override("font_size", 7)
	t_sub.add_theme_color_override("font_color", Color("#d0a0ff"))
	title_panel.add_child(t_sub)

	var btn_start := Button.new()
	btn_start.text = "START CLASSIC MODE"
	btn_start.position = Vector2(92, 92)
	btn_start.size = Vector2(136, 18)
	btn_start.add_theme_font_size_override("font_size", 7)
	btn_start.pressed.connect(func(): _start_game(false))
	title_panel.add_child(btn_start)

	var btn_assist := Button.new()
	btn_assist.text = "START ASSIST / TAS MODE"
	btn_assist.position = Vector2(92, 114)
	btn_assist.size = Vector2(136, 18)
	btn_assist.add_theme_font_size_override("font_size", 7)
	btn_assist.pressed.connect(func():
		GameState.set_difficulty(GameState.DifficultyMode.ASSIST)
		_start_game(false)
	)
	title_panel.add_child(btn_assist)

	var btn_manual := Button.new()
	btn_manual.text = "READ INSTRUCTION MANUAL [M]"
	btn_manual.position = Vector2(92, 136)
	btn_manual.size = Vector2(136, 18)
	btn_manual.add_theme_font_size_override("font_size", 7)
	btn_manual.pressed.connect(func(): manual_ui.open_manual(0))
	title_panel.add_child(btn_manual)

	overlay_layer.add_child(title_panel)

	# Ending Screen Overlay
	ending_panel = Control.new()
	ending_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ending_panel.visible = false
	var ebg := ColorRect.new()
	ebg.color = Color(0.03, 0.03, 0.06, 0.94)
	ebg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ending_panel.add_child(ebg)

	ending_title_lbl = Label.new()
	ending_title_lbl.position = Vector2(16, 36)
	ending_title_lbl.size = Vector2(288, 22)
	ending_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_title_lbl.add_theme_font_size_override("font_size", 10)
	ending_title_lbl.add_theme_color_override("font_color", Color("#ffd41c"))
	ending_panel.add_child(ending_title_lbl)

	ending_desc_lbl = Label.new()
	ending_desc_lbl.position = Vector2(24, 66)
	ending_desc_lbl.size = Vector2(272, 54)
	ending_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_desc_lbl.add_theme_font_size_override("font_size", 7)
	ending_desc_lbl.add_theme_color_override("font_color", Color("#f6f8ff"))
	ending_panel.add_child(ending_desc_lbl)

	var btn_cont := Button.new()
	btn_cont.text = "CONTINUE / ENTER ARRANGE MODE"
	btn_cont.position = Vector2(78, 128)
	btn_cont.size = Vector2(164, 18)
	btn_cont.add_theme_font_size_override("font_size", 7)
	btn_cont.pressed.connect(func():
		ending_panel.visible = false
		_start_game(true)
	)
	ending_panel.add_child(btn_cont)

	overlay_layer.add_child(ending_panel)


func _start_game(enable_arrange: bool) -> void:
	is_in_title = false
	title_panel.visible = false
	ending_panel.visible = false
	GameState.start_new_run(enable_arrange)
	load_room("room_01" if enable_arrange else "room_00")


func load_room(room_id: String) -> void:
	var spec := StageCatalog.get_room_spec(room_id)
	GameState.current_room = spec.get("title", room_id)
	current_room.build_from_spec(spec, GameState.arrange_mode)
	player.is_on_ice = current_room.is_ice_room
	player.set_spawn(current_room.spawn_pos)
	_update_biome_shaders()
	_update_biome_bgm(spec.get("bgm", "overworld"))


func _update_biome_bgm(bgm_key: String) -> void:
	match bgm_key:
		"ice_factory":
			AudioManager.play_bgm("res://assets/audio/bgm/ice_factory.wav", 132.0)
		"core_boss":
			AudioManager.play_bgm("res://assets/audio/bgm/core_boss.wav", 155.0)
		_:
			AudioManager.play_bgm("res://assets/audio/bgm/overworld_paradigm.wav", 140.0)


func _update_biome_shaders() -> void:
	if blizzard_rect and blizzard_rect.material is ShaderMaterial:
		var blizz := 0.85 if (current_room.biome == "ice" and GameState.arrange_mode) else (0.18 if current_room.biome == "ice" else 0.0)
		blizzard_rect.material.set_shader_parameter("intensity", blizz)
	if glitch_rect and glitch_rect.material is ShaderMaterial:
		var base_glitch := 0.28 if current_room.biome == "glitch_escape" else 0.0
		glitch_rect.material.set_shader_parameter("glitch_intensity", maxf(base_glitch, glitch_burst))


func _on_heart_cable_severed() -> void:
	glitch_burst = 0.9
	shake_amount = 6.0
	hud.show_toast("HEART CABLE SEVERED! BOSS GLITCHING — RUN TO THE FLAG!", 4.0)


func _on_hitstop_requested(duration: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	hitstop_timer = maxf(hitstop_timer, duration)
	Engine.time_scale = 0.05


func _set_crt_enabled(enabled: bool) -> void:
	if crt_rect and crt_rect.material is ShaderMaterial:
		crt_rect.material.set_shader_parameter("enable_crt", enabled)


func _toggle_arrange_mode() -> void:
	GameState.arrange_mode = not GameState.arrange_mode
	hud.show_toast("ARRANGE MODE: " + ("ON (2ND LOOP)" if GameState.arrange_mode else "OFF"))
	load_room(current_room.room_id)


func _on_player_died(world_pos: Vector2, death_type: String) -> void:
	GameState.record_death(current_room.room_id, world_pos, death_type)
	shake_amount = 4.5
	if death_type in ["glitch", "laser"]:
		glitch_burst = 0.75
	current_room.queue_redraw()


func _on_player_respawned(_spawn: Vector2) -> void:
	current_room.reset_traps()


func _on_room_exit_reached(next_room_id: String, is_kaizo_fakeout: bool) -> void:
	if is_kaizo_fakeout:
		# Iconic Victory Cutscene Kaizo Trap!
		glitch_burst = 1.0
		shake_amount = 7.0
		_show_ending("normal")
		return

	if next_room_id == "__TRUE_ENDING__":
		SecretManager.coconut_dodged_on_return = true
		SecretManager.unlock_ending("true")
		_show_ending("true")
		return

	call_deferred("load_room", next_room_id)


func _show_ending(ending_id: String) -> void:
	SecretManager.unlock_ending(ending_id)
	var info: Dictionary = SecretManager.ENDINGS.get(ending_id, {"title": ending_id, "desc": ""})
	ending_title_lbl.text = info["title"]
	ending_desc_lbl.text = "%s\n\nDeaths: %d  |  Time: %s  |  Endings Found: %d/%d" % [
		info["desc"],
		GameState.total_deaths,
		GameState.format_clock(),
		SecretManager.get_ending_count(),
		SecretManager.ENDINGS.size()
	]
	ending_panel.visible = true


func _on_terminal_warp(sector: String) -> void:
	if sector in StageCatalog.get_all_room_ids():
		terminal_ui.close_terminal()
		load_room(sector)
	elif sector in ["15243", "1-5-2-4-3"]:
		terminal_ui.close_terminal()
		_show_ending("nyan_whale")
	elif sector == "6":
		terminal_ui.close_terminal()
		_show_ending("sixth")


func _save_assist_state() -> void:
	if GameState.difficulty != GameState.DifficultyMode.ASSIST:
		hud.show_toast("Enable ASSIST MODE (F2) to use Save States!")
		return
	GameState.saved_state = {
		"room_id": current_room.room_id,
		"pos": player.global_position,
		"vel": player.velocity,
		"facing": player.facing,
	}
	hud.show_toast("STATE SAVED [F5]")


func _load_assist_state() -> void:
	if GameState.difficulty != GameState.DifficultyMode.ASSIST or GameState.saved_state.is_empty():
		return
	var st: Dictionary = GameState.saved_state
	if st["room_id"] != current_room.room_id:
		load_room(st["room_id"])
	player.global_position = st["pos"]
	player.velocity = st["vel"]
	player.facing = st["facing"]
	player.is_dead = false
	hud.show_toast("STATE LOADED [F7]")


func _process(delta: float) -> void:
	if hitstop_timer > 0.0:
		# Hitstop uses real unscaled frame time estimate
		hitstop_timer -= delta / maxf(Engine.time_scale, 0.05)
		if hitstop_timer <= 0.0:
			hitstop_timer = 0.0
			Engine.time_scale = float(GameState.assist_game_speed_pct) / 100.0 if GameState.difficulty == GameState.DifficultyMode.ASSIST else 1.0

	if shake_amount > 0.0:
		shake_amount = maxf(0.0, shake_amount - 18.0 * delta)
		cam.offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
	else:
		cam.offset = Vector2.ZERO

	if glitch_burst > 0.0:
		glitch_burst = maxf(0.0, glitch_burst - 1.6 * delta)
		if glitch_rect and glitch_rect.material is ShaderMaterial:
			var base_g := 0.28 if current_room.biome == "glitch_escape" else 0.0
			glitch_rect.material.set_shader_parameter("glitch_intensity", maxf(base_g, glitch_burst))

	# Out-of-bounds pit kill (or Celeste Invincibility Pit Bounce!)
	if not is_in_title and not player.is_dead and player.global_position.y > 192.0:
		player.kill("pit")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_manual"):
		if manual_ui.visible:
			manual_ui.close_manual()
		else:
			manual_ui.open_manual()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_terminal"):
		if terminal_ui.visible:
			terminal_ui.close_terminal()
		else:
			terminal_ui.open_terminal()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_F2:
		hud.toggle_assist_menu()
	elif event.is_action_pressed("quick_restart") and not is_in_title:
		player.respawn()
	elif event.is_action_pressed("save_state"):
		_save_assist_state()
	elif event.is_action_pressed("load_state"):
		_load_assist_state()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not is_in_title:
		# Diegetic CRT Inspect Cursor (Rebirth of lost YouTube Annotations!)
		var world_click := get_global_mouse_position()
		if current_room.handle_crt_inspect_click(world_click):
			hud.show_toast("ANNOTATION CLICKED: 7M01S KEY BLOCK!", 3.5)
		else:
			hud.show_toast("CRT INSPECT (%d, %d): No hidden annotation here." % [int(world_click.x), int(world_click.y)], 1.6)
