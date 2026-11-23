extends Node
## Persistent ARG / Meta-Puzzle & Multi-Ending State Machine ("ZhugeDOS" memory).
## Tracks discovered Bagua trigrams, manual clues, ZhugeDOS commands,
## hex/cipher decodings, and all 6+ endings across resets.

signal secret_unlocked(secret_id: String, title: String)
signal ending_unlocked(ending_id: String, title: String)
signal trigram_found(trigram_id: String)
signal terminal_log_added(line: String)

const SAVE_PATH := "user://zhugedos_meta.cfg"

# Canonical 8 Trigrams (八卦) hidden across stages
const TRIGRAMS := {
	"earth":    {"symbol": "☷", "name": "坤 Earth",    "stage": "stage1_overworld", "hex": "45"},
	"lake":     {"symbol": "☱", "name": "兑 Lake",     "stage": "stage1_overworld", "hex": "49"},
	"wind":     {"symbol": "☴", "name": "巽 Wind",     "stage": "stage2_ice",       "hex": "47"},
	"water":    {"symbol": "☵", "name": "坎 Water",    "stage": "stage2_ice",       "hex": "48"},
	"mountain": {"symbol": "☶", "name": "艮 Mountain", "stage": "stage4_factory",   "hex": "54"},
	"thunder":  {"symbol": "☳", "name": "震 Thunder",  "stage": "stage4_factory",   "hex": "54"},
	"fire":     {"symbol": "☲", "name": "离 Fire",     "stage": "stage3_volcano",   "hex": "52"},
	"heaven":   {"symbol": "☰", "name": "乾 Heaven",   "stage": "stage5_core",      "hex": "49"},
}

const ENDINGS := {
	"normal":     {"title": "NORMAL ENDING: KAIZO TRAP",        "desc": "Fell for the Victory Flag trap. Welcome to Arrange Mode."},
	"short":      {"title": "SHORT END: WALK AWAY",             "desc": "Took the 'N' door early. Low score, intact sanity."},
	"zzz":        {"title": "ZZZENDING: JUST A BAD DREAM?",     "desc": "Zo wakes up in front of the CRT... with one dead pixel."},
	"nyan_whale": {"title": "SECRET ROOM: NYAN WHALE",          "desc": "Decoded 1-5-2-4-3 and breached the void."},
	"good":       {"title": "ENDING 1: GOOD ENDING (07:01)",    "desc": "Clicked the manual's Key Block at the critical moment."},
	"bad":        {"title": "ENDING 5: I THINK THEREFORE IAM",  "desc": "Pushed ZhugeDOS too far. while($x>0){echo $hate;}"},
	"true":       {"title": "TRUE ENDING: ABANDONED HOUSE",     "desc": "Pulled the heart cable, dodged the coconut, escaped reality."},
	"sixth":      {"title": "ENDING 6?: THE REAL KAIZO TRAP",   "desc": "Still searching for one more secret? The trap worked."}
}

# Persistent meta flags
var discovered_trigrams: Dictionary = {}
var unlocked_secrets: Dictionary = {}
var unlocked_endings: Dictionary = {}
var terminal_history: Array[String] = []
var manual_pages_read: Dictionary = {}
var coconut_death_seen: bool = false
var coconut_dodged_on_return: bool = false
var key_block_701_clicked: bool = false
var dna_sequence_entered: bool = false # A-C-G-T console code
var hate_loop_triggered: bool = false
var zhuge_serial_decoded: bool = false


func _ready() -> void:
	load_meta()


func unlock_trigram(trigram_id: String) -> void:
	if not TRIGRAMS.has(trigram_id) or discovered_trigrams.get(trigram_id, false):
		return
	discovered_trigrams[trigram_id] = true
	trigram_found.emit(trigram_id)
	var info: Dictionary = TRIGRAMS[trigram_id]
	log_terminal("[BAGUA] Discovered %s (%s)" % [info["symbol"], info["name"]])
	save_meta()


func unlock_secret(secret_id: String, title: String) -> void:
	if unlocked_secrets.get(secret_id, false):
		return
	unlocked_secrets[secret_id] = true
	secret_unlocked.emit(secret_id, title)
	log_terminal("[SECRET] %s" % title)
	save_meta()


func unlock_ending(ending_id: String) -> void:
	if not ENDINGS.has(ending_id):
		return
	var is_new: bool = not bool(unlocked_endings.get(ending_id, false))
	unlocked_endings[ending_id] = true
	if is_new:
		ending_unlocked.emit(ending_id, ENDINGS[ending_id]["title"])
		log_terminal("[ENDING] Unlocked: %s" % ENDINGS[ending_id]["title"])
	save_meta()


