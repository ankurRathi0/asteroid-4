extends CharacterBody3D

enum { WANDER, PEEK, CHASE }
const WANDER_SPEED = 2.5
const DIRS = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var chase_speed = 8.0
var chase_chance = 0.6
var sight_range = 20.0
var state = WANDER
var world
var player
var dir = Vector3.ZERO
var turn_timer = 0.0
var step_timer = 0.0
var growl_timer = 5.0
var game_time = 0.0
var peek_wait = 0.0
var peek_time = 0.0
var peek_dist = 0.0
var sight_cd = 5.0
var sight_check = 0.0
var chase_time = 0.0
var lost_time = 0.0
var path_timer = 0.0
var waypoint = Vector3.ZERO
var puffs = []
var t_anim = 0.0

func _ready():
	world = get_parent()
	player = world.player
	chase_speed = Game.CHASE_SPEEDS[Game.diff]
	chase_chance = Game.CHASE_CHANCES[Game.diff]
	sight_range = Game.SIGHT_RANGES[Game.diff]
	peek_wait = next_peek_wait()
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 2.2
	col.shape = shape
	col.position.y = 1.1
	add_child(col)
	build_body()
	$Step.max_distance = 25
	$Step.unit_size = 6
	$Step.pitch_scale = 0.6
	$Growl.max_distance = 70
	$Growl.unit_size = 12
	pick_dir()

func add_part(parent, mesh, pos, mat, rot = Vector3.ZERO):
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func make_puff(parent, r, pos, mat, amp):
	var m = SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	var mi = add_part(parent, m, pos, mat)
	puffs.append({"n": mi, "base": pos, "ph": randf() * TAU, "amp": amp})

func build_body():
	var smoke = StandardMaterial3D.new()
	smoke.albedo_color = Color(0.04, 0.04, 0.06, 0.4)
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color(0.01, 0.01, 0.015, 0.92)
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var glow = StandardMaterial3D.new()
	glow.albedo_color = Color(1, 1, 1)
	glow.emission_enabled = true
	glow.emission = Color(1, 1, 1)
	glow.emission_energy_multiplier = 2.5

	for i in 12:
		var r = lerpf(0.4, 0.2, float(i) / 11.0)
		var p = Vector3(randf_range(-0.08, 0.08), 0.2 + i * 0.12, randf_range(-0.08, 0.08))
		make_puff(self, r, p, smoke, 0.05)

	for sx in [-1.0, 1.0]:
		for j in 6:
			var p2 = Vector3(sx * (0.32 + j * 0.02), 1.45 - j * 0.2, randf_range(-0.05, 0.05))
			make_puff(self, lerpf(0.11, 0.05, float(j) / 5.0), p2, smoke, 0.06)

	var head_node = Node3D.new()
	head_node.position = Vector3(0, 1.95, 0)
	head_node.rotation.z = 0.2
	add_child(head_node)
	var head = SphereMesh.new()
	head.radius = 0.17
	head.height = 0.5
	head.radial_segments = 16
	head.rings = 8
	add_part(head_node, head, Vector3.ZERO, dark)
	for sx in [-1.0, 1.0]:
		var eye = SphereMesh.new()
		eye.radius = 0.035
		eye.height = 0.07
		eye.radial_segments = 8
		eye.rings = 4
		var e = add_part(head_node, eye, Vector3(sx * 0.07, 0.05, -0.145), glow, Vector3(0, 0, sx * 0.35))
		e.scale = Vector3(1.8, 0.7, 0.6)
	var mouth = SphereMesh.new()
	mouth.radius = 0.06
	mouth.height = 0.12
	mouth.radial_segments = 8
	mouth.rings = 4
	var mo = add_part(head_node, mouth, Vector3(0, -0.1, -0.14), glow)
	mo.scale = Vector3(1.4, 0.2, 0.4)
	for k in 4:
		var wp = Vector3(randf_range(-0.22, 0.22), randf_range(-0.2, 0.25), randf_range(-0.1, 0.15))
		make_puff(head_node, 0.07, wp, smoke, 0.08)

func _process(delta):
	t_anim += delta
	for p in puffs:
		var a = t_anim * 1.5 + p["ph"]
		p["n"].position = p["base"] + Vector3(sin(a), sin(a * 1.3) * 0.6, cos(a * 0.9)) * p["amp"]

func next_peek_wait():
	var k = clamp(game_time / 600.0, 0.0, 1.0)
	return randf_range(lerpf(70.0, 25.0, k), lerpf(120.0, 50.0, k))

func pick_dir():
	var a = randf() * TAU
	dir = Vector3(cos(a), 0, sin(a))
	turn_timer = randf_range(2.0, 5.0)

func flat_dist():
	var v = player.global_position - global_position
	v.y = 0
	return v.length()

