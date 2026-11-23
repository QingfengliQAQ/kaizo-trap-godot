class_name HudOverlay
extends CanvasLayer
## Pixel HUD + Full Celeste Assist Mode Menu (F2) + Live FPS Display + Stamina Indicator.
## Assist options match Celeste 1:1: Game Speed (100%..50%), Invincibility,
## Air Dashes (1 / 2 / Infinite), Infinite Stamina, Hidden Blocks, Save State, CRT toggle.

signal request_open_manual()
signal request_open_terminal()
signal request_toggle_crt(enabled: bool)
signal request_save_state()
signal request_load_state()
signal request_toggle_arrange()
signal request_toggle_character()
signal request_next_room()

var top_bar: Label
var fps_label: Label
var sub_bar: Label
var toast_label: Label
var toast_timer: float = 0.0
var assist_panel: Panel
var input_display_label: Label

var btn_mode: Button
var btn_speed: Button
var btn_invincible: Button
var btn_dashes: Button
var btn_stamina: Button
var btn_char: Button
var btn_inputs: Button
var btn_crt: Button


func _ready() -> void:
	layer = 10
	_build_ui()
	_refresh_assist_buttons()
	GameState.assist_changed.connect(_refresh_assist_buttons)
	SecretManager.secret_unlocked.connect(func(_id, title): show_toast("SECRET: " + title))
	SecretManager.ending_unlocked.connect(func(_id, title): show_toast("ENDING: " + title, 4.5))
	SecretManager.trigram_found.connect(func(tid):
		var info: Dictionary = SecretManager.TRIGRAMS[tid]
		show_toast("BAGUA %s %s (%d/8)" % [info["symbol"], info["name"], SecretManager.get_trigram_count()])
	)


func _build_ui() -> void:
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.05, 0.05, 0.09, 0.72)
	bar_bg.position = Vector2(0, 0)
	bar_bg.size = Vector2(320, 13)
	add_child(bar_bg)

	top_bar = Label.new()
	top_bar.position = Vector2(4, 1)
	top_bar.size = Vector2(268, 12)
	top_bar.add_theme_font_size_override("font_size", 7)
	top_bar.add_theme_color_override("font_color", Color("#f6f8ff"))
	add_child(top_bar)

	fps_label = Label.new()
	fps_label.position = Vector2(272, 1)
	fps_label.size = Vector2(44, 12)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.add_theme_font_size_override("font_size", 6)
	fps_label.add_theme_color_override("font_color", Color("#44eca8"))
	add_child(fps_label)

	sub_bar = Label.new()
	sub_bar.position = Vector2(4, 170)
	sub_bar.size = Vector2(312, 10)
	sub_bar.text = "[Space/Z] Jump  [X/J] 8-Way Dash  [Shift/E] Climb  [F2] Celeste Assist  [M] Manual  [F1] DOS"
	sub_bar.add_theme_font_size_override("font_size", 5)
	sub_bar.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0, 0.78))
	add_child(sub_bar)

	toast_label = Label.new()
	toast_label.position = Vector2(12, 16)
	toast_label.size = Vector2(296, 14)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 7)
	toast_label.add_theme_color_override("font_color", Color("#ffd41c"))
	toast_label.visible = false
	add_child(toast_label)

	input_display_label = Label.new()
	input_display_label.position = Vector2(214, 158)
	input_display_label.size = Vector2(102, 12)
	input_display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	input_display_label.add_theme_font_size_override("font_size", 6)
	input_display_label.add_theme_color_override("font_color", Color("#44eca8"))
	input_display_label.visible = false
	add_child(input_display_label)

	# Full Celeste Assist Mode Menu (F2)
	assist_panel = Panel.new()
	assist_panel.position = Vector2(162, 14)
	assist_panel.size = Vector2(152, 154)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	sb.border_color = Color("#a4e8ff")
	sb.set_border_width_all(1)
	assist_panel.add_theme_stylebox_override("panel", sb)
	assist_panel.visible = false
	add_child(assist_panel)

	var title := Label.new()
	title.text = "CELESTE ASSIST MODE (F2)"
	title.position = Vector2(6, 3)
	title.add_theme_font_size_override("font_size", 7)
	title.add_theme_color_override("font_color", Color("#a4e8ff"))
	assist_panel.add_child(title)

	btn_mode = _add_menu_btn(0, Callable(self, "_btn_toggle_mode"))
	btn_speed = _add_menu_btn(1, Callable(self, "_btn_cycle_speed"))
	btn_invincible = _add_menu_btn(2, Callable(self, "_btn_toggle_invincible"))
	btn_dashes = _add_menu_btn(3, Callable(self, "_btn_cycle_dashes"))
	btn_stamina = _add_menu_btn(4, Callable(self, "_btn_toggle_stamina"))
	btn_char = _add_menu_btn(5, Callable(self, "_btn_toggle_char"))
	var btn_skip := _add_menu_btn(6, Callable(self, "_btn_next_room"))
	btn_skip.text = "Chapter Warp: Next Room >>"
	var btn_save := _add_menu_btn(7, Callable(self, "_btn_save_state"))
	btn_save.text = "Save State [F5] / Load [F7]"
	var btn_arr := _add_menu_btn(8, Callable(self, "_btn_toggle_arrange"))
	btn_arr.text = "Toggle Arrange Mode (2nd Loop)"
	btn_crt = _add_menu_btn(9, Callable(self, "_btn_toggle_crt"))
	btn_inputs = null


