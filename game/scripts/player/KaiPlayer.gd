class_name KaiPlayer
extends CharacterBody2D
## 1:1 Celeste-aligned precision 2D platformer controller for Kai.
## Runs deterministic 120Hz physics with Godot physics interpolation for locked 120-240+ FPS fluidity!
## Features:
##   - Exact Celeste 8-Way Dash (45ms freeze-frame hitstop, 0.15s burst, 4px dash corner correction)
##   - Wave Dash / Hyper Dash, Super Dash, Wall Bounce, and Glitch Dream Block Phase-Through!
##   - Celeste Wall Grab & Climb with 110 Stamina (red sweat warning <20, Climb Jump, 3px Wall Kick grace)
##   - Jump Apex Anti-Gravity Hang (0.5x gravity near apex), 4px Ceiling Corner Correction, Fast-Fall
##   - Silky 8-frame Run Cycle (kai_run8.png) + Full-Display-Hz dynamic CelesteHair spring ponytail
##   - Full Celeste Assist Mode (Game Speed 50-100%, Invincibility Shield, 1/2/∞ Air Dashes, ∞ Stamina)

signal died(world_pos: Vector2, death_type: String)
signal respawned(spawn_pos: Vector2)
signal state_changed(new_state: String)
signal hitstop_requested(duration: float)

# === Exact Celeste Physics Ratios (scaled cleanly to 16px tile / 320x180 world) ===
@export var max_run_speed: float = 112.0
@export var run_accel: float = 1250.0
@export var run_reduce: float = 520.0
@export var air_mult: float = 0.68
@export var ice_friction: float = 140.0

@export var jump_speed: float = -246.0
@export var jump_h_boost: float = 42.0
@export var jump_cut_mult: float = 0.46
@export var gravity_normal: float = 960.0
@export var apex_threshold: float = 44.0
@export var apex_gravity_mult: float = 0.50
@export var max_fall_speed: float = 220.0
@export var fast_fall_speed: float = 315.0

@export var coyote_time: float = 0.10        # 6 frames at 60Hz (exact Celeste)
@export var jump_buffer_time: float = 0.10
@export var wall_jump_check_dist: float = 4.0
@export var wall_jump_vx: float = 158.0
@export var wall_jump_vy: float = -242.0
@export var wall_jump_lock_time: float = 0.12

# Celeste Climb & Stamina (exact 110 units)
@export var max_stamina: float = 110.0
@export var climb_up_speed: float = -58.0
@export var climb_down_speed: float = 82.0
@export var climb_up_cost: float = 45.45
@export var climb_still_cost: float = 10.0
@export var climb_jump_cost: float = 27.5
@export var wall_slide_speed: float = 44.0

# Celeste 8-Way Dash
@export var dash_speed: float = 268.0
@export var dash_end_speed: float = 166.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.19
@export var super_jump_vx: float = 225.0
@export var hyper_jump_vx: float = 260.0
@export var hyper_jump_vy: float = -188.0
@export var wall_bounce_vx: float = 178.0
@export var wall_bounce_vy: float = -274.0

# State
var facing: int = 1
var is_dead: bool = false
var is_on_ice: bool = false
var is_crouching: bool = false
var is_climbing: bool = false
var is_wall_sliding: bool = false
var is_dashing: bool = false
var is_dream_dashing: bool = false
var wall_dir: int = 0

var dashes_left: int = 1
var stamina: float = 110.0
var dash_dir: Vector2 = Vector2.RIGHT
var dash_timer: float = 0.0
var dash_cd_timer: float = 0.0
var dash_refill_flash: float = 0.0
var dream_block_active: Node2D = null

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_coyote_timer: float = 0.0
var wall_coyote_dir: int = 0
var wall_lock_timer: float = 0.0
var kick_anim_timer: float = 0.0
var death_timer: float = 0.0
var anim_clock: float = 0.0
var invuln_flash_timer: float = 0.0
var trail_timer: float = 0.0
var external_boost: Vector2 = Vector2.ZERO

# Smooth visual nodes (updated in _process at full display Hz!)
var visual_scale: Vector2 = Vector2.ONE
var dust_puffs: Array[Dictionary] = []
var afterimages: Array[Dictionary] = []

var spawn_position: Vector2 = Vector2(32, 120)
var held_shell: Node2D = null
var _prev_inputs: Dictionary = {}
var _current_state: String = "idle"
var _was_on_floor: bool = false
var _prev_vy: float = 0.0

