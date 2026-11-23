class_name AmmoniteShell
extends CharacterBody2D
## Canonical coiled metallic ammonite shell with glowing orange center (ref_25.png).
## Supports Kai picking it up, kicking forward (Right+C), kicking upward (Up+C),
## and bouncing off the shell midair for authentic Kaizo Shell Jumps!

var is_held: bool = false
var is_kicked: bool = false
var spawn_pos: Vector2 = Vector2.ZERO
var pickup_cooldown: float = 0.0
var stomp_area: Area2D
var shell_tex: Texture2D = null


func _ready() -> void:
	add_to_group("shells")
	spawn_pos = global_position
	collision_layer = 16  # Interactive
	collision_mask = 1 | 8  # World | KaizoHidden

	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 6.0
	shape.shape = circ
	add_child(shape)

	stomp_area = Area2D.new()
	stomp_area.collision_layer = 16
	stomp_area.collision_mask = 2  # Player
	var a_shape := CollisionShape2D.new()
	var a_rect := RectangleShape2D.new()
	a_rect.size = Vector2(14, 10)
	a_shape.shape = a_rect
	a_shape.position = Vector2(0, -3)
	stomp_area.add_child(a_shape)
	stomp_area.body_entered.connect(_on_player_overlap)
	add_child(stomp_area)

	if ResourceLoader.exists("res://assets/tilesets/overworld_objects.png"):
		shell_tex = load("res://assets/tilesets/overworld_objects.png")


func reset_shell() -> void:
	global_position = spawn_pos
	velocity = Vector2.ZERO
	is_held = false
	is_kicked = false
	pickup_cooldown = 0.0
	visible = true


func pickup_or_kick(player: KaiPlayer, aim_up: bool) -> void:
	if pickup_cooldown > 0.0:
		return
	if not is_kicked:
		is_held = true
		player.held_shell = self
		velocity = Vector2.ZERO
		AudioManager.play_sfx("key_get", 0.15, -6.0)
	else:
		# Kick mid-flight
		if aim_up:
			kick(Vector2(player.facing * 86.0, -215.0))
		else:
			kick(Vector2(player.facing * 205.0, -25.0))


func kick(impulse: Vector2) -> void:
	is_held = false
	is_kicked = true
	velocity = impulse
	pickup_cooldown = 0.16


func release_on_death() -> void:
	is_held = false
	is_kicked = false
	velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	pickup_cooldown = max(0.0, pickup_cooldown - delta)
	if is_held:
		queue_redraw()
		return

	velocity.y = min(velocity.y + 620.0 * delta, 280.0)
	if not is_kicked:
		velocity.x = move_toward(velocity.x, 0.0, 260.0 * delta)

	var prev_vx := velocity.x
	move_and_slide()

	if is_on_wall() and abs(prev_vx) > 20.0:
		velocity.x = -prev_vx * 0.85
		AudioManager.play_sfx("kaizo_block", 0.2, -7.0)
	if is_on_floor() and is_kicked and abs(velocity.y) < 10.0:
		velocity.x = move_toward(velocity.x, 0.0, 120.0 * delta)
		if abs(velocity.x) < 15.0:
			is_kicked = false

	queue_redraw()


func _on_player_overlap(body: Node) -> void:
	if is_held or pickup_cooldown > 0.0:
		return
	if body is KaiPlayer and not body.is_dead:
		# Shell Jump! If Kai is descending onto the shell, bounce high!
		if body.velocity.y > -20.0 and body.global_position.y <= global_position.y + 4.0:
			body.bounce_off_shell(-262.0)
			velocity.y = 65.0
			velocity.x *= 0.4
			pickup_cooldown = 0.14


func _draw() -> void:
	if shell_tex:
		# Cell (2, 1) -> col 2, row 1 in 4x3 16x16 sheet
		draw_texture_rect_region(shell_tex, Rect2(-8, -8, 16, 16), Rect2(32, 16, 16, 16))
		return
	# Crisp fallback coiled metallic ammonite shell with glowing orange center
	draw_circle(Vector2.ZERO, 6.5, Color("#0d0c14"))
	draw_circle(Vector2.ZERO, 5.5, Color("#646a7e"))
	draw_arc(Vector2.ZERO, 3.8, 0.0, TAU * 0.8, 12, Color("#aab2c6"), 1.2)
	draw_circle(Vector2.ZERO, 2.0, Color("#f68636"))
