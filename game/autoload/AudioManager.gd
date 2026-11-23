extends Node
## Retro SFX & beat-synced BGM audio controller.
## Plays procedural 8/16-bit WAVs from res://assets/audio/sfx/ if present,
## and safely degrades to silent no-op in headless/test runs.

signal beat_pulse(beat_index: int)

var sfx_cache: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var bgm_player: AudioStreamPlayer
var bpm: float = 140.0
var _beat_accum: float = 0.0
var _beat_idx: int = 0
var muted: bool = false

const SFX_POOL_SIZE := 8
const SFX_DIR := "res://assets/audio/sfx/"


func _ready() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)

	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = -8.0
	add_child(bgm_player)

	_preload_sfx()


func _process(delta: float) -> void:
	var sec_per_beat: float = 60.0 / maxf(bpm, 30.0)
	_beat_accum += delta
	if _beat_accum >= sec_per_beat:
		_beat_accum -= sec_per_beat
		_beat_idx += 1
		beat_pulse.emit(_beat_idx)


func _preload_sfx() -> void:
	var names: Array[String] = [
		"jump", "wall_jump", "slide", "land", "kaizo_block",
		"death_spike", "death_glitch", "death_coconut",
		"key_get", "spring", "door", "laser", "secret", "manual_flip", "dos_beep"
	]
	for n: String in names:
		var path: String = SFX_DIR + n + ".wav"
		if ResourceLoader.exists(path):
			sfx_cache[n] = load(path)


func play_sfx(sfx_name: String, pitch_jitter: float = 0.05, volume_db: float = -4.0) -> void:
	if muted or DisplayServer.get_name() == "headless":
		return
	if not sfx_cache.has(sfx_name):
		var path := SFX_DIR + sfx_name + ".wav"
		if ResourceLoader.exists(path):
			sfx_cache[sfx_name] = load(path)
		else:
			return
	for p in sfx_players:
		if not p.playing:
			p.stream = sfx_cache[sfx_name]
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.volume_db = volume_db
			p.play()
			return


func play_bgm(res_path: String, track_bpm: float = 140.0) -> void:
	bpm = track_bpm
	if muted or DisplayServer.get_name() == "headless":
		return
	if ResourceLoader.exists(res_path):
		var stream = load(res_path)
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.data.size() / 2)
		if bgm_player.stream != stream:
			bgm_player.stream = stream
			bgm_player.play()


func stop_bgm() -> void:
	if bgm_player:
		bgm_player.stop()