var body_shape: CollisionShape2D
var stand_rect: RectangleShape2D
var crouch_rect: RectangleShape2D
var sprite: Sprite2D
var run_sprite: Sprite2D
var hair: Node2D = null
var ceiling_check_left: RayCast2D
var ceiling_check_center: RayCast2D
var ceiling_check_right: RayCast2D
var wall_check_left: RayCast2D
var wall_check_right: RayCast2D
var has_sheet_texture: bool = false
var has_run8_texture: bool = false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 8 | 32
	floor_snap_length = 3.5

	stand_rect = RectangleShape2D.new()
	stand_rect.size = Vector2(10, 18)
	crouch_rect = RectangleShape2D.new()
	crouch_rect.size = Vector2(12, 9)

	body_shape = CollisionShape2D.new()
	body_shape.shape = stand_rect
	body_shape.position = Vector2(0, -9)
	add_child(body_shape)

	# 3-ray ceiling sensor (4px Corner Correction) + generous 4px wall sensors
	ceiling_check_left = _make_ray(Vector2(-5, -14), Vector2(0, -7))
	ceiling_check_center = _make_ray(Vector2(0, -14), Vector2(0, -7))
	ceiling_check_right = _make_ray(Vector2(5, -14), Vector2(0, -7))
	wall_check_left = _make_ray(Vector2(-5, -10), Vector2(-wall_jump_check_dist, 0))
	wall_check_right = _make_ray(Vector2(5, -10), Vector2(wall_jump_check_dist, 0))

	# Dynamic full-refresh-rate Celeste Hair (renders right behind sprite!)
	if ResourceLoader.exists("res://scripts/player/CelesteHair.gd"):
		var hair_script: Script = load("res://scripts/player/CelesteHair.gd")
		if hair_script:
			hair = hair_script.new()
			hair.top_level = true
			hair.z_index = 2
			add_child(hair)

	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.position = Vector2(0, -12)
	sprite.z_index = 3
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	run_sprite = Sprite2D.new()
	run_sprite.centered = true
	run_sprite.position = Vector2(0, -12)
	run_sprite.z_index = 3
	run_sprite.visible = false
	run_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(run_sprite)

	_load_character_sheets()
	spawn_position = global_position
	refill_dash_and_stamina(false)


func _make_ray(origin: Vector2, target: Vector2) -> RayCast2D:
	var r := RayCast2D.new()
	r.position = origin
	r.target_position = target
	r.collision_mask = 1 | 8
	r.enabled = true
	add_child(r)
	return r


func _load_character_sheets() -> void:
	if ResourceLoader.exists("res://assets/sprites/kai_sheet.png"):
		var tex: Texture2D = load("res://assets/sprites/kai_sheet.png")
		if tex:
			sprite.texture = tex
			sprite.hframes = 4
			sprite.vframes = 3
			sprite.frame = 0
			has_sheet_texture = true
	if ResourceLoader.exists("res://assets/sprites/kai_run8.png"):
		var rtex: Texture2D = load("res://assets/sprites/kai_run8.png")
		if rtex:
			run_sprite.texture = rtex
			run_sprite.hframes = 4
			run_sprite.vframes = 2
			run_sprite.frame = 0
			has_run8_texture = true


func set_spawn(pos: Vector2) -> void:
	spawn_position = pos
	global_position = pos
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	is_dead = false
	is_crouching = false
	is_climbing = false
	is_dashing = false
	is_dream_dashing = false
	dream_block_active = null
	collision_mask = 1 | 8 | 32
	invuln_flash_timer = 0.0
	visual_scale = Vector2.ONE
	dust_puffs.clear()
	afterimages.clear()
	refill_dash_and_stamina(false)
	_apply_hitbox(false)
	if hair and hair.has_method("reset_to"):
		hair.reset_to(global_position + Vector2(-facing * 3, -17))


func refill_dash_and_stamina(with_flash: bool = true) -> void:
	var target_dashes: int = GameState.get_max_dashes()
	if dashes_left < target_dashes and with_flash:
		dash_refill_flash = 0.14
	dashes_left = max(dashes_left, target_dashes)
	stamina = max_stamina


func apply_zip_launch(launch_vel: Vector2) -> void:
	external_boost = launch_vel
	velocity = velocity + launch_vel
	refill_dash_and_stamina(true)


func _spawn_dust(local_pos: Vector2, count: int = 4, vel_bias: Vector2 = Vector2.ZERO, col: Color = Color(0.95, 0.96, 1.0, 0.85)) -> void:
	for i in count:
		dust_puffs.append({
			"pos": global_position + local_pos + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 1.0)),
			"vel": vel_bias + Vector2(randf_range(-26.0, 26.0), randf_range(-22.0, -4.0)),
			"life": randf_range(0.16, 0.28),
			"max_life": 0.28,
			"size": randf_range(1.6, 2.8),
			"color": col,
		})


