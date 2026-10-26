extends Node3D

const CS = 16
const TILE = 3.0
const H = 3.0
const WALL_P = 0.28
const HALL_P = 0.10
const RADIUS = 1
const MonsterScene = preload("res://monster.tscn")

var world_seed = 0
var chunks = {}
var player
var monster
var pickup
var hud
var score = 0
var hearts = 3
var play_time = 0.0
var dead = false
var unit_box = BoxMesh.new()
var wall_mat = make_mat("res://textures/wall.jpg")
var floor_mat = make_mat("res://textures/floor.jpg")
var ceil_mat = make_mat("res://textures/ceiling.jpg")

func make_mat(path):
	var m = StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.4, 0.4, 0.4)
	return m

func _ready():
	randomize()
	player = $Player
	var start = Vector3(TILE, 1, TILE)
	if Game.loading:
		world_seed = Game.seed_value
		score = Game.score
		play_time = Game.play_time
		start = Vector3(Game.pos.x, 1.0, Game.pos.z)
		Game.loading = false
	else:
		world_seed = randi() % 100000
	hearts = Game.hearts
	player.position = start
	var pc = Vector2i(floori((start.x / TILE + 0.5) / CS), floori((start.z / TILE + 0.5) / CS))
	for cx in range(pc.x - RADIUS, pc.x + RADIUS + 1):
		for cy in range(pc.y - RADIUS, pc.y + RADIUS + 1):
			load_chunk(Vector2i(cx, cy))
	make_hud()
	spawn_monster()
	spawn_pickup()

func make_hud():
	var layer = CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(20, 44)
	hud.add_theme_font_size_override("font_size", 22)
	layer.add_child(hud)
	var b = Button.new()
	b.text = "Menu"
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = -120
	b.offset_right = -20
	b.offset_top = 20
	b.offset_bottom = 70
	b.pressed.connect(go_menu)
	layer.add_child(b)

func save_now():
	Game.hearts = hearts
	Game.save_run(world_seed, score, player.position, play_time)

func go_menu():
	if dead:
		return
	save_now()
	get_tree().change_scene_to_file("res://menu.tscn")

func rnd(x, y, s):
	var n = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791) ^ world_seed
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0

func is_hall(cx, cy):
	if cx == 0 and cy == 0:
		return false
	return rnd(cx, cy, 2) < HALL_P

func is_wall(x, y):
	if x >= 0 and x <= 2 and y >= 0 and y <= 2 and not (x % 2 == 0 and y % 2 == 0):
		return false
	var cx = floori(x / float(CS))
	var cy = floori(y / float(CS))
	var lx = posmod(x, CS)
	var ly = posmod(y, CS)
	if is_hall(cx, cy) and lx >= 2 and lx <= CS - 3 and ly >= 2 and ly <= CS - 3:
		return posmod(x, 4) == 0 and posmod(y, 4) == 0
	var ex = posmod(x, 2) == 0
	var ey = posmod(y, 2) == 0
	if ex and ey:
		return true
	if not ex and not ey:
		return false
	return rnd(x, y, 1) < WALL_P

func add_shape(body, pos, sz):
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = sz
	col.shape = shape
	col.position = pos
	body.add_child(col)

func add_slab(root, body, pos, sz, m):
	add_shape(body, pos, sz)
	var mi = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = sz
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = m
	root.add_child(mi)

func load_chunk(c):
	if chunks.has(c):
		return
	var root = Node3D.new()
	add_child(root)
	var body = StaticBody3D.new()
	root.add_child(body)
	var hall = is_hall(c.x, c.y)
	var span = CS * TILE
	var mid_x = (c.x * CS + (CS - 1) / 2.0) * TILE
	var mid_z = (c.y * CS + (CS - 1) / 2.0) * TILE
	add_slab(root, body, Vector3(mid_x, -0.25, mid_z), Vector3(span, 0.5, span), floor_mat)
	add_slab(root, body, Vector3(mid_x, H + 0.25, mid_z), Vector3(span, 0.5, span), ceil_mat)

	var runs = []
	for ly in CS:
		var y = c.y * CS + ly
		var lx = 0
		while lx < CS:
			if is_wall(c.x * CS + lx, y):
				var start = lx
				while lx < CS and is_wall(c.x * CS + lx, y):
					lx += 1
				var n = lx - start
				var px = (c.x * CS + start + (n - 1) / 2.0) * TILE
				runs.append([Vector3(px, H / 2, y * TILE), Vector3(n * TILE, H, TILE)])
			else:
				lx += 1

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = unit_box
	mm.instance_count = runs.size()
	for i in runs.size():
		var r = runs[i]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(r[1]), r[0]))
		add_shape(body, r[0], r[1])
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = wall_mat
	root.add_child(mmi)

	var list = []
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(c.x, c.y, world_seed))
	var count = 5 if hall else 3
	for i in count:
		for t in 30:
			var x = c.x * CS + rng.randi_range(0, CS - 1)
			var y = c.y * CS + rng.randi_range(0, CS - 1)
			if not is_wall(x, y):
				var l = OmniLight3D.new()
				l.position = Vector3(x * TILE, 2.7, y * TILE)
				l.omni_range = 14 if hall else 10
				l.light_color = Color("fff3b0")
				root.add_child(l)
				list.append(l)
				break
	chunks[c] = {"root": root, "lights": list}

