extends Node
## Automated Headless Verification Suite for Kaizo Trap (Godot 4.7).
## Verifies all 10 campaign rooms (Classic + Arrange), Celeste Assist Mode
## (50-100% Game Speed + Invincibility Shield), Phase 1+2 GPT Image assets,
## 3 Shaders, 15 SFX + 3 BGM tracks, ZhugeDOS ARG puzzles, and 60Hz TAS physics.

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
	print("=== KAIZO TRAP PHASE 2 AUTOMATED VERIFICATION SUITE ===")

	# 1. Autoloads & ZhugeDOS 14 ARG
	assert_true(GameState != null and SecretManager != null and ReplayManager != null and AudioManager != null, "All 4 Autoload singletons loaded")
	assert_true(SecretManager.evaluate_zhugedos_command("ver").find("4569676874205472696772616d73") != -1, "ZhugeDOS VER contains canonical Eight Trigrams serial hex")
	assert_true(SecretManager.evaluate_zhugedos_command("hex 4569676874205472696772616d73").find("Eight Trigrams") != -1, "ZhugeDOS HEX decodes Eight Trigrams")
	SecretManager.evaluate_zhugedos_command("dna ACGT")
	assert_true(SecretManager.dna_sequence_entered, "DNA A-C-G-T controller cipher unlocks tether")
	SecretManager.evaluate_zhugedos_command("key 7:01")
	assert_true(SecretManager.key_block_701_clicked, "Manual 7:01 Key Block timestamp accepted")
	SecretManager.evaluate_zhugedos_command("warp 1-5-2-4-3")
	assert_true(bool(SecretManager.unlocked_endings.get("nyan_whale", false)), "1-5-2-4-3 unlocks Nyan Whale")
	SecretManager.evaluate_zhugedos_command("edit hate.php")
	assert_true(bool(SecretManager.unlocked_endings.get("bad", false)), "EDIT HATE.PHP unlocks Ending 5")
	SecretManager.evaluate_zhugedos_command("warp 6")
	assert_true(bool(SecretManager.unlocked_endings.get("sixth", false)), "WARP 6 unlocks 6th Ending easter egg")

	# 2. Shaders, SFX, BGM, and GPT-Image pixel sheets
	for sh: String in ["res://shaders/crt_screen.gdshader", "res://shaders/blizzard.gdshader", "res://shaders/glitch_vram.gdshader"]:
		assert_true(ResourceLoader.exists(sh) and load(sh) != null, "Shader loaded: " + sh)
	assert_true(AudioManager.sfx_cache.size() >= 15, "All 15 retro SFX loaded (%d)" % AudioManager.sfx_cache.size())
	for bgm: String in ["overworld_paradigm.wav", "ice_factory.wav", "core_boss.wav"]:
		assert_true(ResourceLoader.exists("res://assets/audio/bgm/" + bgm), "Chiptune BGM exists: " + bgm)
	for img: String in [
		"res://assets/sprites/kai_sheet.png",
		"res://assets/sprites/zo_and_boss.png",
		"res://assets/tilesets/overworld_objects.png",
		"res://assets/tilesets/biomes_tiles.png",
		"res://assets/manual/manual_controller.png",
	]:
		assert_true(ResourceLoader.exists(img), "16-bit Pixel Asset exists: " + img)

	# 3. Main scene + all 10 campaign rooms in Classic & Arrange Mode
	var main_packed: PackedScene = load("res://scenes/core/Main.tscn")
	assert_true(main_packed != null, "Main.tscn loaded")
	var main: Node = main_packed.instantiate()
	add_child(main)
	await get_tree().process_frame

	var all_rooms: Array[String] = StageCatalog.get_all_room_ids()
	assert_true(all_rooms.size() == 10, "Campaign contains all 10 handcrafted rooms")
	for rid: String in all_rooms:
		GameState.arrange_mode = false
		main.load_room(rid)
		await get_tree().process_frame
		assert_true(main.current_room.room_id == rid, "Loaded Classic room: " + rid)
		GameState.arrange_mode = true
		main.load_room(rid)
		await get_tree().process_frame
		assert_true(main.current_room.room_id == rid, "Loaded Arrange room: " + rid)

	# 4. Celeste Assist Mode verification (Game Speed 100%..50% + Invincibility Shield!)
	GameState.set_difficulty(GameState.DifficultyMode.CLASSIC)
	assert_true(is_equal_approx(Engine.time_scale, 1.0), "Classic mode runs at 100% speed")
	var pct1: int = GameState.cycle_game_speed(1)
	assert_true(pct1 == 90 and is_equal_approx(Engine.time_scale, 0.9), "Celeste Assist speed steps to 90%")
	GameState.set_game_speed_pct(50)
	assert_true(is_equal_approx(Engine.time_scale, 0.5), "Celeste Assist speed reaches 50% slow-mo")
	GameState.set_game_speed_pct(100)

	# Invincibility test on spike & pit
	GameState.toggle_invincibility()
	assert_true(GameState.is_invincible(), "Celeste Invincibility Mode active")
	GameState.arrange_mode = false
	main.load_room("room_01")
	await get_tree().physics_frame
	var player: KaiPlayer = main.player
	var deaths_inv: int = GameState.total_deaths
	player.kill("spike")
	assert_true(not player.is_dead and GameState.total_deaths == deaths_inv and player.velocity.y < -150.0, "Invincibility safely bounces Kai off spikes with 0 deaths")
	player.kill("pit")
	assert_true(not player.is_dead and player.velocity.y < -300.0, "Invincibility safely super-bounces Kai out of bottomless pits")
	GameState.set_difficulty(GameState.DifficultyMode.CLASSIC)

	# 5. Deterministic 60Hz Celeste Physics TAS test (Run, Slide hitbox, Jump + Apex hang)
	GameState.clear_splats()
	main.load_room("room_01")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var start_x: float = player.global_position.x
	var tas: Array = []
	for i in 12:
		tas.append({"move_right": true, "slide": true})
	tas.append({"move_right": true, "crouch": true, "slide": true})
	for i in 8:
		tas.append({"move_right": true})
	for i in 12:
		tas.append({"move_right": true, "jump": true})

	ReplayManager.start_tas(tas)
	var saw_slide_hitbox := false
	var saw_airborne := false
	for i in tas.size():
		await get_tree().physics_frame
		if player.body_shape.shape == player.crouch_rect:
			saw_slide_hitbox = true
		if not player.is_on_floor():
			saw_airborne = true
	ReplayManager.stop_tas()
	assert_true(player.global_position.x > start_x + 25.0, "Celeste TAS physics moved Kai right cleanly (dx=%.1f)" % (player.global_position.x - start_x))
	assert_true(saw_slide_hitbox, "Slide morphed Kai hitbox to 12x9 low crouch rect")
	assert_true(saw_airborne, "Jump launched Kai cleanly into the air")

	# 6. Classic Death -> Persistent Splat -> Instant Respawn
	player.respawn()
	GameState.clear_splats()
	var deaths_before: int = GameState.total_deaths
	player.kill("coconut")
	await get_tree().physics_frame
	assert_true(GameState.total_deaths == deaths_before + 1 and GameState.get_splats("room_01").size() >= 1, "Classic coconut death records persistent splat")
	for i in 18:
		await get_tree().physics_frame
	assert_true(not player.is_dead, "Kai respawned instantaneously (<0.3s)")

	# 7. Stage 5 Core Boss Heart Cable Pull disarms Kaizo Trap flag
	main.load_room("room_08")
	await get_tree().process_frame
	assert_true(main.current_room.exit_flag.is_kaizo_fakeout, "Stage 5 Core Victory Flag starts armed as Kaizo Trap fakeout")
	main.current_room._on_heart_cable_pulled()
	assert_true(main.current_room.boss_glitched and not main.current_room.exit_flag.is_kaizo_fakeout, "Pulling Zo's Heart Cable glitches Boss and unlocks Glitch Escape")

	# 8. CRT Right-Click Inspect on 7M01S Key Block unlocks Ending 1
	main.load_room("room_03")
	await get_tree().process_frame
	var clicked: bool = main.current_room.handle_crt_inspect_click(Vector2(46.0, 56.0))
	assert_true(clicked and bool(SecretManager.unlocked_endings.get("good", false)), "Right-click CRT Inspect on 7M01S Key Block unlocks Ending 1")

	print("===============================================")
	if failures.is_empty():
		print("ALL PHASE 2 VERIFICATION CHECKS PASSED! (0 failures)")
		get_tree().quit(0)
	else:
		printerr("TESTS FAILED: ", failures.size())
		get_tree().quit(1)