func _spawn_afterimage(col: Color = Color(0.36, 0.90, 1.0, 0.55)) -> void:
	afterimages.append({
		"pos": global_position + Vector2(0, -12),
		"use_run8": run_sprite.visible,
		"frame": run_sprite.frame if run_sprite.visible else sprite.frame,
		"flip_h": facing < 0,
		"life": 0.17,
		"max_life": 0.17,
		"color": col,
	})


func _process(delta: float) -> void:
	# Render-rate smooth visual updates (runs at native 120-240+ FPS!)
	_update_particles(delta)
	visual_scale = visual_scale.lerp(Vector2.ONE, minf(1.0, delta * 20.0))
	_sync_sprite_transform()

	if hair and hair.has_method("set_anchor"):
		var anchor_y: float = -9.0 if is_crouching else -16.5
		var anchor_pos: Vector2 = global_position + Vector2(-facing * 3.5, anchor_y)
		var low_stam: bool = (stamina < 22.0) and (not GameState.has_infinite_stamina())
		hair.set_anchor(anchor_pos, facing, dashes_left, GameState.get_max_dashes(), low_stam, dash_refill_flash > 0.0)

	if not dust_puffs.is_empty() or not afterimages.is_empty() or GameState.is_invincible() or stamina < max_stamina:
		queue_redraw()