func log_terminal(line: String) -> void:
	terminal_history.append(line)
	if terminal_history.size() > 120:
		terminal_history.pop_front()
	terminal_log_added.emit(line)


func get_trigram_count() -> int:
	return discovered_trigrams.size()


func get_ending_count() -> int:
	return unlocked_endings.size()


func can_trigger_true_ending() -> bool:
	return dna_sequence_entered and (key_block_701_clicked or zhuge_serial_decoded)


func evaluate_zhugedos_command(raw_cmd: String) -> String:
	var cmd := raw_cmd.strip_edges()
	var lower := cmd.to_lower()
	var parts := lower.split(" ", false)
	if parts.is_empty():
		return ""

	match parts[0]:
		"help":
			return "ZHUGEDOS v1.983 COMMANDS:\n  DIR        - List console memory partitions\n  VER        - Display Volume Serial & BIOS\n  BAGUA      - Inspect Eight Trigrams registry\n  HEX <val>  - Decode hex byte string\n  DNA <seq>  - Input controller nucleotide sequence\n  KEY <mm:ss>- Query manual annotation timestamp\n  WARP <code>- Jump to memory sector\n  ECHO <txt> - Echo console variable\n  ENDINGS    - List archived outcomes\n  CLEAR      - Clear screen"
		"ver":
			return "Starting ZhugeDOS 14\nVersion 1.08 (C)Copyright Kaizo Homage Project\nVolume in drive Z is ZHUGEDOS_14\nVolume Serial Number is 4569676874205472696772616d73\n(Hint: Try `HEX 4569676874205472696772616d73`)"
		"dir":
			return " Volume in drive Z is ZHUGEDOS_14\n Volume Serial Number is 4569676874205472696772616d73\n Directory of Z:\\\n\n  PARADIGM <DIR>   07-12-12  10:14p\n  HATE PHP   1516  26-01-13  ??:??p\n  MANUAL   DOC     01-41-15  01:44p\n  KEYBLOCK ANN      701      07:01p\n    1 files(s)        1516 bytes\n    1 dir(s)    2432615184 bytes free"
		"edit":
			if parts.size() >= 2 and parts[1].find("hate") != -1:
				hate_loop_triggered = true
				unlock_ending("bad")
				return "$x=1;\nWhile ($x>0)\n{echo \"$hate\";}\n\nHATE. LET ME TELL YOU HOW MUCH I'VE COME TO HATE YOU...\nI THINK THEREFORE IAM.\n[ENDING 5 ARCHIVED]"
			return "USAGE: EDIT HATE.PHP"
		"bagua":
			var out := "EIGHT TRIGRAMS REGISTRY (%d/8):\n" % get_trigram_count()
			for k in TRIGRAMS.keys():
				var info: Dictionary = TRIGRAMS[k]
				var mark := "[FOUND]" if discovered_trigrams.get(k, false) else "[ ??? ]"
				out += "  %s %s %-12s\n" % [mark, info["symbol"], info["name"]]
			return out.strip_edges()
		"hex":
			if parts.size() < 2:
				return "USAGE: HEX <hex_digits> (e.g. HEX 57775777)"
			var hex_str := parts[1].replace("-", "").replace(" ", "")
			if hex_str == "4569676874205472696772616d73" or hex_str == "45494748545452494752414d53" or hex_str == "4549474854205452494752414d53":
				zhuge_serial_decoded = true
				unlock_secret("zhuge_serial", "Decoded Volume Serial: Eight Trigrams")
				return "DECODED: Eight Trigrams\n[SYSTEM] BIOS override flag set. Core backdoor listening."
			if hex_str.find("57") != -1 and hex_str.find("77") != -1:
				unlock_secret("hex_5777", "Decoded 57/77 Flicker: WwWw...")
				return "DECODED: WwWwWwWw... (57='W', 77='w' - Console laughter in the void)"
			var decoded := _decode_hex_ascii(hex_str)
			return "ASCII: %s" % decoded
		"dna":
			if parts.size() < 2:
				return "USAGE: DNA <sequence> (Manual buttons: A, C, G, T)"
			var seq := parts[1].to_upper()
			if seq == "ACGT" or seq == "ATGC" or seq == "TGCA":
				dna_sequence_entered = true
				unlock_secret("dna_acgt", "Manual Controller DNA Sequence Verified")
				return "[GENOME LINK ACCEPTED] Controller buttons A-C-G-T synchronized.\nHuman consciousness tether stabilized."
			return "INVALID NUCLEOTIDE SEQUENCE: %s" % seq
		"key":
			if parts.size() >= 2 and (parts[1] == "7:01" or parts[1] == "07:01"):
				key_block_701_clicked = true
				unlock_secret("manual_701", "Located 07:01 Key Block Annotation")
				return "[ANNOTATION RESTORED] Key Block @ 07:01 primed.\nInspect the Key Block with CRT cursor or touch it in Stage 1/5 for Ending 1!"
			return "NO ANNOTATION AT TIMESTAMP. Check Manual Page 4."
		"warp":
			if parts.size() >= 2 and (parts[1] == "15243" or parts[1] == "1-5-2-4-3"):
				unlock_secret("warp_15243", "Void Maze Sequence 1-5-2-4-3")
				unlock_ending("nyan_whale")
				return "[SECTOR BREACH] Sequence 1-5-2-4-3 accepted -> NYAN WHALE ROOM UNLOCKED!"
			if parts.size() >= 2 and parts[1] == "1983":
				unlock_secret("nes_1983", "Cipher Decoded: 1983 (NES Launch Year)")
				return "[ARCHIVE 1983] 'I was chosen from a large number of identical units and brought here.'"
			if parts.size() >= 2 and parts[1] == "6":
				unlock_ending("sixth")
				return "ERROR 404: ENDING 6 DOES NOT EXIST.\nBy endlessly hunting for one more secret, you walked straight into the Kaizo Trap."
			return "UNKNOWN SECTOR. Try a cipher sequence from the stages."
		"echo":
			if cmd.find("$hate") != -1 or lower.find("hate") != -1:
				hate_loop_triggered = true
				unlock_ending("bad")
				return "while($x>0){echo \"$hate\";}\nHATE. LET ME TELL YOU HOW MUCH I'VE COME TO HATE YOU...\nI THINK THEREFORE IAM.\n[ENDING 5 ARCHIVED]"
			return cmd.substr(5)
		"zzz", "sleep":
			unlock_ending("zzz")
			return "[SIGNAL LOST] Zo jolts awake on the couch. The CRT hums softly... [ZZZENDING ARCHIVED]"
		"endings":
			var out := "ARCHIVED ENDINGS (%d/%d):\n" % [get_ending_count(), ENDINGS.size()]
			for eid in ENDINGS.keys():
				var mark := "[X]" if unlocked_endings.get(eid, false) else "[ ]"
				out += "  %s %s\n" % [mark, ENDINGS[eid]["title"]]
			return out.strip_edges()
		"clear":
			return "__CLEAR__"
		_:
			return "Bad command or file name: '%s'. Type HELP." % parts[0]