func cell_of(p):
	return Vector2i(roundi(p.x / world.TILE), roundi(p.z / world.TILE))

func clear_line(from_pos):
	var q = PhysicsRayQueryParameters3D.create(from_pos, player.global_position + Vector3(0, 0.7, 0))
	q.exclude = [get_rid(), player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func try_peek():
	var pp = player.global_position
	var fwd = -player.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	for t in 200:
		var a = randf() * TAU
		var off = Vector3(cos(a), 0, sin(a))
		if off.dot(fwd) < 0.3:
			continue
		var dist = randf_range(14.0, 20.0)
		var x = roundi((pp.x + off.x * dist) / world.TILE)
		var y = roundi((pp.z + off.z * dist) / world.TILE)
		if world.is_wall(x, y):
			continue
		var pos = Vector3(x * world.TILE, 0.1, y * world.TILE)
		if clear_line(pos + Vector3(0, 1.6, 0)):
			global_position = pos
			return true
	return false

func next_step(from_cell, to_cell):
	var came = {from_cell: from_cell}
	var queue = [from_cell]
	var i = 0
	while i < queue.size():
		var c = queue[i]
		i += 1
		if c == to_cell:
			break
		for d in DIRS:
			var n = c + d
			if came.has(n):
				continue
			if abs(n.x - from_cell.x) > 22 or abs(n.y - from_cell.y) > 22:
				continue
			if world.is_wall(n.x, n.y):
				continue
			came[n] = c
			queue.append(n)
	if not came.has(to_cell):
		return null
	var c = to_cell
	while came[c] != from_cell:
		c = came[c]
	return c

func enter_peek():
	state = PEEK
	peek_time = 0.0
	peek_dist = flat_dist()
	velocity = Vector3.ZERO
	$Growl.play()
	$Scare.play()

func start_chase():
	if state == WANDER:
		$Scare.play()
	state = CHASE
	chase_time = 0.0
	lost_time = 0.0
	path_timer = 0.0
	waypoint = Vector3.ZERO + global_position
	$Growl.play()

func end_chase():
	state = WANDER
	sight_cd = 10.0
	pick_dir()

func _physics_process(delta):
	game_time += delta
	if not is_on_floor():
		velocity += get_gravity() * delta
	var d = flat_dist()
	if state == WANDER:
		do_wander(delta, d)
	elif state == PEEK:
		do_peek(delta, d)
	else:
		do_chase(delta, d)
	move_and_slide()

	if state != PEEK:
		step_timer -= delta
		if step_timer <= 0:
			$Step.play()
			step_timer = 0.4 if state == CHASE else 0.7
		growl_timer -= delta
		if growl_timer <= 0:
			$Growl.play()
			growl_timer = randf_range(8.0, 16.0)

func do_wander(delta, d):
	turn_timer -= delta
	if turn_timer <= 0 or is_on_wall():
		pick_dir()
	velocity.x = dir.x * WANDER_SPEED
	velocity.z = dir.z * WANDER_SPEED
	if dir.length() > 0.1:
		look_at(global_position + dir)
	peek_wait -= delta
	sight_cd -= delta
	if peek_wait <= 0:
		if try_peek():
			enter_peek()
		else:
			peek_wait = 1.5
		return
	sight_check -= delta
	if sight_check <= 0:
		sight_check = 0.4
		if sight_cd <= 0 and d < sight_range and clear_line(global_position + Vector3(0, 1.6, 0)):
			if randf() < chase_chance:
				start_chase()
			else:
				sight_cd = 25.0
				enter_peek()

func do_peek(delta, d):
	velocity.x = 0
	velocity.z = 0
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z))
	peek_time += delta
	if d < peek_dist - 4.0 or d < 9.0:
		start_chase()
	elif peek_time > 8.0:
		state = WANDER
		peek_wait = next_peek_wait()
		sight_cd = 20.0
		world.spawn_monster()

func do_chase(delta, d):
	chase_time += delta
	path_timer -= delta
	if path_timer <= 0:
		path_timer = 0.3
		if clear_line(global_position + Vector3(0, 1.6, 0)):
			lost_time = 0.0
		else:
			lost_time += 0.3
		var step = next_step(cell_of(global_position), cell_of(player.global_position))
		if step != null:
			waypoint = Vector3(step.x * world.TILE, 0, step.y * world.TILE)
	var target = waypoint
	if d < 3.0:
		target = player.global_position
	var to = target - global_position
	to.y = 0
	if to.length() > 0.1:
		to = to.normalized()
		velocity.x = to.x * chase_speed
		velocity.z = to.z * chase_speed
		look_at(global_position + to)
	if d < 1.4:
		world.caught()
	elif lost_time > 4.0 or d > 35.0 or chase_time > 20.0:
		end_chase()