func _physics_process(delta: float) -> void:
	if ReplayManager.is_playing_tas:
		ReplayManager.step_tas_frame()

	invuln_flash_timer = maxf(0.0, invuln_flash_timer - delta)
	dash_cd_timer = maxf(0.0, dash_cd_timer - delta)
	dash_refill_flash = maxf(0.0, dash_refill_flash - delta)
	wall_lock_timer = maxf(0.0, wall_lock_timer - delta)
	kick_anim_timer = maxf(0.0, kick_anim_timer - delta)
	anim_clock += delta

	if is_dead:
		death_timer -= delta
		velocity.y += gravity_normal * 0.35 * delta
		global_position += velocity * delta
		if death_timer <= 0.0:
			respawn()
		return

	var inp := _read_inputs()
	var aim_x := float(int(inp.right) - int(inp.left))
	var aim_y := float(int(inp.down) - int(inp.up))
	if aim_x != 0.0 and wall_lock_timer <= 0.0 and not is_climbing and not is_dream_dashing:
		facing = int(signf(aim_x))

	# === DREAM DASH STATE (Glitch Dream Blocks — Celeste Ch.2!) ===
	if is_dream_dashing:
		_step_dream_dash(delta, inp)
		_update_animation(aim_x)
		_prev_inputs = inp.raw
		return

	# Floor / Landing / Refill
	if is_on_floor():
		coyote_timer = coyote_time
		if not is_dashing:
			refill_dash_and_stamina(dashes_left == 0)
		if not _was_on_floor:
			var impact := clampf(_prev_vy / 260.0, 0.35, 1.0)
			visual_scale = Vector2(1.0 + 0.25 * impact, 1.0 - 0.23 * impact)
			_spawn_dust(Vector2(0, -1), 5, Vector2(0, -8))
			AudioManager.play_sfx("land", 0.08, -10.0)
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
	_was_on_floor = is_on_floor()

	if inp.jump_just_pressed:
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)

	# Generous 4px wall detection
	var touching_left := wall_check_left.is_colliding()
	var touching_right := wall_check_right.is_colliding()
	wall_dir = 0
	if touching_left:
		wall_dir = -1
	elif touching_right:
		wall_dir = 1

	if wall_dir != 0 and not is_on_floor():
		wall_coyote_timer = 0.10
		wall_coyote_dir = wall_dir
	else:
		wall_coyote_timer = maxf(0.0, wall_coyote_timer - delta)

	# === INITIATE CELESTE 8-WAY DASH (X / J) ===
	var can_dash: bool = (dashes_left > 0 or GameState.get_max_dashes() >= 99) and dash_cd_timer <= 0.0
	if inp.dash_just_pressed and can_dash:
		_start_dash(Vector2(aim_x, aim_y))

	# === ACTIVE DASH STATE ===
	if is_dashing:
		_step_dash(delta, inp)
		_prev_vy = velocity.y
		_update_animation(aim_x)
		_prev_inputs = inp.raw
		return

	# === CROUCH / LOW CEILING CHECK ===
	var ceiling_blocked := ceiling_check_left.is_colliding() or ceiling_check_center.is_colliding() or ceiling_check_right.is_colliding()
	is_crouching = (inp.down and is_on_floor()) or (is_crouching and ceiling_blocked)
	_apply_hitbox(is_crouching)

	# === CELESTE WALL GRAB & CLIMB (Shift / E / C / L) ===
	var wants_climb: bool = inp.grab and wall_dir != 0 and (stamina > 0.0 or GameState.has_infinite_stamina()) and not is_crouching
	if wants_climb and not is_on_floor():
		is_climbing = true
		facing = wall_dir
		if aim_y < 0.0:
			velocity.y = climb_up_speed
			if not GameState.has_infinite_stamina():
				stamina = maxf(0.0, stamina - climb_up_cost * delta)
		elif aim_y > 0.0:
			velocity.y = climb_down_speed
		else:
			velocity.y = 0.0
			if not GameState.has_infinite_stamina():
				stamina = maxf(0.0, stamina - climb_still_cost * delta)
		velocity.x = float(wall_dir) * 16.0
	else:
		is_climbing = false

	# === HORIZONTAL MOVEMENT (Exact Celeste snappy ground + gentle air conservation) ===
	if not is_climbing and wall_lock_timer <= 0.0:
		var mult: float = 1.0 if is_on_floor() else air_mult
		var target_vx: float = 0.0 if is_crouching else (aim_x * max_run_speed)
		if is_on_floor() and is_on_ice:
			if aim_x != 0.0 and not is_crouching:
				velocity.x = move_toward(velocity.x, target_vx, run_accel * 0.38 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, ice_friction * delta)
		else:
			# Preserve momentum above max_run_speed when moving in the same direction (Celeste speed tech!)
			if absf(velocity.x) > max_run_speed and signf(velocity.x) == signf(aim_x) and aim_x != 0.0:
				velocity.x = move_toward(velocity.x, target_vx, run_reduce * mult * delta)
			else:
				velocity.x = move_toward(velocity.x, target_vx, run_accel * mult * delta)

	# === JUMP / CLIMB JUMP / WALL KICK ===
	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0 and not ceiling_blocked:
			velocity.y = jump_speed
			velocity.x += aim_x * jump_h_boost
			visual_scale = Vector2(0.76, 1.26)
			_spawn_dust(Vector2(0, -1), 5, Vector2(-aim_x * 16.0, -10.0))
			AudioManager.play_sfx("jump", 0.05, -4.0)
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
		elif is_climbing and aim_x != float(-wall_dir):
			# Celeste Climb Jump straight up!
			is_climbing = false
			velocity.y = jump_speed * 0.94
			if not GameState.has_infinite_stamina():
				stamina = maxf(0.0, stamina - climb_jump_cost)
			visual_scale = Vector2(0.78, 1.24)
			_spawn_dust(Vector2(wall_dir * 5, -8), 5, Vector2(-wall_dir * 18.0, -18.0))
			AudioManager.play_sfx("wall_jump", 0.06, -4.0)
			jump_buffer_timer = 0.0
		elif wall_coyote_timer > 0.0:
			# Crisp Celeste Wall Kick!
			is_climbing = false
			velocity.x = float(-wall_coyote_dir) * wall_jump_vx
			velocity.y = wall_jump_vy
			facing = -wall_coyote_dir
			wall_lock_timer = wall_jump_lock_time
			wall_coyote_timer = 0.0
			jump_buffer_timer = 0.0
			visual_scale = Vector2(0.78, 1.24)
			_spawn_dust(Vector2(wall_coyote_dir * 5, -9), 5, Vector2(-wall_coyote_dir * 32.0, -16.0))
			AudioManager.play_sfx("wall_jump", 0.05, -4.0)

	# Variable jump cut on early release
	if inp.jump_just_released and velocity.y < 0.0:
		velocity.y *= jump_cut_mult

	# Celeste 4px Ceiling Corner Correction when rising
	if velocity.y < -10.0 and not ceiling_check_center.is_colliding():
		var hit_l := ceiling_check_left.is_colliding()
		var hit_r := ceiling_check_right.is_colliding()
		if hit_l and not hit_r:
			global_position.x += 3.0
		elif hit_r and not hit_l:
			global_position.x -= 3.0

	# === GRAVITY WITH CELESTE APEX ANTI-GRAVITY HANG + FAST-FALL ===
	is_wall_sliding = (not is_on_floor()) and (not is_climbing) and wall_dir != 0 and velocity.y > 0.0 and (aim_x == float(wall_dir))
	if not is_climbing:
		if is_wall_sliding:
			velocity.y = minf(velocity.y + gravity_normal * 0.35 * delta, wall_slide_speed)
			if int(anim_clock * 20.0) % 4 == 0:
				_spawn_dust(Vector2(wall_dir * 5, -10), 1, Vector2(-wall_dir * 8.0, -8.0))
		else:
			var in_apex: bool = (not is_on_floor()) and absf(velocity.y) < apex_threshold and inp.jump
			var g: float = gravity_normal * (apex_gravity_mult if in_apex else 1.0)
			var cap: float = fast_fall_speed if (inp.down and velocity.y > 0.0) else max_fall_speed
			velocity.y = minf(velocity.y + g * delta, cap)

	# Optional Shell Kick synergy (E / C when near a shell!)
	if inp.interact_just_pressed:
		_handle_shell_action(inp.up)

	if held_shell and is_instance_valid(held_shell):
		held_shell.global_position = global_position + Vector2(facing * 10, -10)

	_prev_vy = velocity.y
	move_and_slide()

	# Check bonking Kaizo blocks from below
	if velocity.y <= 0.0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if col.get_normal().y > 0.6 and col.get_collider().has_method("on_hit_from_below"):
				col.get_collider().on_hit_from_below(self)

	_update_animation(aim_x)
	_prev_inputs = inp.raw


