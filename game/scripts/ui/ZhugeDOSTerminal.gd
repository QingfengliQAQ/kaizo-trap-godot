class_name ZhugeDOSTerminal
extends CanvasLayer
## Authentic ZhugeDOS 14 (Z:\>) Console Overlay (` or F1).
## Recreates ref_39.png and connects players directly to SecretManager's ARG puzzles!

signal closed()
signal warp_requested(sector: String)

var output_box: RichTextLabel
var input_line: LineEdit


func _ready() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.03, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var frame := Panel.new()
	frame.position = Vector2(10, 8)
	frame.size = Vector2(300, 164)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#060808")
	sb.border_color = Color("#44eca8")
	sb.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", sb)
	add_child(frame)

	output_box = RichTextLabel.new()
	output_box.position = Vector2(6, 4)
	output_box.size = Vector2(288, 134)
	output_box.scroll_following = true
	output_box.add_theme_font_size_override("normal_font_size", 7)
	output_box.add_theme_color_override("default_color", Color("#d8ffe8"))
	output_box.text = (
		"continue (y/n)?Y\n\n"
		+ "Starting ZhugeDOS 14\n"
		+ "Version 1.08 (C)Copyright Kaizo Homage Project\n"
		+ "Type HELP for commands. Press ESC or F1 to exit.\n\n"
	)
	frame.add_child(output_box)

	var prompt_lbl := Label.new()
	prompt_lbl.text = "Z:\\>"
	prompt_lbl.position = Vector2(6, 143)
	prompt_lbl.size = Vector2(24, 16)
	prompt_lbl.add_theme_font_size_override("font_size", 7)
	prompt_lbl.add_theme_color_override("font_color", Color("#44eca8"))
	frame.add_child(prompt_lbl)

	input_line = LineEdit.new()
	input_line.position = Vector2(28, 140)
	input_line.size = Vector2(266, 18)
	input_line.placeholder_text = "dir | ver | bagua | hex ... | dna ... | edit hate.php"
	input_line.add_theme_font_size_override("font_size", 7)
	input_line.add_theme_color_override("font_color", Color("#44eca8"))
	input_line.text_submitted.connect(_on_command_submitted)
	frame.add_child(input_line)


func open_terminal() -> void:
	visible = true
	get_tree().paused = true
	AudioManager.play_sfx("dos_beep", 0.02, -5.0)
	input_line.grab_focus()


func close_terminal() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


func _on_command_submitted(cmd: String) -> void:
	input_line.clear()
	AudioManager.play_sfx("dos_beep", 0.08, -7.0)
	var trimmed := cmd.strip_edges()
	if trimmed.to_lower() in ["exit", "quit"]:
		close_terminal()
		return

	output_box.append_text("Z:\\>" + trimmed + "\n")
	var result := SecretManager.evaluate_zhugedos_command(trimmed)
	if result == "__CLEAR__":
		output_box.text = "Z:\\> (cleared)\n"
	else:
		output_box.append_text(result + "\n\n")

	if trimmed.to_lower().begins_with("warp "):
		warp_requested.emit(trimmed.substr(5).strip_edges())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("toggle_terminal") or event.is_action_pressed("ui_cancel"):
		close_terminal()
		get_viewport().set_input_as_handled()
