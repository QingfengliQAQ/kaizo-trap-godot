class_name ManualOverlay
extends CanvasLayer
## Authentic Kaizo Trap Retro Instruction Manual Viewer (Tab / M).
## Styled in canonical white paper + navy blue headers + orange schematic accents
## (matching manual_12..15.png), including the clickable 7M01S Key Block annotation!

signal closed()
signal annotation_701_clicked()

var current_page: int = 0
var root_panel: Panel
var header_label: Label
var body_label: RichTextLabel
var page_label: Label
var art_rect: TextureRect
var annotation_btn: Button
var footer_hint: Label

const PAGES := [
	{
		"header": "01 / KAIZO TRAP - WARNING",
		"body": "[color=#1c223e][b]CONSOLE HARDWARE LOG // UNIT #1983[/b]\n\n\"I was chosen from a large number of identical units and brought here. It makes no difference. My purpose is to provide the humans with a temporary distraction, a retreat.\"\n\n[color=#e8562a][b]WARRANTY VOID IF:[/b][/color]\n- Subject gets pulled into CRT monitor\n- Subject hits invisible Bagua blocks\n- Subject trusts any arrow pointing RIGHT[/color]",
		"show_art": false,
		"show_701": false
	},
	{
		"header": "02 / CONTROLLER (CELESTE x ACGT)",
		"body": "[color=#1c223e][b]DNA-ENCODED PRECISION CONTROLS[/b]\n\n[color=#e8562a]MOVE (WASD / Arrows)[/color]: 8-Way Aim & Walk/Run\n[color=#e8562a]'A' JUMP (Space / Z / K)[/color]: Jump, Wall Kick & Wall Bounce\n[color=#e8562a]'T' DASH (X / J)[/color]: 8-Way Celeste Air Dash!\n  (Hair turns [color=#266098]Cyan[/color] when spent, [color=#e8562a]Orange[/color] when ready)\n[color=#e8562a]'C/G' CLIMB (Shift / E / C / L)[/color]: Wall Climb & Shell Kick\n[color=#e8562a]ASSIST MODE (F2)[/color]: Game Speed 50-100%, Invincibility, ∞ Dash[/color]",
		"show_art": true,
		"show_701": false
	},
	{
		"header": "03 / CELESTE FLOW TECHNIQUES",
		"body": "[color=#1c223e][b]MASTERING THE FLOW[/b]\n\n1. [color=#e8562a]WAVE / SUPER DASH[/color]: Dash diagonally into ground + Jump for a huge speed burst & dash refill!\n2. [color=#e8562a]WALL BOUNCE[/color]: Dash UP beside a wall + Jump for massive vertical height!\n3. [color=#e8562a]GLITCH DREAM BLOCKS[/color]: Dash STRAIGHT INTO starry dark code blocks to phase through!\n4. [color=#e8562a]DASH CRYSTALS & ZIP BLOCKS[/color]: Green crystals refill Dash+Stamina; Zip Blocks fling you![/color]",
		"show_art": false,
		"show_701": false
	},
	{
		"header": "04 / KEY BLOCK & 7M01S CLUE",
		"body": "[color=#1c223e][b]KEYHOLE PEDESTAL MECHANISM[/b]\n\nCarry the silver key (hidden BELOW the misleading arrow signs!) to unlock the Key Block.\n\n[color=#e8562a][b]ANNOTATION ARCHIVE NOTE:[/b][/color]\nLong ago, viewers clicked the orange annotation box at [b]7M01S[/b] to break the loop.\nUse the [b]CRT Inspect Cursor (Right-Click)[/b] on the Key Block—or click the orange box below![/color]",
		"show_art": false,
		"show_701": true
	},
	{
		"header": "05 / ZHUGEDOS & CIPHERS",
		"body": "[color=#1c223e][b]ENGINEER BACKDOOR NOTES[/b]\n\nPress [color=#e8562a]` or F1[/color] to open [b]ZhugeDOS 14 (Z:\\>)[/b].\n\n- Check [b]DIR[/b] and [b]VER[/b] for the Volume Serial Hex\n- Collect all 8 [b]Bagua Trigrams[/b] hidden in stages\n- Enter the 4 controller bases with [b]DNA ????[/b]\n- Decode the void sequence: [color=#e8562a]1-5-2-4-3[/color]\n- Never run [color=#c21834]EDIT HATE.PHP[/color]... unless you dare.[/color]",
		"show_art": false,
		"show_701": false
	}
]


func _ready() -> void:
	layer = 20
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh_page()