func _start_dash(aim: Vector2) -> void:
	is_dashing = true
	is_climbing = false
	dash_timer = dash_duration
	dash_cd_timer = dash_cooldown
	if GameState.get_max_dashes() < 99:
		dashes_left = max(0, dashes_left - 1)

	if aim == Vector2.ZERO:
		dash_dir = Vector2(float(facing), 0.0)
	else:
		dash_dir = aim.normalized()
		if aim.x != 0.0:
			facing = int(signf(aim.x))

	# Low crouch hitbox if dashing horizontally along floor under low arches!
	_apply_hitbox(is_on_floor() and dash_dir.y >= 0.0 and absf(dash_dir.x) > 0.5)

	velocity = dash_dir * dash_speed
	visual_scale = Vector2(1.32, 0.72) if absf(dash_dir.x) >= absf(dash_dir.y) else Vector2(0.72, 1.32)
	_spawn_dust(Vector2(0, -8), 7, -dash_dir * 38.0, Color(0.64, 0.95, 1.0, 0.9))
	_spawn_afterimage(Color(0.36, 0.90, 1.0, 0.65))
	hitstop_requested.emit(0.042) # Exact Celeste 3-frame dash freeze-frame!
	AudioManager.play_sfx("dash", 0.05, -3.0)


func _step_dash(delta: float, inp: Dictionary) -> void:
	dash_timer -= delta
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = 0.028
		_spawn_afterimage(Color(0.36, 0.90, 1.0, 0.52))

	velocity = dash_dir * dash_speed

	# Check for Celeste Super / Wave / Hyper Dash & Wall Bounce mid-dash!
	if jump_buffer_timer > 0.0:
		if is_on_floor() or coyote_timer > 0.0:
			is_dashing = false
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			_apply_hitbox(false)
			if dash_dir.y > 0.3:
				# CELESTE WAVE / HYPER DASH! Huge forward burst + instant dash refill!
				velocity.x = float(facing) * hyper_jump_vx
				velocity.y = hyper_jump_vy
				refill_dash_and_stamina(true)
				visual_scale = Vector2(1.34, 0.70)
			else:
				# CELESTE SUPER DASH!
				velocity.x = float(facing) * super_jump_vx
				velocity.y = jump_speed
				visual_scale = Vector2(1.22, 0.80)
			_spawn_dust(Vector2(-facing * 4, -2), 8, Vector2(-facing * 45.0, -18.0), Color(1.0, 0.88, 0.35, 0.95))
			AudioManager.play_sfx("jump", 0.03, -2.0)
			return
		elif dash_dir.y < -0.5 and wall_coyote_timer > 0.0:
			# CELESTE WALL BOUNCE! Massive vertical-away surge!
			is_dashing = false
			jump_buffer_timer = 0.0
			_apply_hitbox(false)
			velocity.x = float(-wall_coyote_dir) * wall_bounce_vx
			velocity.y = wall_bounce_vy
			facing = -wall_coyote_dir
			wall_lock_timer = 0.11
			visual_scale = Vector2(0.70, 1.36)
			_spawn_dust(Vector2(wall_coyote_dir * 5, -9), 9, Vector2(-wall_coyote_dir * 45.0, -28.0), Color(0.64, 0.95, 1.0, 0.95))
			AudioManager.play_sfx("wall_jump", 0.03, -2.0)
			return

	# Check entering a Glitch Dream Block!
	var probe_pos := global_position + Vector2(0, -9) + dash_dir * 10.0
	for blk in get_tree().get_nodes_in_group("dream_blocks"):
		if blk.has_method("contains_point") and blk.contains_point(probe_pos):
			_enter_dream_dash(blk)
			return

	# Dash Corner Correction (4px nudge around ceiling/ledge edges)
	if dash_dir.y < -0.3 and not ceiling_check_center.is_colliding():
		if ceiling_check_left.is_colliding() and not ceiling_check_right.is_colliding():
			global_position.x += 3.5
		elif ceiling_check_right.is_colliding() and not ceiling_check_left.is_colliding():
			global_position.x -= 3.5

	move_and_slide()

	# Also check if slide collision directly touched a Dream Block
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("dream_blocks"):
			_enter_dream_dash(collider)
			return

	if dash_timer <= 0.0:
		is_dashing = false
		_apply_hitbox(false)
		if dash_dir.y <= 0.0:
			velocity = dash_dir * dash_end_speed
		if is_on_floor():
			refill_dash_and_stamina(false)