func _add_menu_btn(row: int, cb: Callable) -> Button:
	var b := Button.new()
	b.position = Vector2(6, 16 + row * 13.5)
	b.size = Vector2(140, 12)
	b.add_theme_font_size_override("font_size", 6)
	b.pressed.connect(cb)
	assist_panel.add_child(b)
	return b


func _refresh_assist_buttons() -> void:
	if not btn_mode:
		return
	var is_assist := GameState.difficulty == GameState.DifficultyMode.ASSIST
	btn_mode.text = "Mode: %s" % ("ASSIST (ON)" if is_assist else "CLASSIC")
	btn_speed.text = "Game Speed: %d%% (100->50%%)" % GameState.assist_game_speed_pct
	btn_invincible.text = "Invincibility: %s" % ("ON (SHIELD)" if GameState.assist_invincible else "OFF")
	var d_txt := "INFINITE" if GameState.assist_air_dashes >= 99 else str(GameState.assist_air_dashes)
	btn_dashes.text = "Air Dashes: %s" % d_txt
	btn_stamina.text = "Infinite Stamina: %s" % ("ON" if GameState.assist_infinite_stamina else "OFF")
	btn_char.text = "Character: %s (Swap)" % GameState.playable_character.to_upper()
	btn_crt.text = "CRT Scanlines: %s" % ("ON" if GameState.assist_crt_enabled else "OFF")


func _btn_toggle_char() -> void:
	var ch := GameState.toggle_playable_character()
	request_toggle_character.emit()
	show_toast("CHARACTER: " + ch.to_upper())


func _btn_next_room() -> void:
	request_next_room.emit()


func _btn_toggle_mode() -> void:
	var next := GameState.DifficultyMode.ASSIST if GameState.difficulty == GameState.DifficultyMode.CLASSIC else GameState.DifficultyMode.CLASSIC
	GameState.set_difficulty(next)
	show_toast("MODE: " + ("CELESTE ASSIST" if next == GameState.DifficultyMode.ASSIST else "CLASSIC"))


func _btn_cycle_speed() -> void:
	var pct := GameState.cycle_game_speed(1)
	show_toast("GAME SPEED: %d%%" % pct)


func _btn_toggle_invincible() -> void:
	var on := GameState.toggle_invincibility()
	show_toast("INVINCIBILITY: " + ("ON (HAZARD BOUNCE)" if on else "OFF"))


func _btn_cycle_dashes() -> void:
	var d := GameState.cycle_air_dashes()
	show_toast("AIR DASHES: " + ("INFINITE" if d >= 99 else str(d)))


func _btn_toggle_stamina() -> void:
	var on := GameState.toggle_infinite_stamina()
	show_toast("INFINITE STAMINA: " + ("ON" if on else "OFF"))


func _btn_toggle_hidden() -> void:
	GameState.set_difficulty(GameState.DifficultyMode.ASSIST)
	GameState.assist_show_hidden_blocks = not GameState.assist_show_hidden_blocks
	_refresh_assist_buttons()
	show_toast("HIDDEN BLOCKS: " + ("VISIBLE" if GameState.assist_show_hidden_blocks else "HIDDEN"))


func _btn_toggle_inputs() -> void:
	GameState.assist_show_input_display = not GameState.assist_show_input_display
	input_display_label.visible = GameState.assist_show_input_display
	_refresh_assist_buttons()


func _btn_save_state() -> void:
	request_save_state.emit()


func _btn_toggle_arrange() -> void:
	request_toggle_arrange.emit()


func _btn_toggle_crt() -> void:
	GameState.assist_crt_enabled = not GameState.assist_crt_enabled
	request_toggle_crt.emit(GameState.assist_crt_enabled)
	_refresh_assist_buttons()


func show_toast(msg: String, duration: float = 2.8) -> void:
	toast_label.text = msg
	toast_label.visible = true
	toast_timer = duration


func toggle_assist_menu() -> void:
	assist_panel.visible = not assist_panel.visible
	_refresh_assist_buttons()


func _process(delta: float) -> void:
	var loop_tag := " [2ND]" if GameState.arrange_mode else ""
	var assist_tag := ""
	if GameState.difficulty == GameState.DifficultyMode.ASSIST:
		var flags := "%d%%" % GameState.assist_game_speed_pct
		if GameState.assist_invincible:
			flags += " INV"
		if GameState.assist_air_dashes >= 99:
			flags += " ∞D"
		elif GameState.assist_air_dashes == 2:
			flags += " 2D"
		assist_tag = " [A:%s]" % flags
	var key_tag := " [KEY]" if GameState.has_key("stage1_key") else ""
	top_bar.text = "%s%s%s | D:%d | %s | ☰:%d/8%s" % [
		GameState.current_room.to_upper(),
		loop_tag,
		assist_tag,
		GameState.total_deaths,
		GameState.format_clock(),
		SecretManager.get_trigram_count(),
		key_tag
	]
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()

	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_label.visible = false

	if GameState.assist_show_input_display:
		var s := ""
		s += "L" if Input.is_action_pressed("move_left") else "."
		s += "R" if Input.is_action_pressed("move_right") else "."
		s += "U" if Input.is_action_pressed("move_up") else "."
		s += "D" if Input.is_action_pressed("crouch") else "."
		s += " J" if Input.is_action_pressed("jump") else " ."
		s += "X" if Input.is_action_pressed("slide") else "."
		s += "G" if Input.is_action_pressed("grab") else "."
		input_display_label.text = s