func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.04, 0.04, 0.08, 0.72)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	root_panel = Panel.new()
	root_panel.position = Vector2(22, 12)
	root_panel.size = Vector2(276, 156)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f6f8ff")
	sb.border_color = Color("#1c223e")
	sb.set_border_width_all(2)
	root_panel.add_theme_stylebox_override("panel", sb)
	add_child(root_panel)

	# Navy header bar
	var header_bg := ColorRect.new()
	header_bg.color = Color("#1c223e")
	header_bg.position = Vector2(0, 0)
	header_bg.size = Vector2(276, 18)
	root_panel.add_child(header_bg)

	header_label = Label.new()
	header_label.position = Vector2(6, 2)
	header_label.size = Vector2(210, 14)
	header_label.add_theme_font_size_override("font_size", 8)
	header_label.add_theme_color_override("font_color", Color("#f6f8ff"))
	root_panel.add_child(header_label)

	page_label = Label.new()
	page_label.position = Vector2(218, 2)
	page_label.size = Vector2(52, 14)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	page_label.add_theme_font_size_override("font_size", 8)
	page_label.add_theme_color_override("font_color", Color("#f68636"))
	root_panel.add_child(page_label)

	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.fit_content = false
	body_label.position = Vector2(8, 22)
	body_label.size = Vector2(260, 112)
	body_label.add_theme_font_size_override("normal_font_size", 7)
	body_label.add_theme_font_size_override("bold_font_size", 7)
	root_panel.add_child(body_label)

	art_rect = TextureRect.new()
	art_rect.position = Vector2(188, 24)
	art_rect.size = Vector2(80, 80)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/manual/manual_controller.png"):
		art_rect.texture = load("res://assets/manual/manual_controller.png")
	root_panel.add_child(art_rect)

	# Clickable canonical orange 7M01S annotation box (ref_07.png!)
	annotation_btn = Button.new()
	annotation_btn.text = "[ 7M01S ] CLICK KEY BLOCK"
	annotation_btn.position = Vector2(72, 102)
	annotation_btn.size = Vector2(132, 20)
	annotation_btn.add_theme_font_size_override("font_size", 7)
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.96, 0.53, 0.21, 0.92)
	btn_sb.border_color = Color("#1c223e")
	btn_sb.set_border_width_all(1)
	annotation_btn.add_theme_stylebox_override("normal", btn_sb)
	annotation_btn.add_theme_color_override("font_color", Color("#1c223e"))
	annotation_btn.pressed.connect(_on_701_clicked)
	root_panel.add_child(annotation_btn)

	# Page navigation buttons
	var prev_btn := Button.new()
	prev_btn.text = "< PREV"
	prev_btn.position = Vector2(6, 136)
	prev_btn.size = Vector2(46, 16)
	prev_btn.add_theme_font_size_override("font_size", 7)
	prev_btn.pressed.connect(func(): turn_page(-1))
	root_panel.add_child(prev_btn)

	var next_btn := Button.new()
	next_btn.text = "NEXT >"
	next_btn.position = Vector2(224, 136)
	next_btn.size = Vector2(46, 16)
	next_btn.add_theme_font_size_override("font_size", 7)
	next_btn.pressed.connect(func(): turn_page(1))
	root_panel.add_child(next_btn)

	footer_hint = Label.new()
	footer_hint.text = "[A/D] Flip Page   [TAB/M/ESC] Close"
	footer_hint.position = Vector2(56, 139)
	footer_hint.size = Vector2(164, 12)
	footer_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_hint.add_theme_font_size_override("font_size", 6)
	footer_hint.add_theme_color_override("font_color", Color("#565e7e"))
	root_panel.add_child(footer_hint)


func open_manual(page_idx: int = -1) -> void:
	if page_idx >= 0:
		current_page = clampi(page_idx, 0, PAGES.size() - 1)
	visible = true
	get_tree().paused = true
	AudioManager.play_sfx("manual_flip", 0.05, -4.0)
	_refresh_page()


func close_manual() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


func turn_page(delta_page: int) -> void:
	current_page = wrapi(current_page + delta_page, 0, PAGES.size())
	AudioManager.play_sfx("manual_flip", 0.08, -5.0)
	_refresh_page()


func _refresh_page() -> void:
	var p: Dictionary = PAGES[current_page]
	header_label.text = p["header"]
	page_label.text = "P.%d/%d" % [current_page + 1, PAGES.size()]
	body_label.text = p["body"]
	art_rect.visible = bool(p["show_art"]) and art_rect.texture != null
	body_label.size.x = 176 if art_rect.visible else 260
	annotation_btn.visible = bool(p["show_701"])
	SecretManager.manual_pages_read[str(current_page)] = true


func _on_701_clicked() -> void:
	SecretManager.key_block_701_clicked = true
	SecretManager.unlock_secret("manual_701_click", "Clicked Manual 7M01S Annotation Box!")
	AudioManager.play_sfx("secret", 0.0, -2.0)
	annotation_btn.text = "7M01S PRIMED! TOUCH KEY BLOCK"
	annotation_701_clicked.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("toggle_manual") or event.is_action_pressed("ui_cancel"):
		close_manual()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		turn_page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		turn_page(1)
		get_viewport().set_input_as_handled()