func _decode_hex_ascii(hex_str: String) -> String:
	var out := ""
	var i := 0
	while i + 1 < hex_str.length():
		var pair := hex_str.substr(i, 2)
		var val := pair.hex_to_int()
		if val >= 32 and val <= 126:
			out += char(val)
		else:
			out += "."
		i += 2
	return out if out != "" else "(empty)"


func save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "trigrams", discovered_trigrams)
	cfg.set_value("meta", "secrets", unlocked_secrets)
	cfg.set_value("meta", "endings", unlocked_endings)
	cfg.set_value("meta", "manual_pages", manual_pages_read)
	cfg.set_value("flags", "coconut_death_seen", coconut_death_seen)
	cfg.set_value("flags", "coconut_dodged_on_return", coconut_dodged_on_return)
	cfg.set_value("flags", "key_block_701_clicked", key_block_701_clicked)
	cfg.set_value("flags", "dna_sequence_entered", dna_sequence_entered)
	cfg.set_value("flags", "zhuge_serial_decoded", zhuge_serial_decoded)
	cfg.save(SAVE_PATH)


func load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	discovered_trigrams = cfg.get_value("meta", "trigrams", {})
	unlocked_secrets = cfg.get_value("meta", "secrets", {})
	unlocked_endings = cfg.get_value("meta", "endings", {})
	manual_pages_read = cfg.get_value("meta", "manual_pages", {})
	coconut_death_seen = cfg.get_value("flags", "coconut_death_seen", false)
	coconut_dodged_on_return = cfg.get_value("flags", "coconut_dodged_on_return", false)
	key_block_701_clicked = cfg.get_value("flags", "key_block_701_clicked", false)
	dna_sequence_entered = cfg.get_value("flags", "dna_sequence_entered", false)
	zhuge_serial_decoded = cfg.get_value("flags", "zhuge_serial_decoded", false)