func _process(delta):
	if not dead:
		play_time += delta
	var p = player.position
	if monster.state == 0 and (monster.position.distance_to(p) > 45 or monster.position.y < -3):
		spawn_monster()
	var pc = Vector2i(floori((p.x / TILE + 0.5) / CS), floori((p.z / TILE + 0.5) / CS))
	for c in chunks.keys():
		if abs(c.x - pc.x) > RADIUS + 1 or abs(c.y - pc.y) > RADIUS + 1:
			chunks[c]["root"].queue_free()
			chunks.erase(c)
	var loaded = false
	for dx in range(-RADIUS, RADIUS + 1):
		for dy in range(-RADIUS, RADIUS + 1):
			var c = pc + Vector2i(dx, dy)
			if not loaded and not chunks.has(c):
				load_chunk(c)
				loaded = true
	for c in chunks:
		for l in chunks[c]["lights"]:
			if randf() < 0.03:
				l.light_energy = randf_range(0.0, 0.6)
			else:
				l.light_energy = 1.0

	var pd = Vector2(p.x - pickup.position.x, p.z - pickup.position.z).length()
	if pd < 1.5 and not dead:
		score += 1
		spawn_pickup()
		save_now()
		pd = 0.0
	hud.text = "Points: %d    Next: %d m\nHearts: %d / %d    Time: %s" % [score, roundi(pd), hearts, Game.HEARTS[Game.diff], Game.format_time(play_time)]

func spawn_monster():
	if monster == null:
		monster = MonsterScene.instantiate()
		add_child(monster)
	for t in 50:
		var a = randf() * TAU
		var d = randf_range(30.0, 38.0)
		var x = roundi((player.position.x + cos(a) * d) / TILE)
		var y = roundi((player.position.z + sin(a) * d) / TILE)
		if not is_wall(x, y):
			monster.position = Vector3(x * TILE, 0.5, y * TILE)
			return

func spawn_pickup():
	if pickup == null:
		pickup = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.3
		sm.height = 0.6
		pickup.mesh = sm
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(1, 1, 1)
		m.emission_enabled = true
		m.emission = Color(1, 0.9, 0.3)
		m.emission_energy_multiplier = 2.0
		pickup.material_override = m
		add_child(pickup)
	for t in 100:
		var a = randf() * TAU
		var d = randf_range(60.0, 90.0)
		var x = roundi((player.position.x + cos(a) * d) / TILE)
		var y = roundi((player.position.z + sin(a) * d) / TILE)
		if not is_wall(x, y):
			pickup.position = Vector3(x * TILE, 1.2, y * TILE)
			return

func caught():
	if dead:
		return
	dead = true
	hearts -= 1
	Game.hearts = hearts
	if hearts > 0:
		save_now()
	else:
		Game.add_score(score, play_time)
		Game.clear_run()
	for a in ["jump", "run", "interact", "fire"]:
		Input.action_release(a)
	player.set_physics_process(false)
	player.set_process_input(false)
	monster.set_physics_process(false)
	monster.velocity = Vector3.ZERO
	monster.get_node("Step").stop()
	monster.get_node("Growl").stop()
	monster.get_node("Scare").stop()
	var to = monster.global_position - player.global_position
	to.y = 0
	if to.length() < 0.1:
		to = Vector3(0, 0, -1)
	to = to.normalized()
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Camera3D").rotation.x = 0.35
	monster.global_position = player.global_position + to * 1.1
	monster.global_position.y = 0.0
	monster.look_at(Vector3(player.global_position.x, 0.0, player.global_position.z))
	var end_pos = player.global_position + to * 0.55
	end_pos.y = 0.0
	create_tween().tween_property(monster, "global_position", end_pos, 0.3)

	var snd = AudioStreamPlayer.new()
	var path = "res://sounds/jumpscare.mp3"
	if not ResourceLoader.exists(path):
		path = "res://sounds/scare.mp3"
	snd.stream = load(path)
	snd.volume_db = 6.0
	add_child(snd)
	snd.play()

	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0.9)
	layer.add_child(flash)
	create_tween().tween_property(flash, "color", Color(0.5, 0, 0, 0.45), 0.5)
	var shake = create_tween()
	shake.set_loops(18)
	shake.tween_callback(shake_cam).set_delay(0.04)

	await get_tree().create_timer(1.8).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_game_over(layer, hearts > 0)

func shake_cam():
	var cam = player.get_node("Camera3D")
	cam.h_offset = randf_range(-0.08, 0.08)
	cam.v_offset = randf_range(-0.08, 0.08)

func show_game_over(layer, alive):
	var dark = ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.8)
	layer.add_child(dark)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var t = Label.new()
	t.text = "YOU LOST A HEART" if alive else "YOU DIED"
	t.add_theme_font_size_override("font_size", 56)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var s = Label.new()
	if alive:
		s.text = "Hearts left: %d / %d    Points: %d" % [hearts, Game.HEARTS[Game.diff], score]
	else:
		s.text = "Final score: %d    Time: %s" % [score, Game.format_time(play_time)]
	s.add_theme_font_size_override("font_size", 24)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	var r = Button.new()
	r.text = "Retry"
	r.custom_minimum_size = Vector2(320, 56)
	r.add_theme_font_size_override("font_size", 24)
	r.pressed.connect(on_retry)
	box.add_child(r)
	var b = Button.new()
	b.text = "Menu"
	b.custom_minimum_size = Vector2(320, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(on_menu)
	box.add_child(b)

func on_retry():
	if hearts > 0:
		Game.load_run()
	else:
		Game.hearts = Game.HEARTS[Game.diff]
		Game.loading = false
	get_tree().reload_current_scene()

func on_menu():
	get_tree().change_scene_to_file("res://menu.tscn")