func _enter_dream_dash(blk: Node2D) -> void:
	is_dashing = false
	is_dream_dashing = true
	dream_block_active = blk
	collision_mask = 0 # Phase cleanly through the starry Glitch Dream Block!
	velocity = dash_dir * (dash_speed * 0.92)
	AudioManager.play_sfx("dream_through", 0.04, -3.0)
	_spawn_dust(Vector2(0, -9), 8, -dash_dir * 20.0, Color(0.64, 0.35, 1.0, 0.95))


func _step_dream_dash(delta: float, _inp: Dictionary) -> void:
	global_position += velocity * delta
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = 0.025
		_spawn_afterimage(Color(0.82, 0.45, 1.0, 0.65))

	var center := global_position + Vector2(0, -9)
	var still_inside: bool = dream_block_active != null and is_instance_valid(dream_block_active) and dream_block_active.has_method("contains_point") and dream_block_active.contains_point(center)
	if not still_inside:
		# Burst out the far side with Celeste Dream Jump bonus + instant Dash & Stamina refill!
		is_dream_dashing = false
		dream_block_active = null
		collision_mask = 1 | 8 | 32
		refill_dash_and_stamina(true)
		velocity = dash_dir * (dash_speed * 0.82)
		if dash_dir.y >= -0.1:
			velocity.y = minf(velocity.y, -150.0) # Smooth upward arc out of dream block!
		visual_scale = Vector2(1.30, 0.74)
		_spawn_dust(Vector2(0, -9), 9, dash_dir * 32.0, Color(0.36, 0.95, 1.0, 0.95))
		AudioManager.play_sfx("crystal_refill", 0.06, -4.0)


func _update_particles(delta: float) -> void:
	for i in range(dust_puffs.size() - 1, -1, -1):
		var d: Dictionary = dust_puffs[i]
		d["life"] = float(d["life"]) - delta
		if float(d["life"]) <= 0.0:
			dust_puffs.remove_at(i)
		else:
			d["pos"] = Vector2(d["pos"]) + Vector2(d["vel"]) * delta
			d["vel"] = Vector2(d["vel"]) * 0.88

	for i in range(afterimages.size() - 1, -1, -1):
		var a: Dictionary = afterimages[i]
		a["life"] = float(a["life"]) - delta
		if float(a["life"]) <= 0.0:
			afterimages.remove_at(i)


func _sync_sprite_transform() -> void:
	var active_sp: Sprite2D = run_sprite if (run_sprite.visible and has_run8_texture) else sprite
	active_sp.scale = visual_scale
	active_sp.position = Vector2(0, -12.0 * visual_scale.y)
	var mod := Color.WHITE
	if invuln_flash_timer > 0.0:
		mod = Color(0.64, 0.95, 1.0, 0.9) if (int(anim_clock * 24.0) % 2 == 0) else Color(1.0, 0.92, 0.45, 0.95)
	elif dash_refill_flash > 0.0:
		mod = Color(1.4, 1.4, 1.4, 1.0)
	elif stamina < 22.0 and is_climbing and not GameState.has_infinite_stamina() and (int(anim_clock * 16.0) % 2 == 0):
		mod = Color(1.0, 0.55, 0.55, 1.0)
	sprite.modulate = mod
	run_sprite.modulate = mod


