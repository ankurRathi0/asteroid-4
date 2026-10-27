extends Control

var pages = []
var main_page
var settings_page
var credits_page
var scores_page
var continue_btn
var score_grid
var empty_label
var title

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = Color(0.03, 0.026, 0.012)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box = make_page("The Chase")
	main_page = box.get_parent()
	title = box.get_child(0)
	title.add_theme_color_override("font_color", Color(0.86, 0.78, 0.48))
	add_button(box, "Play", on_play)
	add_button(box, "New Game", on_new)
	continue_btn = add_button(box, "Continue", on_continue)
	continue_btn.disabled = not Game.has_run()
	add_button(box, "Settings", on_settings)
	add_button(box, "Scoreboard", on_scores)
	add_button(box, "Credits", on_credits)

	var sbox = make_page("SETTINGS")
	settings_page = sbox.get_parent()
	add_label(sbox, "Volume")
	add_slider(sbox, 0.0, 1.0, 0.05, Game.volume, on_volume)
	add_label(sbox, "Look sensitivity")
	add_slider(sbox, 0.3, 2.0, 0.1, Game.sens, on_sens)
	add_label(sbox, "Difficulty (for new runs)")
	var ob = OptionButton.new()
	for n in Game.DIFF_NAMES:
		ob.add_item(n)
	ob.selected = Game.pref_diff
	ob.custom_minimum_size = Vector2(320, 50)
	ob.add_theme_font_size_override("font_size", 22)
	ob.item_selected.connect(on_diff)
	sbox.add_child(ob)
	add_label(sbox, "Hearts: Easy 5 / Medium 3 / Hard 2")
	var gfx = CheckButton.new()
	gfx.text = "High quality graphics"
	gfx.button_pressed = Game.high_gfx
	gfx.add_theme_font_size_override("font_size", 22)
	gfx.toggled.connect(on_gfx)
	sbox.add_child(gfx)
	add_button(sbox, "Back", on_back)

	var scbox = make_page("SCOREBOARD")
	scores_page = scbox.get_parent()
	add_label(scbox, "Last 30 runs")
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 330)
	scbox.add_child(scroll)
	score_grid = GridContainer.new()
	score_grid.columns = 5
	score_grid.add_theme_constant_override("h_separation", 36)
	scroll.add_child(score_grid)
	empty_label = add_label(scbox, "No runs yet")
	add_button(scbox, "Back", on_back)

	var cbox = make_page("CREDITS")
	credits_page = cbox.get_parent()
	add_label(cbox, "Game by PRANAY\nMade with Godot Engine\nTextures: ambientCG\nSounds: Kenney, Pixabay")
	add_button(cbox, "Back", on_back)

	show_page(main_page)

func make_page(title_text):
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var t = Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 48)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	pages.append(center)
	return box

func add_button(box, text, fn):
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(fn)
	box.add_child(b)
	return b

func add_label(box, text):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	return l

func add_slider(box, mn, mx, step, val, fn):
	var s = HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(320, 30)
	s.value_changed.connect(fn)
	box.add_child(s)

func add_cell(text):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	score_grid.add_child(l)

func refresh_scores():
	for c in score_grid.get_children():
		score_grid.remove_child(c)
		c.queue_free()
	var list = Game.get_scores()
	empty_label.visible = list.is_empty()
	if list.is_empty():
		return
	for h in ["#", "Date", "Time", "Score", "Mode"]:
		add_cell(h)
	var i = 1
	for e in list:
		add_cell(str(i))
		add_cell(e["date"])
		add_cell(Game.format_time(e["time"]))
		add_cell(str(e["score"]))
		add_cell(Game.DIFF_NAMES[e["diff"]])
		i += 1

func show_page(p):
	for q in pages:
		q.visible = (q == p)

func on_settings():
	show_page(settings_page)

func on_credits():
	show_page(credits_page)

func on_scores():
	refresh_scores()
	show_page(scores_page)

func on_back():
	Game.save_settings()
	show_page(main_page)

func on_volume(v):
	Game.volume = v
	Game.apply_settings()

func on_sens(v):
	Game.sens = v

func on_diff(i):
	Game.pref_diff = i

func on_gfx(on):
	Game.high_gfx = on

func _process(_delta):
	if randf() < 0.04:
		title.modulate.a = randf_range(0.15, 0.7)
	else:
		title.modulate.a = 1.0

func start():
	get_tree().change_scene_to_file("res://main.tscn")

func on_play():
	Game.start_new()
	start()

func on_new():
	Game.clear_run()
	Game.start_new()
	start()

func on_continue():
	if Game.load_run():
		start()
