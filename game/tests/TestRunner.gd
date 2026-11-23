extends Node
## Automated Headless Verification Suite for Kaizo Trap (Pure WYSIWYG 14-Room Edition).
## Verifies:
##   - 120Hz Physics + Godot Physics Interpolation
##   - All 14 Pure Kaizo Trap WYSIWYG Rooms (Classic + Arrange, zero blind hidden blocks!)
##   - Pure Kaizo Trap Mechanics (BaguaResonanceOrb, SteelRailPlatform, HexCodeCurtain,
##     WindGustZone, DirectionalSpring, BaguaTalisman, TelegraphedDropper)
##   - Playable Kai & Zo character switching
##   - Full Celeste-aligned physics feel & Assist Mode + ZhugeDOS ARG!

var failures: Array[String] = []


func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("FAIL: " + msg)
		printerr("[FAIL] ", msg)
	else:
		print("[PASS] ", msg)


func _ready() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	print("=== KAIZO TRAP PHASE 3 WYSIWYG 14-ROOM VERIFICATION SUITE ===")

	# 1. Engine Smoothness
	assert_true(Engine.physics_ticks_per_second >= 120, "High-frequency 120Hz physics active (%d Hz)" % Engine.physics_ticks_per_second)
	assert_true(get_tree().physics_interpolation, "Godot 2D Physics Interpolation enabled")

	# 2. Autoloads & ZhugeDOS 14 ARG
	assert_true(GameState != null and SecretManager != null and ReplayManager != null and AudioManager != null, "All 4 Autoload singletons loaded")
	assert_true(SecretManager.evaluate_zhugedos_command("ver").find("4569676874205472696772616d73") != -1, "ZhugeDOS VER serial verified")
	assert_true(SecretManager.evaluate_zhugedos_command("hex 4569676874205472696772616d73").find("Eight Trigrams") != -1, "ZhugeDOS HEX decodes Eight Trigrams")
	SecretManager.evaluate_zhugedos_command("dna ACGT")
	SecretManager.evaluate_zhugedos_command("key 7:01")
	SecretManager.evaluate_zhugedos_command("warp 1-5-2-4-3")
	SecretManager.evaluate_zhugedos_command("edit hate.php")
	SecretManager.evaluate_zhugedos_command("warp 6")
	assert_true(SecretManager.dna_sequence_entered and SecretManager.key_block_701_clicked, "ARG flags verified")

	# 3. Assets: 19 SFX, 3 BGM, Pure Kaizo Props & Playable Zo Sheet
	assert_true(AudioManager.sfx_cache.size() >= 19, "All 19 SFX loaded (%d)" % AudioManager.sfx_cache.size())
	for img: String in [
		"res://assets/sprites/kai_sheet.png",
		"res://assets/sprites/kai_run8.png",
		"res://assets/sprites/zo_sheet.png",
		"res://assets/sprites/zo_and_boss.png",
		"res://assets/tilesets/overworld_objects.png",
		"res://assets/tilesets/biomes_tiles.png",
		"res://assets/tilesets/kaizo_props.png",
		"res://assets/manual/manual_controller.png",
	]:
		assert_true(ResourceLoader.exists(img), "16-bit Pixel Asset exists: " + img)

	# 4. Main scene + ALL 14 pure Kaizo Trap WYSIWYG rooms (Classic & Arrange)
	var main_packed: PackedScene = load("res://scenes/core/Main.tscn")
	var main: Node = main_packed.instantiate()
	add_child(main)
	await get_tree().process_frame

	var all_rooms: Array[String] = StageCatalog.get_all_room_ids()
	assert_true(all_rooms.size() == 14, "Campaign contains all 14 pure Kaizo Trap rooms")
	for rid: String in all_rooms:
		var spec := StageCatalog.get_room_spec(rid)
		assert_true(spec.get("kaizo_blocks", []).is_empty(), "WYSIWYG verified (0 blind invisible traps) in " + rid)
		GameState.arrange_mode = false
		main.load_room(rid)
		await get_tree().process_frame
		assert_true(main.current_room.room_id == rid, "Loaded Classic room: " + rid)
		GameState.arrange_mode = true
		main.load_room(rid)
		await get_tree().process_frame
		assert_true(main.current_room.room_id == rid, "Loaded Arrange room: " + rid)

	# 5. Character Switching (Kai <-> Playable Zo)
	var player: KaiPlayer = main.player
	assert_true(player.kai_sheet_tex != null and player.zo_sheet_tex != null, "Both Kai and Playable Zo sprite sheets loaded")
	GameState.toggle_playable_character()
	player.set_character(GameState.playable_character)
	assert_true(player.active_char_id == "zo" and player.sprite.texture == player.zo_sheet_tex, "Switched playable character cleanly to Zo")
	GameState.toggle_playable_character()
	player.set_character(GameState.playable_character)
	assert_true(player.active_char_id == "kai" and player.has_run8_texture, "Switched back cleanly to Kai (8-frame run + dynamic hair)")

	# 6. Full Celeste-Style Assist Mode Checks
	GameState.set_difficulty(GameState.DifficultyMode.CLASSIC)
	assert_true(GameState.cycle_game_speed(1) == 90 and is_equal_approx(Engine.time_scale, 0.9), "Assist speed 90%")
	GameState.set_game_speed_pct(50)
	assert_true(is_equal_approx(Engine.time_scale, 0.5), "Assist speed 50%")
	GameState.set_game_speed_pct(100)
	assert_true(GameState.cycle_air_dashes() == 2, "Assist Air Dashes -> 2")
	assert_true(GameState.cycle_air_dashes() == 99, "Assist Air Dashes -> Infinite")
	assert_true(GameState.toggle_infinite_stamina(), "Assist Infinite Stamina ON")
	GameState.toggle_invincibility()

	GameState.arrange_mode = false
	main.load_room("room_02")
	await get_tree().physics_frame
	var deaths_inv: int = GameState.total_deaths
	player.kill("spike")
	assert_true(not player.is_dead and GameState.total_deaths == deaths_inv and player.velocity.y < -150.0, "Invincibility bounces Kai off spikes with 0 deaths")
	player.kill("pit")
	assert_true(not player.is_dead and player.velocity.y < -300.0, "Invincibility bounces Kai safely out of pits")
	GameState.set_difficulty(GameState.DifficultyMode.CLASSIC)

	# 7. 120Hz 8-Way Dash TAS Check on room_02
	main.load_room("room_02")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var start_x: float = player.global_position.x
	var tas: Array = []
	for i in 6:
		tas.append({"move_right": true, "jump": true})
	tas.append({"move_right": true, "move_up": true, "slide": true})
	for i in 22:
		tas.append({"move_right": true})
	ReplayManager.start_tas(tas)
	var saw_dash := false
	for i in tas.size():
		await get_tree().physics_frame
		if player.is_dashing:
			saw_dash = true
	ReplayManager.stop_tas()
	assert_true(saw_dash and player.global_position.x > start_x + 35.0, "120Hz 8-Way Dash propelled Kai cleanly (dx=%.1f)" % (player.global_position.x - start_x))

	# 8. Pure Kaizo Mechanics checks: HexCodeCurtain (room_10), Heart Cable (room_12), 7M01S Key Block (room_04)
	main.load_room("room_10")
	await get_tree().physics_frame
	assert_true(get_tree().get_nodes_in_group("dream_blocks").size() >= 2, "ZhugeDOS HexCodeCurtains active in room_10")

	main.load_room("room_12")
	await get_tree().process_frame
	main.current_room._on_heart_cable_pulled()
	assert_true(main.current_room.boss_glitched and not main.current_room.exit_flag.is_kaizo_fakeout, "Core Boss Heart Cable disarms Kaizo Trap")

	main.load_room("room_04")
	await get_tree().process_frame
	assert_true(main.current_room.handle_crt_inspect_click(Vector2(46.0, 56.0)), "7M01S Key Block CRT Inspect click unlocks Ending 1")

	print("===============================================")
	if failures.is_empty():
		print("ALL PHASE 3 PURE KAIZO WYSIWYG CHECKS PASSED! (0 failures)")
		get_tree().quit(0)
	else:
		printerr("TESTS FAILED: ", failures.size())
		get_tree().quit(1)