func _handle_shell_action(aim_up: bool) -> void:
	kick_anim_timer = 0.15
	if held_shell and is_instance_valid(held_shell):
		var s = held_shell
		held_shell = null
		if aim_up:
			s.kick(Vector2(facing * 86.0, -218.0))
		else:
			s.kick(Vector2(facing * 208.0, -25.0))
		AudioManager.play_sfx("kaizo_block", 0.1, -4.0)
		return

	for node in get_tree().get_nodes_in_group("shells"):
		if node is Node2D and global_position.distance_to(node.global_position) < 22.0:
			if node.has_method("pickup_or_kick"):
				node.pickup_or_kick(self, aim_up)
				return


func bounce_off_shell(boost_vy: float = -265.0) -> void:
	velocity.y = boost_vy
	coyote_timer = 0.0
	refill_dash_and_stamina(true)
	visual_scale = Vector2(0.76, 1.28)
	_spawn_dust(Vector2(0, -2), 6, Vector2(0, -20), Color(0.96, 0.53, 0.21, 0.9))
	hitstop_requested.emit(0.035)
	AudioManager.play_sfx("spring", 0.06, -3.0)


func apply_spring(boost_vy: float = -310.0) -> void:
	velocity.y = boost_vy
	is_dashing = false
	refill_dash_and_stamina(true)
	visual_scale = Vector2(0.74, 1.30)
	_spawn_dust(Vector2(0, -2), 6, Vector2(0, -24))
	AudioManager.play_sfx("spring", 0.05, -2.0)


func apply_directional_spring(launch: Vector2) -> void:
	velocity = launch
	is_dashing = false
	is_climbing = false
	refill_dash_and_stamina(true)
	if launch.x != 0.0:
		facing = int(signf(launch.x))
		wall_lock_timer = 0.12
	visual_scale = Vector2(0.74, 1.30) if absf(launch.y) >= absf(launch.x) else Vector2(1.30, 0.74)
	_spawn_dust(Vector2(0, -8), 7, launch * 0.12)
	AudioManager.play_sfx("spring", 0.05, -2.0)


func kill(death_type: String = "spike") -> void:
	if is_dead or is_dream_dashing:
		return

	# Celeste-style Invincibility Mode
	if GameState.is_invincible():
		if invuln_flash_timer > 0.0 and death_type != "pit":
			return
		invuln_flash_timer = 0.45
		refill_dash_and_stamina(true)
		if death_type == "pit":
			global_position.y = minf(global_position.y, 174.0)
			velocity.y = -345.0
		else:
			velocity.y = -220.0
			velocity.x = -float(facing) * 90.0
		visual_scale = Vector2(0.80, 1.22)
		_spawn_dust(Vector2(0, -8), 8, Vector2(0, -18), Color(0.64, 0.91, 1.0, 0.95))
		AudioManager.play_sfx("spring", 0.12, -5.0)
		return

	is_dead = true
	is_dashing = false
	is_climbing = false
	death_timer = 0.22
	is_crouching = false
	if held_shell and is_instance_valid(held_shell):
		held_shell.release_on_death()
		held_shell = null

	velocity = Vector2(-facing * 65.0, -145.0)
	hitstop_requested.emit(0.045)

	match death_type:
		"coconut":
			SecretManager.coconut_death_seen = true
			AudioManager.play_sfx("death_coconut", 0.05, -2.0)
		"glitch", "laser":
			AudioManager.play_sfx("death_glitch", 0.08, -2.0)
		_:
			AudioManager.play_sfx("death_spike", 0.08, -2.0)

	died.emit(global_position + Vector2(0, -8), death_type)


func respawn() -> void:
	set_spawn(spawn_position)
	visual_scale = Vector2(0.84, 1.16)
	respawned.emit(spawn_position)


func _apply_hitbox(low: bool) -> void:
	if low:
		if body_shape.shape != crouch_rect:
			body_shape.shape = crouch_rect
			body_shape.position = Vector2(0, -4.5)
	else:
		if body_shape.shape != stand_rect:
			body_shape.shape = stand_rect
			body_shape.position = Vector2(0, -9.0)


