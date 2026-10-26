extends Node

const PATH = "user://save.cfg"
const MAX_SCORES = 30
const DIFF_NAMES = ["Easy", "Medium", "Hard"]
const HEARTS = [5, 3, 2]
const CHASE_SPEEDS = [6.5, 8.0, 9.0]
const CHASE_CHANCES = [0.4, 0.6, 0.85]
const SIGHT_RANGES = [15.0, 20.0, 25.0]

var loading = false
var seed_value = 0
var score = 0
var pos = Vector3(3, 1, 3)
var play_time = 0.0
var hearts = 3
var diff = 1
var pref_diff = 1
var volume = 1.0
var sens = 1.0

func _ready():
	var cf = ConfigFile.new()
	if cf.load(PATH) == OK:
		volume = cf.get_value("settings", "volume", 1.0)
		sens = cf.get_value("settings", "sens", 1.0)
		pref_diff = cf.get_value("settings", "diff", 1)
	diff = pref_diff
	hearts = HEARTS[diff]
	apply_settings()

func start_new():
	diff = pref_diff
	hearts = HEARTS[diff]
	loading = false

func apply_settings():
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))

func save_settings():
	var cf = ConfigFile.new()
	cf.load(PATH)
	cf.set_value("settings", "volume", volume)
	cf.set_value("settings", "sens", sens)
	cf.set_value("settings", "diff", pref_diff)
	cf.save(PATH)

func has_run():
	var cf = ConfigFile.new()
	return cf.load(PATH) == OK and cf.has_section_key("game", "seed")

func save_run(s, sc, p, t):
	var cf = ConfigFile.new()
	cf.load(PATH)
	cf.set_value("game", "seed", s)
	cf.set_value("game", "score", sc)
	cf.set_value("game", "pos", p)
	cf.set_value("game", "time", t)
	cf.set_value("game", "hearts", hearts)
	cf.set_value("game", "diff", diff)
	cf.save(PATH)

func load_run():
	var cf = ConfigFile.new()
	if cf.load(PATH) != OK or not cf.has_section_key("game", "seed"):
		return false
	seed_value = cf.get_value("game", "seed")
	score = cf.get_value("game", "score", 0)
	pos = cf.get_value("game", "pos", Vector3(3, 1, 3))
	play_time = cf.get_value("game", "time", 0.0)
	diff = cf.get_value("game", "diff", 1)
	hearts = cf.get_value("game", "hearts", HEARTS[diff])
	loading = true
	return true

func clear_run():
	var cf = ConfigFile.new()
	if cf.load(PATH) == OK and cf.has_section("game"):
		cf.erase_section("game")
		cf.save(PATH)

func add_score(sc, t):
	var cf = ConfigFile.new()
	cf.load(PATH)
	var list = cf.get_value("scores", "list", [])
	var date = Time.get_datetime_string_from_system(false, true).substr(0, 16)
	list.push_front({"date": date, "time": t, "score": sc, "diff": diff})
	while list.size() > MAX_SCORES:
		list.pop_back()
	cf.set_value("scores", "list", list)
	cf.save(PATH)

func get_scores():
	var cf = ConfigFile.new()
	if cf.load(PATH) != OK:
		return []
	return cf.get_value("scores", "list", [])

func format_time(t):
	var s = int(t)
	return "%02d:%02d" % [s / 60, s % 60]
