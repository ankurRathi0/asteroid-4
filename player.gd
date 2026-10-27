extends CharacterBody3D

const WALK_SPEED = 5.0
const RUN_SPEED = 10.0
const JUMP_VELOCITY = 4.5
const MAX_STAMINA = 150.0
const DRAIN = 15.0
const REFILL = 10.0
const FORCE_TOUCH = false
const JOY_R = 110.0

var stamina = MAX_STAMINA
var tired = false
var step_timer = 0.0
var bar
var touch = false
var overlay
var screen_size = Vector2(1280, 720)
var move_vec = Vector2.ZERO
var joy_id = -1
var look_id = -1
var joy_base = Vector2.ZERO
var held = {}
var buttons = []
var flash
var bob = 0.0
var bob_amp = 0.0
var breath = 0.0

func _ready():
	touch = FORCE_TOUCH or OS.has_feature("mobile")
	if not touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_key("move_left", KEY_A)
	add_key("move_right", KEY_D)
	add_key("move_forward", KEY_W)
	add_key("move_back", KEY_S)
	add_key("run", KEY_SHIFT)
	add_key("jump", KEY_SPACE)
	add_key("interact", KEY_E)
	add_key("flashlight", KEY_F)
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
	InputMap.action_add_event("fire", click)
	make_bar()
	make_flashlight()
	if touch:
		make_touch_ui()

func make_flashlight():
	flash = SpotLight3D.new()
	flash.spot_range = 20.0
	flash.spot_angle = 26.0
	flash.spot_attenuation = 1.2
	flash.spot_angle_attenuation = 0.6
	flash.light_energy = 3.0
	flash.light_color = Color(1.0, 0.93, 0.8)
	flash.shadow_enabled = true
	flash.position = Vector3(0.15, -0.1, 0)
	flash.visible = false
	$Camera3D.add_child(flash)

func make_bar():
	var layer = CanvasLayer.new()
	add_child(layer)
	bar = ProgressBar.new()
	bar.max_value = MAX_STAMINA
	bar.value = MAX_STAMINA
	bar.show_percentage = false
	bar.position = Vector2(20, 20)
	bar.size = Vector2(200, 16)
	layer.add_child(bar)

func make_touch_ui():
	var layer = CanvasLayer.new()
	add_child(layer)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(draw_touch)
	layer.add_child(overlay)
	layout()

func layout():
	var s = get_viewport().get_visible_rect().size
	screen_size = s
	buttons = [
		{"name": "JUMP", "action": "jump", "pos": Vector2(s.x - 130, s.y - 150), "r": 75.0},
		{"name": "RUN", "action": "run", "pos": Vector2(s.x - 330, s.y - 110), "r": 65.0},
		{"name": "LIGHT", "action": "flashlight", "pos": Vector2(s.x - 130, s.y - 330), "r": 55.0},
	]
func draw_touch():
	layout()
	var base = Vector2(180, screen_size.y - 170)
	if joy_id != -1:
		base = joy_base
	overlay.draw_circle(base, JOY_R, Color(1, 1, 1, 0.12))
	overlay.draw_circle(base + move_vec * JOY_R, 45, Color(1, 1, 1, 0.35))
	for b in buttons:
		var down = held.values().has(b["action"])
		var a = 0.35 if down else 0.15
		overlay.draw_circle(b["pos"], b["r"], Color(1, 1, 1, a))
		overlay.draw_string(ThemeDB.fallback_font, b["pos"] + Vector2(-40, 8), b["name"], HORIZONTAL_ALIGNMENT_CENTER, 80, 22)

func add_key(action, key):
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e = InputEventKey.new()
	e.physical_keycode = key
	InputMap.action_add_event(action, e)

func _process(_delta):
	if touch:
		overlay.queue_redraw()
	if flash.visible:
		var m = get_parent().monster
		var near = m != null and m.global_position.distance_to(global_position) < 12.0
		flash.light_energy = randf_range(0.0, 1.5) if near and randf() < 0.2 else 3.0

func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		$Jump.play()
	if Input.is_action_just_pressed("flashlight"):
		flash.visible = not flash.visible

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if move_vec.length() > 0.15:
		input_dir = move_vec
	var running = Input.is_action_pressed("run") and input_dir != Vector2.ZERO and not tired

	if running:
		stamina -= DRAIN * delta
		if stamina <= 0:
			stamina = 0
			tired = true
	else:
		stamina = min(stamina + REFILL * delta, MAX_STAMINA)
		if tired and stamina >= 20:
			tired = false
	bar.value = stamina

	var speed = RUN_SPEED if running else WALK_SPEED
	var dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()

	var moving = is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.5
	if moving:
		step_timer -= delta
		if step_timer <= 0:
			$Step.pitch_scale = randf_range(0.9, 1.1)
			$Step.play()
			step_timer = 0.3 if running else 0.5
	else:
		step_timer = 0.0

	var hv = Vector2(velocity.x, velocity.z).length()
	if moving:
		bob += delta * hv * 1.4
	bob_amp = lerpf(bob_amp, minf(hv / WALK_SPEED, 2.0) if moving else 0.0, delta * 8.0)
	breath += delta * (2.6 if tired else 1.2)
	var cam = $Camera3D
	cam.position.y = 0.7 + sin(bob * 2.0) * 0.04 * bob_amp + sin(breath) * (0.025 if tired else 0.008)
	cam.position.x = cos(bob) * 0.03 * bob_amp
	cam.fov = lerpf(cam.fov, 82.0 if running else 75.0, delta * 4.0)

func rotate_view(rel):
	rotate_y(-rel.x)
	var cam = $Camera3D
	cam.rotate_x(-rel.y)
	cam.rotation.x = clamp(cam.rotation.x, -1.5, 1.5)

func _input(event):
	if touch:
		touch_event(event)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_view(event.relative * 0.003 * Game.sens)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func touch_event(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_down(event.index, event.position)
		else:
			touch_up(event.index)
	elif event is InputEventScreenDrag:
		if event.index == joy_id:
			move_vec = (event.position - joy_base).limit_length(JOY_R) / JOY_R
		elif event.index == look_id:
			rotate_view(event.relative * 0.004 * Game.sens)

func touch_down(i, pos):
	for b in buttons:
		if pos.distance_to(b["pos"]) <= b["r"]:
			Input.action_press(b["action"])
			held[i] = b["action"]
			return
	if pos.x < screen_size.x * 0.4 and joy_id == -1:
		joy_id = i
		joy_base = pos
		move_vec = Vector2.ZERO
	elif look_id == -1:
		look_id = i

func touch_up(i):
	if held.has(i):
		Input.action_release(held[i])
		held.erase(i)
	elif i == joy_id:
		joy_id = -1
		move_vec = Vector2.ZERO
	elif i == look_id:
		look_id = -1