func _read_inputs() -> Dictionary:
	var raw := ReplayManager.sample_current_inputs()
	return {
		"raw": raw,
		"left": ReplayManager.get_action_pressed("move_left"),
		"right": ReplayManager.get_action_pressed("move_right"),
		"up": ReplayManager.get_action_pressed("move_up"),
		"down": ReplayManager.get_action_pressed("crouch"),
		"jump": ReplayManager.get_action_pressed("jump"),
		"grab": ReplayManager.get_action_pressed("grab"),
		"jump_just_pressed": ReplayManager.get_action_just_pressed("jump", _prev_inputs),
		"jump_just_released": ReplayManager.get_action_just_released("jump", _prev_inputs),
		"dash_just_pressed": ReplayManager.get_action_just_pressed("slide", _prev_inputs),
		"interact_just_pressed": ReplayManager.get_action_just_pressed("interact", _prev_inputs),
	}


func _update_animation(move_dir: float) -> void:
	var st := "idle"
	var use_run8 := false
	var frame_idx := 0

	if is_dead:
		st = "dead"
		frame_idx = 10
	elif is_dashing or is_dream_dashing:
		st = "dash"
		frame_idx = 8 if absf(dash_dir.x) > absf(dash_dir.y) else 4
	elif kick_anim_timer > 0.0:
		st = "kick"
		frame_idx = 9
	elif is_climbing or is_wall_sliding:
		st = "wall_slide"
		frame_idx = 6
	elif not is_on_floor():
		st = "jump" if velocity.y < 0.0 else "fall"
		frame_idx = 4 if velocity.y < 0.0 else 5
	elif is_crouching:
		st = "crouch"
		frame_idx = 7
	elif absf(velocity.x) > 10.0 or move_dir != 0.0:
		st = "run"
		if has_run8_texture:
			use_run8 = true
			var speed_rate: float = clampf(absf(velocity.x) / max_run_speed, 0.55, 1.6) * 16.0
			frame_idx = int(anim_clock * speed_rate) % 8
		else:
			var run_frames := [1, 2, 3, 2]
			frame_idx = run_frames[int(anim_clock * 14.0) % run_frames.size()]
	else:
		st = "idle"
		frame_idx = 0

	if st != _current_state:
		_current_state = st
		state_changed.emit(st)

	if use_run8 and has_run8_texture:
		run_sprite.visible = true
		sprite.visible = false
		run_sprite.flip_h = (facing < 0)
		run_sprite.frame = frame_idx
	elif has_sheet_texture:
		run_sprite.visible = false
		sprite.visible = true
		sprite.flip_h = (facing < 0)
		sprite.frame = frame_idx
	else:
		run_sprite.visible = false
		sprite.visible = false


func _draw() -> void:
	# Dash / Wave-dash / Dream-dash afterimages
	for a: Dictionary in afterimages:
		var frac: float = clampf(float(a["life"]) / float(a["max_life"]), 0.0, 1.0)
		var lp: Vector2 = Vector2(a["pos"]) - global_position
		var tex: Texture2D = run_sprite.texture if (bool(a["use_run8"]) and has_run8_texture) else sprite.texture
		if tex:
			var f_idx: int = int(a["frame"])
			var src := Rect2((f_idx % 4) * 24, (f_idx / 4) * 24, 24, 24)
			var dst := Rect2(lp.x - 12.0, lp.y - 12.0, 24.0, 24.0)
			if bool(a["flip_h"]):
				dst = Rect2(lp.x + 12.0, lp.y - 12.0, -24.0, 24.0)
			var tint: Color = a["color"]
			tint.a *= frac
			draw_texture_rect_region(tex, dst, src, tint)

	# Pixel dust puffs
	for d: Dictionary in dust_puffs:
		var frac: float = clampf(float(d["life"]) / float(d["max_life"]), 0.0, 1.0)
		var lp: Vector2 = Vector2(d["pos"]) - global_position
		var sz: float = float(d["size"]) * frac
		var c: Color = d["color"]
		c.a *= frac
		draw_rect(Rect2(lp - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), c)

	# Subtle Celeste Stamina mini-gauge when climbing below 100%
	if stamina < max_stamina - 1.0 and not GameState.has_infinite_stamina():
		var pct := clampf(stamina / max_stamina, 0.0, 1.0)
		var bar_col := Color("#f64830") if stamina < 22.0 else Color("#44eca8")
		draw_rect(Rect2(-7, -25, 14, 2.5), Color(0.05, 0.05, 0.1, 0.8))
		draw_rect(Rect2(-6.5, -24.5, 13.0 * pct, 1.5), bar_col)

	# Invincibility Shield Aura
	if GameState.is_invincible():
		var pulse := 0.35 + 0.20 * sin(anim_clock * 7.0)
		draw_arc(Vector2(0, -10), 12.0, 0.0, TAU, 20, Color(0.64, 0.91, 1.0, pulse), 1.2)
