extends Node3D

const MathUtil = preload("res://scripts/math_util.gd")

const ARENA_HALF_SIZE := 72.0
const INITIAL_RADIUS := 1.15
const MAX_AREA := 125.0
const PROP_COUNT := 700
const BOT_COUNT := 3
const MATCH_SECONDS := 120.0
const COUNTDOWN_SECONDS := 3.0
const CONSUME_RADIUS_FACTOR := 0.82
const CONSUME_EFFECT_SECONDS := 0.22
const GROWTH_PULSE_SECONDS := 0.34
const SCORE_POPUP_SECONDS := 0.72
const UNLOCK_POPUP_SECONDS := 1.35
const TOO_BIG_TILT_DEGREES := 16.0
const TOO_BIG_FALL_DEGREES := 78.0
const TOO_BIG_FALL_PRESSURE_SECONDS := 0.55
const PROP_RECOVER_RATE := 4.5
const PROP_MARKER_NEAR_MARGIN := 1.6
const HOLE_EAT_RADIUS_MARGIN := 1.12
const HOLE_EAT_SCORE_BASE := 180
const HOLE_EAT_AREA_FACTOR := 0.30
const RESPAWN_SECONDS := 2.25
const BOT_HOLE_DETECTION_RADIUS := 15.0
const BOT_HUNT_WEIGHT := 1.35
const BOT_AVOID_WEIGHT := 2.10
const BOT_AVOID_DISTANCE := 8.0
const EVENT_FEED_MAX_LINES := 6
const MINIMAP_SIZE := 150.0
const MINIMAP_PROP_LIMIT := 28
const BASE_SPEED := 8.0
const MIN_SPEED := 4.2
const ACCELERATION := 22.0
const DECELERATION := 28.0
const MAP_SEED := 43021
const SPAWN_ALGO_VERSION := 1
const PROFILE_SAVE_PATH := "user://profile.cfg"
const JOYSTICK_SIZE := 128.0
const JOYSTICK_KNOB_SIZE := 44.0
const BOT_DIFFICULTY_CASUAL := 0
const BOT_DIFFICULTY_NORMAL := 1
const BOT_DIFFICULTY_HARD := 2
const BOT_NAMES := ["Riley", "Morgan", "Casey"]
const BOT_START_POSITIONS := [
	Vector3(-45.0, 0.0, -45.0),
	Vector3(45.0, 0.0, -39.0),
	Vector3(0.0, 0.0, 48.0),
]
const BOT_COLORS := [
	Color(0.85, 0.18, 0.24),
	Color(0.18, 0.38, 0.92),
	Color(0.95, 0.70, 0.14),
]

enum MatchPhase { MENU, COUNTDOWN, PLAYING, PAUSED, ENDED }

var prop_tiers := []
var props := []
var bots := []
var materials := {}
var velocity := Vector3.ZERO
var hole_area := 0.0
var hole_radius := INITIAL_RADIUS
var score := 0
var best_score := 0
var player_props_eaten := 0
var player_holes_eaten := 0
var player_times_eaten := 0
var player_biggest_prop_name := "None"
var player_biggest_prop_area := 0.0
var player_name := "You"
var player_unlocked_prop_names := {}
var player_alive := true
var player_respawn_remaining := 0.0
var remaining_count := 0
var selected_match_seconds := MATCH_SECONDS
var selected_map_seed := MAP_SEED
var selected_bot_count := BOT_COUNT
var selected_bot_difficulty := BOT_DIFFICULTY_NORMAL
var time_remaining := MATCH_SECONDS
var countdown_remaining := COUNTDOWN_SECONDS
var match_phase := MatchPhase.COUNTDOWN
var phase_before_pause := MatchPhase.PLAYING
var event_feed_messages := []
var joystick_input_vector := Vector2.ZERO
var joystick_dragging := false
var joystick_pointer_id := -1
var consumption_actors_cache: Array = []
var consumption_actor_positions_cache: PackedVector2Array = PackedVector2Array()
var max_actor_radius_cache: float = INITIAL_RADIUS

var player_root: Node3D
var hole_mesh: MeshInstance3D
var consume_mesh: MeshInstance3D
var player_name_label: Label3D
var props_root: Node3D
var bots_root: Node3D
var effects_root: Node3D
var camera: Camera3D
var hud_layer: CanvasLayer
var floating_text_root: Control
var phase_label: Label
var score_label: Label
var size_label: Label
var timer_label: Label
var remaining_label: Label
var rank_label: Label
var growth_label: Label
var stats_label: Label
var leaderboard_label: Label
var event_feed_label: Label
var minimap: Control
var message_label: Label
var menu_panel: PanelContainer
var menu_title_label: Label
var menu_best_label: Label
var player_name_edit: LineEdit
var play_practice_button: Button
var duration_option: OptionButton
var seed_option: OptionButton
var rival_count_option: OptionButton
var bot_difficulty_option: OptionButton
var host_match_button: Button
var join_match_button: Button
var pause_panel: PanelContainer
var pause_title_label: Label
var resume_button: Button
var pause_restart_button: Button
var pause_menu_button: Button
var result_panel: PanelContainer
var result_label: Label
var restart_button: Button
var joystick_base: Panel
var joystick_knob: Panel


func _ready() -> void:
	_configure_input_actions()
	_create_materials()
	_create_prop_tiers()
	_load_profile()
	_build_world()
	_build_hud()
	reset_match(false)


func _physics_process(delta: float) -> void:
	match match_phase:
		MatchPhase.MENU:
			if Input.is_action_just_pressed("restart_match"):
				_start_practice_match()
		MatchPhase.COUNTDOWN:
			if Input.is_action_just_pressed("pause_match"):
				_pause_match()
				_update_camera(delta)
				_update_hud()
				return
			countdown_remaining -= delta
			if countdown_remaining <= 0.0:
				countdown_remaining = 0.0
				match_phase = MatchPhase.PLAYING
				message_label.text = ""
		MatchPhase.PLAYING:
			if Input.is_action_just_pressed("pause_match"):
				_pause_match()
				_update_camera(delta)
				_update_hud()
				return
			time_remaining -= delta
			if time_remaining <= 0.0:
				time_remaining = 0.0
				_end_match("Time up")
			else:
				_update_respawns(delta)
				_handle_movement(delta)
				_update_bots(delta)
				_refresh_interaction_cache()
				_update_too_big_prop_feedback(delta)
				_update_prop_markers()
				_check_consumption()
				_check_hole_consumption()
		MatchPhase.PAUSED:
			if Input.is_action_just_pressed("pause_match"):
				_resume_match()
		MatchPhase.ENDED:
			if Input.is_action_just_pressed("restart_match"):
				reset_match()

	_update_camera(delta)
	_update_hud()


func reset_match(start_countdown := true) -> void:
	hole_area = PI * INITIAL_RADIUS * INITIAL_RADIUS
	hole_radius = INITIAL_RADIUS
	score = 0
	player_props_eaten = 0
	player_holes_eaten = 0
	player_times_eaten = 0
	player_biggest_prop_name = "None"
	player_biggest_prop_area = 0.0
	_reset_player_unlocks()
	player_alive = true
	player_respawn_remaining = 0.0
	if player_name_label:
		player_name_label.text = player_name
	remaining_count = 0
	time_remaining = selected_match_seconds
	countdown_remaining = COUNTDOWN_SECONDS
	match_phase = MatchPhase.COUNTDOWN if start_countdown else MatchPhase.MENU
	phase_before_pause = MatchPhase.PLAYING
	_clear_event_feed()
	velocity = Vector3.ZERO
	_reset_joystick()
	player_root.position = Vector3.ZERO
	player_root.show()
	message_label.text = ""
	if restart_button:
		restart_button.hide()
	if menu_panel:
		menu_panel.visible = not start_countdown
	if pause_panel:
		pause_panel.hide()
	if result_panel:
		result_panel.hide()
	_clear_feedback_effects()
	_update_hole_visual()
	_reset_bots()
	_spawn_props()
	if start_countdown:
		_add_event_feed_message("Practice started: %d rivals, %s AI" % [selected_bot_count, _get_bot_difficulty_name()])
	_update_camera(1.0)
	_update_hud()


func _start_practice_match() -> void:
	reset_match(true)


func _on_player_name_changed(new_text: String) -> void:
	var clean_name := new_text.strip_edges()
	player_name = clean_name if not clean_name.is_empty() else "You"
	if player_name_label:
		player_name_label.text = player_name
	_update_hud()


func _on_duration_selected(index: int) -> void:
	if not duration_option:
		return

	selected_match_seconds = float(duration_option.get_item_id(index))
	time_remaining = selected_match_seconds
	_update_hud()


func _on_seed_selected(index: int) -> void:
	if not seed_option:
		return

	selected_map_seed = seed_option.get_item_id(index)


func _on_rival_count_selected(index: int) -> void:
	if not rival_count_option:
		return

	selected_bot_count = rival_count_option.get_item_id(index)
	_update_hud()


func _on_bot_difficulty_selected(index: int) -> void:
	if not bot_difficulty_option:
		return

	selected_bot_difficulty = bot_difficulty_option.get_item_id(index)
	_update_hud()


func _reset_player_unlocks() -> void:
	player_unlocked_prop_names = {}
	for tier in prop_tiers:
		if _get_tier_fit_radius(tier) <= INITIAL_RADIUS:
			player_unlocked_prop_names[String(tier["name"])] = true


func _pause_match() -> void:
	if match_phase != MatchPhase.COUNTDOWN and match_phase != MatchPhase.PLAYING:
		return

	phase_before_pause = match_phase
	match_phase = MatchPhase.PAUSED
	velocity = Vector3.ZERO
	for bot in bots:
		bot["velocity"] = Vector3.ZERO


func _resume_match() -> void:
	if match_phase != MatchPhase.PAUSED:
		return

	match_phase = phase_before_pause


func _return_to_menu() -> void:
	reset_match(false)


func _configure_input_actions() -> void:
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("move_forward", [KEY_W, KEY_UP])
	_bind_keys("move_back", [KEY_S, KEY_DOWN])
	_bind_keys("restart_match", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
	_bind_keys("pause_match", [KEY_ESCAPE, KEY_P])


func _bind_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)


func _create_materials() -> void:
	materials["floor"] = _make_material(Color(0.18, 0.48, 0.28))
	materials["wall"] = _make_material(Color(0.12, 0.18, 0.20))
	materials["hole"] = _make_material(Color(0.015, 0.017, 0.02))
	materials["consume"] = _make_transparent_material(Color(0.1, 0.68, 0.78, 0.22))
	materials["trunk"] = _make_material(Color(0.37, 0.21, 0.10))
	materials["leaves"] = _make_material(Color(0.09, 0.40, 0.16))
	materials["marker_edible"] = _make_transparent_material(Color(0.24, 0.92, 0.46, 0.36))
	materials["marker_too_big"] = _make_transparent_material(Color(1.0, 0.72, 0.18, 0.34))


func _create_prop_tiers() -> void:
	prop_tiers = [
		{"name": "Can", "tier": 1, "shape": "cylinder", "required_radius": 0.70, "area": 0.18, "score": 10, "scale": Vector3(0.35, 0.65, 0.35), "collision_radius": 0.18, "color": Color(0.90, 0.72, 0.16), "weight": 28},
		{"name": "Box", "tier": 1, "shape": "box", "required_radius": 0.90, "area": 0.24, "score": 15, "scale": Vector3(0.65, 0.55, 0.65), "collision_radius": 0.46, "color": Color(0.66, 0.42, 0.22), "weight": 26},
		{"name": "Ball", "tier": 1, "shape": "sphere", "required_radius": 0.85, "area": 0.28, "score": 18, "scale": Vector3(0.70, 0.70, 0.70), "collision_radius": 0.35, "color": Color(0.86, 0.22, 0.28), "weight": 18},
		{"name": "Bin", "tier": 2, "shape": "cylinder", "required_radius": 1.20, "area": 0.58, "score": 35, "scale": Vector3(0.75, 1.05, 0.75), "collision_radius": 0.38, "color": Color(0.16, 0.35, 0.72), "weight": 14},
		{"name": "Bench", "tier": 3, "shape": "box", "required_radius": 1.45, "area": 1.35, "score": 75, "scale": Vector3(1.90, 0.45, 0.65), "collision_radius": 1.00, "color": Color(0.55, 0.34, 0.18), "weight": 8},
		{"name": "Car", "tier": 4, "shape": "box", "required_radius": 2.25, "area": 3.00, "score": 140, "scale": Vector3(2.50, 0.80, 1.25), "collision_radius": 1.40, "color": Color(0.06, 0.34, 0.70), "weight": 4},
		{"name": "Tree", "tier": 4, "shape": "tree", "required_radius": 1.65, "area": 5.40, "score": 240, "scale": Vector3(1.50, 2.50, 1.50), "collision_radius": 0.75, "color": Color(0.09, 0.40, 0.16), "weight": 2},
	]


func _build_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.48, 0.68, 0.88)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.74, 0.82, 0.88)
	environment.ambient_light_energy = 0.85
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 2.0
	sun.rotation_degrees = Vector3(-58.0, -34.0, 0.0)
	add_child(sun)

	var floor_mesh := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(ARENA_HALF_SIZE * 2.15, ARENA_HALF_SIZE * 2.15)
	floor_mesh.name = "ArenaFloor"
	floor_mesh.mesh = floor_plane
	floor_mesh.material_override = materials["floor"]
	floor_mesh.position.y = -0.03
	add_child(floor_mesh)

	_add_wall("NorthWall", Vector3(0.0, 0.35, -ARENA_HALF_SIZE), Vector3(ARENA_HALF_SIZE * 2.0, 0.70, 0.45))
	_add_wall("SouthWall", Vector3(0.0, 0.35, ARENA_HALF_SIZE), Vector3(ARENA_HALF_SIZE * 2.0, 0.70, 0.45))
	_add_wall("WestWall", Vector3(-ARENA_HALF_SIZE, 0.35, 0.0), Vector3(0.45, 0.70, ARENA_HALF_SIZE * 2.0))
	_add_wall("EastWall", Vector3(ARENA_HALF_SIZE, 0.35, 0.0), Vector3(0.45, 0.70, ARENA_HALF_SIZE * 2.0))

	player_root = Node3D.new()
	player_root.name = "PlayerHole"
	add_child(player_root)

	hole_mesh = MeshInstance3D.new()
	hole_mesh.name = "HoleDisc"
	hole_mesh.material_override = materials["hole"]
	player_root.add_child(hole_mesh)

	consume_mesh = MeshInstance3D.new()
	consume_mesh.name = "ConsumeRadius"
	consume_mesh.position.y = 0.015
	consume_mesh.material_override = materials["consume"]
	player_root.add_child(consume_mesh)

	player_name_label = Label3D.new()
	player_name_label.text = player_name
	player_name_label.font_size = 28
	player_name_label.position = Vector3(0.0, 0.08, 0.0)
	player_name_label.modulate = Color(0.95, 0.97, 1.0)
	player_root.add_child(player_name_label)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = 56.0
	add_child(camera)

	bots_root = Node3D.new()
	bots_root.name = "Rivals"
	add_child(bots_root)
	_create_bots()

	effects_root = Node3D.new()
	effects_root.name = "Effects"
	add_child(effects_root)


func _create_bots() -> void:
	bots = []
	for index in range(BOT_COUNT):
		var bot_root := Node3D.new()
		bot_root.name = "Rival%s" % BOT_NAMES[index]
		bots_root.add_child(bot_root)

		var bot_hole_mesh := MeshInstance3D.new()
		bot_hole_mesh.name = "HoleDisc"
		bot_hole_mesh.material_override = _make_material(BOT_COLORS[index])
		bot_root.add_child(bot_hole_mesh)

		var bot_consume_mesh := MeshInstance3D.new()
		bot_consume_mesh.name = "ConsumeRadius"
		bot_consume_mesh.position.y = 0.018
		var ring_color: Color = BOT_COLORS[index]
		ring_color.a = 0.18
		bot_consume_mesh.material_override = _make_transparent_material(ring_color)
		bot_root.add_child(bot_consume_mesh)

		var name_label := Label3D.new()
		name_label.text = BOT_NAMES[index]
		name_label.font_size = 28
		name_label.position = Vector3(0.0, 0.08, 0.0)
		name_label.modulate = Color(0.95, 0.97, 1.0)
		bot_root.add_child(name_label)

		bots.append({
			"id": index + 1,
			"name": BOT_NAMES[index],
			"root": bot_root,
			"hole_mesh": bot_hole_mesh,
			"consume_mesh": bot_consume_mesh,
			"label": name_label,
			"area": PI * INITIAL_RADIUS * INITIAL_RADIUS,
			"radius": INITIAL_RADIUS,
			"score": 0,
			"velocity": Vector3.ZERO,
			"target_id": -1,
			"target_cooldown": 0.0,
			"enabled": true,
			"alive": true,
			"respawn_remaining": 0.0,
			"start_position": BOT_START_POSITIONS[index],
			"is_player": false,
		})


func _reset_bots() -> void:
	for index in range(bots.size()):
		var bot: Dictionary = bots[index]
		var is_enabled := index < selected_bot_count
		bot["area"] = PI * INITIAL_RADIUS * INITIAL_RADIUS
		bot["radius"] = INITIAL_RADIUS
		bot["score"] = 0
		bot["velocity"] = Vector3.ZERO
		bot["target_id"] = -1
		bot["target_cooldown"] = 0.0
		bot["enabled"] = is_enabled
		bot["alive"] = is_enabled
		bot["respawn_remaining"] = 0.0
		var bot_root := bot["root"] as Node3D
		bot_root.position = BOT_START_POSITIONS[index]
		bot_root.visible = is_enabled
		_update_bot_visual(bot)


func _update_bot_visual(bot: Dictionary) -> void:
	var radius := float(bot["radius"])
	var bot_hole_mesh := bot["hole_mesh"] as MeshInstance3D
	var hole_disc := CylinderMesh.new()
	hole_disc.top_radius = radius
	hole_disc.bottom_radius = radius
	hole_disc.height = 0.08
	hole_disc.radial_segments = 64
	bot_hole_mesh.mesh = hole_disc
	bot_hole_mesh.position.y = 0.016

	var bot_consume_mesh := bot["consume_mesh"] as MeshInstance3D
	var consume_disc := CylinderMesh.new()
	consume_disc.top_radius = radius * CONSUME_RADIUS_FACTOR
	consume_disc.bottom_radius = radius * CONSUME_RADIUS_FACTOR
	consume_disc.height = 0.025
	consume_disc.radial_segments = 64
	bot_consume_mesh.mesh = consume_disc


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud_layer = hud
	add_child(hud)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.offset_left = 16.0
	margin.offset_top = 12.0
	margin.offset_right = -16.0
	margin.offset_bottom = 64.0
	hud.add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.045, 0.050, 0.82)))
	margin.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)

	phase_label = _hud_label()
	score_label = _hud_label()
	size_label = _hud_label()
	timer_label = _hud_label()
	remaining_label = _hud_label()
	rank_label = _hud_label()
	growth_label = _hud_label()
	stats_label = _hud_label()
	row.add_child(phase_label)
	row.add_child(score_label)
	row.add_child(size_label)
	row.add_child(timer_label)
	row.add_child(remaining_label)
	row.add_child(rank_label)
	row.add_child(growth_label)
	row.add_child(stats_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var controls := _hud_label(16)
	controls.text = "WASD / arrows / joystick move"
	row.add_child(controls)

	var leaderboard_panel := PanelContainer.new()
	leaderboard_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	leaderboard_panel.offset_left = -236.0
	leaderboard_panel.offset_top = 82.0
	leaderboard_panel.offset_right = -16.0
	leaderboard_panel.offset_bottom = 218.0
	leaderboard_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.045, 0.050, 0.72)))
	hud.add_child(leaderboard_panel)

	leaderboard_label = _hud_label(16)
	leaderboard_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	leaderboard_panel.add_child(leaderboard_label)

	var event_feed_panel := PanelContainer.new()
	event_feed_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	event_feed_panel.offset_left = 16.0
	event_feed_panel.offset_top = 82.0
	event_feed_panel.offset_right = 342.0
	event_feed_panel.offset_bottom = 218.0
	event_feed_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.045, 0.050, 0.62)))
	hud.add_child(event_feed_panel)

	event_feed_label = _hud_label(15)
	event_feed_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	event_feed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_feed_panel.add_child(event_feed_label)

	minimap = Control.new()
	minimap.name = "Minimap"
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.offset_left = -MINIMAP_SIZE - 16.0
	minimap.offset_top = -MINIMAP_SIZE - 16.0
	minimap.offset_right = -16.0
	minimap.offset_bottom = -16.0
	minimap.custom_minimum_size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_minimap)
	hud.add_child(minimap)

	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.offset_left = -210.0
	menu_panel.offset_top = -262.0
	menu_panel.offset_right = 210.0
	menu_panel.offset_bottom = 262.0
	menu_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.045, 0.050, 0.92)))
	hud.add_child(menu_panel)

	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 12)
	menu_panel.add_child(menu_box)

	menu_title_label = _hud_label(30)
	menu_title_label.text = "Corn Hole"
	menu_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(menu_title_label)

	menu_best_label = _hud_label(16)
	menu_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(menu_best_label)

	var name_label := _hud_label(16)
	name_label.text = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(name_label)

	player_name_edit = LineEdit.new()
	player_name_edit.text = player_name
	player_name_edit.max_length = 14
	player_name_edit.placeholder_text = "Player name"
	player_name_edit.text_changed.connect(_on_player_name_changed)
	menu_box.add_child(player_name_edit)

	var duration_label := _hud_label(16)
	duration_label.text = "Match length"
	duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(duration_label)

	duration_option = OptionButton.new()
	duration_option.add_item("1 minute", 60)
	duration_option.add_item("2 minutes", 120)
	duration_option.add_item("3 minutes", 180)
	duration_option.select(1)
	duration_option.item_selected.connect(_on_duration_selected)
	menu_box.add_child(duration_option)

	var seed_label := _hud_label(16)
	seed_label.text = "Arena seed"
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(seed_label)

	seed_option = OptionButton.new()
	seed_option.add_item("Classic", MAP_SEED)
	seed_option.add_item("Dense North", 77031)
	seed_option.add_item("Wide Scatter", 99173)
	seed_option.add_item("Big Finish", 24680)
	seed_option.select(0)
	seed_option.item_selected.connect(_on_seed_selected)
	menu_box.add_child(seed_option)

	var rival_count_label := _hud_label(16)
	rival_count_label.text = "Rivals"
	rival_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(rival_count_label)

	rival_count_option = OptionButton.new()
	for count in range(BOT_COUNT + 1):
		rival_count_option.add_item("%d" % count, count)
	rival_count_option.select(BOT_COUNT)
	rival_count_option.item_selected.connect(_on_rival_count_selected)
	menu_box.add_child(rival_count_option)

	var bot_difficulty_label := _hud_label(16)
	bot_difficulty_label.text = "Rival skill"
	bot_difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(bot_difficulty_label)

	bot_difficulty_option = OptionButton.new()
	bot_difficulty_option.add_item("Casual", BOT_DIFFICULTY_CASUAL)
	bot_difficulty_option.add_item("Normal", BOT_DIFFICULTY_NORMAL)
	bot_difficulty_option.add_item("Hard", BOT_DIFFICULTY_HARD)
	bot_difficulty_option.select(BOT_DIFFICULTY_NORMAL)
	bot_difficulty_option.item_selected.connect(_on_bot_difficulty_selected)
	menu_box.add_child(bot_difficulty_option)

	play_practice_button = _menu_button("Play Practice")
	play_practice_button.pressed.connect(_start_practice_match)
	menu_box.add_child(play_practice_button)

	host_match_button = _menu_button("Host Match")
	host_match_button.disabled = true
	menu_box.add_child(host_match_button)

	join_match_button = _menu_button("Join Match")
	join_match_button.disabled = true
	menu_box.add_child(join_match_button)

	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -170.0
	pause_panel.offset_top = -132.0
	pause_panel.offset_right = 170.0
	pause_panel.offset_bottom = 132.0
	pause_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.045, 0.050, 0.92)))
	pause_panel.hide()
	hud.add_child(pause_panel)

	var pause_box := VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 12)
	pause_panel.add_child(pause_box)

	pause_title_label = _hud_label(28)
	pause_title_label.text = "Paused"
	pause_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(pause_title_label)

	resume_button = _menu_button("Resume")
	resume_button.pressed.connect(_resume_match)
	pause_box.add_child(resume_button)

	pause_restart_button = _menu_button("Restart Practice")
	pause_restart_button.pressed.connect(_start_practice_match)
	pause_box.add_child(pause_restart_button)

	pause_menu_button = _menu_button("Main Menu")
	pause_menu_button.pressed.connect(_return_to_menu)
	pause_box.add_child(pause_menu_button)

	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER)
	message_label.offset_left = -360.0
	message_label.offset_top = -90.0
	message_label.offset_right = 360.0
	message_label.offset_bottom = 90.0
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 34)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	message_label.add_theme_constant_override("shadow_offset_x", 2)
	message_label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(message_label)

	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -250.0
	result_panel.offset_top = -150.0
	result_panel.offset_right = 250.0
	result_panel.offset_bottom = 136.0
	result_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.045, 0.050, 0.90)))
	result_panel.hide()
	hud.add_child(result_panel)

	result_label = _hud_label(20)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_panel.add_child(result_label)

	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.set_anchors_preset(Control.PRESET_CENTER)
	restart_button.offset_left = -70.0
	restart_button.offset_top = 72.0
	restart_button.offset_right = 70.0
	restart_button.offset_bottom = 116.0
	restart_button.hide()
	restart_button.pressed.connect(reset_match)
	hud.add_child(restart_button)

	floating_text_root = Control.new()
	floating_text_root.name = "FloatingText"
	floating_text_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	floating_text_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(floating_text_root)

	_build_touch_joystick(hud)


func _add_wall(name: String, position: Vector3, size: Vector3) -> void:
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	wall.name = name
	wall.mesh = box
	wall.position = position
	wall.material_override = materials["wall"]
	add_child(wall)


func _spawn_props() -> void:
	if props_root:
		props_root.queue_free()

	props = []
	props_root = Node3D.new()
	props_root.name = "Props"
	add_child(props_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = selected_map_seed

	for id in range(PROP_COUNT):
		var tier := _choose_tier(rng)
		var position := _random_spawn_position(rng)
		var node := Node3D.new()
		node.name = "%s_%03d" % [tier["name"], id]
		node.position = position
		node.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		props_root.add_child(node)
		_build_prop_visual(node, tier)
		var marker := _build_prop_marker(node, tier)
		props.append({
			"id": id,
			"spawn_algo_version": SPAWN_ALGO_VERSION,
			"object_type": tier["name"],
			"tier": tier["tier"],
			"node": node,
			"marker": marker,
			"position": position,
			"base_rotation": node.rotation,
			"rotation_y": node.rotation.y,
			"shape": tier["shape"],
			"footprint": Vector2(float(tier["scale"].x) * 0.5, float(tier["scale"].z) * 0.5),
			"required_radius": tier["required_radius"],
			"area": tier["area"],
			"score": tier["score"],
			"collision_radius": tier["collision_radius"],
			"pressure": 0.0,
			"fallen": false,
			"consumed": false,
		})

	remaining_count = props.size()
	_update_prop_markers()


func _random_spawn_position(rng: RandomNumberGenerator) -> Vector3:
	for attempt in 40:
		var position := Vector3(
			rng.randf_range(-ARENA_HALF_SIZE + 2.0, ARENA_HALF_SIZE - 2.0),
			0.0,
			rng.randf_range(-ARENA_HALF_SIZE + 2.0, ARENA_HALF_SIZE - 2.0)
		)
		if Vector2(position.x, position.z).length() > 4.0:
			return position

	return Vector3(6.0, 0.0, 6.0)


func _choose_tier(rng: RandomNumberGenerator) -> Dictionary:
	var total_weight := 0
	for tier in prop_tiers:
		total_weight += int(tier["weight"])

	var roll := rng.randi_range(1, total_weight)
	var running := 0
	for tier in prop_tiers:
		running += int(tier["weight"])
		if roll <= running:
			return tier

	return prop_tiers[0]


func _build_prop_visual(parent: Node3D, tier: Dictionary) -> void:
	if tier["shape"] == "tree":
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.18
		trunk_mesh.bottom_radius = 0.22
		trunk_mesh.height = 1.35
		trunk.mesh = trunk_mesh
		trunk.position.y = 0.68
		trunk.material_override = materials["trunk"]
		parent.add_child(trunk)

		var leaves := MeshInstance3D.new()
		var leaves_mesh := SphereMesh.new()
		leaves_mesh.radius = 0.72
		leaves_mesh.height = 1.25
		leaves.mesh = leaves_mesh
		leaves.position.y = 1.65
		leaves.material_override = materials["leaves"]
		parent.add_child(leaves)
		return

	var visual := MeshInstance3D.new()
	match String(tier["shape"]):
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			cylinder.radial_segments = 18
			visual.mesh = cylinder
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			visual.mesh = sphere
		_:
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			visual.mesh = box

	var scale: Vector3 = tier["scale"]
	visual.scale = scale
	visual.position.y = scale.y * 0.5
	visual.material_override = _make_material(tier["color"])
	parent.add_child(visual)


func _build_prop_marker(parent: Node3D, tier: Dictionary) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = "EatMarker"
	var marker_mesh := CylinderMesh.new()
	var marker_radius: float = max(float(tier["collision_radius"]), max(float(tier["scale"].x), float(tier["scale"].z)) * 0.5)
	marker_mesh.top_radius = marker_radius * 1.12
	marker_mesh.bottom_radius = marker_radius * 1.12
	marker_mesh.height = 0.018
	marker_mesh.radial_segments = 40
	marker.mesh = marker_mesh
	marker.position.y = 0.012
	marker.hide()
	parent.add_child(marker)
	return marker


func _handle_movement(delta: float) -> void:
	if not player_alive:
		velocity = Vector3.ZERO
		return

	var input_vector := _get_move_input()

	var current_speed: float = max(MIN_SPEED, BASE_SPEED - hole_radius * 0.22)
	var desired_velocity := Vector3(input_vector.x, 0.0, input_vector.y) * current_speed
	var change_rate := ACCELERATION if input_vector.length() > 0.0 else DECELERATION
	velocity = velocity.move_toward(desired_velocity, change_rate * delta)

	var next_position := player_root.position + velocity * delta
	next_position.x = clamp(next_position.x, -ARENA_HALF_SIZE + hole_radius, ARENA_HALF_SIZE - hole_radius)
	next_position.z = clamp(next_position.z, -ARENA_HALF_SIZE + hole_radius, ARENA_HALF_SIZE - hole_radius)
	next_position.y = 0.0
	player_root.position = next_position


func _get_move_input() -> Vector2:
	var keyboard_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)

	var input_vector := keyboard_vector + joystick_input_vector
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	return input_vector


func _update_bots(delta: float) -> void:
	for bot in bots:
		if not bool(bot["enabled"]):
			continue
		if not bool(bot["alive"]):
			continue

		bot["target_cooldown"] = float(bot["target_cooldown"]) - delta
		var current_target := _find_prop_by_id(int(bot["target_id"]))
		var target_invalid := current_target.is_empty() or bool(current_target["consumed"]) or not _can_actor_consume_prop(current_target, float(bot["radius"]))
		if target_invalid or float(bot["target_cooldown"]) <= 0.0:
			_update_bot_target(bot)
			bot["target_cooldown"] = 0.25

		var move_vector := _get_bot_hole_interaction_vector(bot)
		var target_prop := _find_prop_by_id(int(bot["target_id"]))
		if not target_prop.is_empty():
			var target_position: Vector3 = target_prop["position"]
			var bot_root := bot["root"] as Node3D
			var offset := Vector2(
				target_position.x - bot_root.position.x,
				target_position.z - bot_root.position.z
			)
			if offset.length() > 0.05:
				move_vector += offset.normalized()

		move_vector += _get_bot_wall_avoidance(bot)

		if move_vector.length() > 1.0:
			move_vector = move_vector.normalized()

		_move_bot(bot, move_vector, delta)


func _get_bot_wall_avoidance(bot: Dictionary) -> Vector2:
	var bot_root := bot["root"] as Node3D
	var radius := float(bot["radius"])
	var wall_margin: float = 6.0 + radius
	var inner_half: float = ARENA_HALF_SIZE - wall_margin
	var steering := Vector2.ZERO
	if bot_root.position.x > inner_half:
		steering.x -= (bot_root.position.x - inner_half) / wall_margin
	elif bot_root.position.x < -inner_half:
		steering.x += (-inner_half - bot_root.position.x) / wall_margin
	if bot_root.position.z > inner_half:
		steering.y -= (bot_root.position.z - inner_half) / wall_margin
	elif bot_root.position.z < -inner_half:
		steering.y += (-inner_half - bot_root.position.z) / wall_margin
	return steering * 1.4


func _get_bot_hole_interaction_vector(bot: Dictionary) -> Vector2:
	var bot_root := bot["root"] as Node3D
	var bot_flat := Vector2(bot_root.position.x, bot_root.position.z)
	var bot_radius := float(bot["radius"])
	var steering := Vector2.ZERO
	var nearest_hunt_distance := INF
	var nearest_hunt_direction := Vector2.ZERO

	for actor in _get_consumption_actors():
		if int(actor["id"]) == int(bot["id"]):
			continue

		var actor_position := _get_actor_position(actor)
		var actor_flat := Vector2(actor_position.x, actor_position.z)
		var offset := actor_flat - bot_flat
		var distance := offset.length()
		if distance <= 0.001:
			continue

		var actor_radius := _get_actor_radius(actor)
		var direction := offset / distance
		var detection_radius := BOT_HOLE_DETECTION_RADIUS * _get_bot_detection_scale()
		if bot_radius >= actor_radius * HOLE_EAT_RADIUS_MARGIN and distance <= detection_radius:
			if distance < nearest_hunt_distance:
				nearest_hunt_distance = distance
				nearest_hunt_direction = direction
		elif actor_radius >= bot_radius * HOLE_EAT_RADIUS_MARGIN and distance <= BOT_AVOID_DISTANCE * _get_bot_detection_scale() + actor_radius:
			var avoid_distance := BOT_AVOID_DISTANCE * _get_bot_detection_scale() + actor_radius
			var avoid_strength: float = 1.0 - clamp(distance / avoid_distance, 0.0, 1.0)
			steering -= direction * BOT_AVOID_WEIGHT * _get_bot_avoid_scale() * avoid_strength

	if nearest_hunt_direction.length() > 0.0:
		var hunt_strength: float = 1.0 - clamp(nearest_hunt_distance / (BOT_HOLE_DETECTION_RADIUS * _get_bot_detection_scale()), 0.0, 1.0)
		steering += nearest_hunt_direction * BOT_HUNT_WEIGHT * _get_bot_hunt_scale() * max(0.35, hunt_strength)

	return steering


func _update_bot_target(bot: Dictionary) -> void:
	var current_target := _find_prop_by_id(int(bot["target_id"]))
	if not current_target.is_empty():
		if not bool(current_target["consumed"]) and _can_actor_consume_prop(current_target, float(bot["radius"])):
			return

	var bot_root := bot["root"] as Node3D
	var bot_flat := Vector2(bot_root.position.x, bot_root.position.z)
	var best_id := -1
	var best_weighted_distance := INF

	for prop in props:
		if bool(prop["consumed"]):
			continue
		if not _can_actor_consume_prop(prop, float(bot["radius"])):
			continue

		var prop_position: Vector3 = prop["position"]
		var distance := bot_flat.distance_to(Vector2(prop_position.x, prop_position.z))
		var weighted_distance := distance - float(prop["score"]) * _get_bot_score_seek_scale()
		if weighted_distance < best_weighted_distance:
			best_weighted_distance = weighted_distance
			best_id = int(prop["id"])

	bot["target_id"] = best_id


func _find_prop_by_id(prop_id: int) -> Dictionary:
	if prop_id < 0:
		return {}
	for prop in props:
		if int(prop["id"]) == prop_id:
			return prop
	return {}


func _move_bot(bot: Dictionary, move_vector: Vector2, delta: float) -> void:
	var radius := float(bot["radius"])
	var current_speed: float = max(MIN_SPEED * 0.92, (BASE_SPEED - radius * 0.22) * 0.90 * _get_bot_speed_scale())
	var desired_velocity := Vector3(move_vector.x, 0.0, move_vector.y) * current_speed
	var current_velocity: Vector3 = bot["velocity"]
	var change_rate := ACCELERATION if move_vector.length() > 0.0 else DECELERATION
	current_velocity = current_velocity.move_toward(desired_velocity, change_rate * delta)
	bot["velocity"] = current_velocity

	var bot_root := bot["root"] as Node3D
	var next_position := bot_root.position + current_velocity * delta
	next_position.x = clamp(next_position.x, -ARENA_HALF_SIZE + radius, ARENA_HALF_SIZE - radius)
	next_position.z = clamp(next_position.z, -ARENA_HALF_SIZE + radius, ARENA_HALF_SIZE - radius)
	next_position.y = 0.0
	bot_root.position = next_position


func _update_respawns(delta: float) -> void:
	if not player_alive:
		player_respawn_remaining = max(0.0, player_respawn_remaining - delta)
		if player_respawn_remaining <= 0.0:
			_respawn_player()

	for bot in bots:
		if not bool(bot["enabled"]):
			continue
		if bool(bot["alive"]):
			continue

		bot["respawn_remaining"] = max(0.0, float(bot["respawn_remaining"]) - delta)
		if float(bot["respawn_remaining"]) <= 0.0:
			_respawn_bot(bot)


func _respawn_player() -> void:
	var respawn_position := _find_clear_respawn_position(Vector3.ZERO)
	player_alive = true
	player_respawn_remaining = 0.0
	hole_area = PI * INITIAL_RADIUS * INITIAL_RADIUS
	hole_radius = INITIAL_RADIUS
	velocity = Vector3.ZERO
	player_root.position = respawn_position
	player_root.show()
	_update_hole_visual()
	_add_event_feed_message("%s respawned" % player_name)


func _respawn_bot(bot: Dictionary) -> void:
	if not bool(bot["enabled"]):
		return

	var respawn_position := _find_clear_respawn_position(bot["start_position"])
	bot["alive"] = true
	bot["respawn_remaining"] = 0.0
	bot["area"] = PI * INITIAL_RADIUS * INITIAL_RADIUS
	bot["radius"] = INITIAL_RADIUS
	bot["velocity"] = Vector3.ZERO
	bot["target_id"] = -1
	bot["target_cooldown"] = 0.0
	var bot_root := bot["root"] as Node3D
	bot_root.position = respawn_position
	bot_root.show()
	_update_bot_visual(bot)
	_add_event_feed_message("%s respawned" % String(bot["name"]))


func _find_clear_respawn_position(preferred_position: Vector3) -> Vector3:
	var best_position := preferred_position
	var best_distance := -INF
	var candidates := [
		preferred_position,
		Vector3(-18.0, 0.0, 18.0),
		Vector3(18.0, 0.0, 18.0),
		Vector3(-18.0, 0.0, -18.0),
		Vector3(18.0, 0.0, -18.0),
		Vector3.ZERO,
	]

	for candidate in candidates:
		var nearest_distance := INF
		for actor in _get_consumption_actors():
			var actor_position := _get_actor_position(actor)
			var distance := Vector2(candidate.x, candidate.z).distance_to(Vector2(actor_position.x, actor_position.z))
			nearest_distance = min(nearest_distance, distance)

		if nearest_distance > best_distance:
			best_distance = nearest_distance
			best_position = candidate

	best_position.x = clamp(best_position.x, -ARENA_HALF_SIZE + INITIAL_RADIUS, ARENA_HALF_SIZE - INITIAL_RADIUS)
	best_position.z = clamp(best_position.z, -ARENA_HALF_SIZE + INITIAL_RADIUS, ARENA_HALF_SIZE - INITIAL_RADIUS)
	best_position.y = 0.0
	return best_position


func _update_too_big_prop_feedback(delta: float) -> void:
	for prop in props:
		if bool(prop["consumed"]):
			continue

		var prop_position: Vector3 = prop["position"]
		if not _is_prop_potentially_interactive(Vector2(prop_position.x, prop_position.z), 0.0):
			_recover_too_big_prop(prop, delta)
			continue

		var actor := _find_too_big_pressure_actor(prop)
		if actor.is_empty():
			_recover_too_big_prop(prop, delta)
			continue

		prop["pressure"] = float(prop["pressure"]) + delta
		if float(prop["pressure"]) >= TOO_BIG_FALL_PRESSURE_SECONDS and _get_actor_radius(actor) >= _get_prop_fit_radius(prop) * 0.68:
			prop["fallen"] = true

		_apply_too_big_prop_pose(prop, actor)


func _find_too_big_pressure_actor(prop: Dictionary) -> Dictionary:
	var prop_position: Vector3 = prop["position"]
	var prop_flat := Vector2(prop_position.x, prop_position.z)
	var best_actor := {}
	var best_distance := INF

	for actor in consumption_actors_cache:
		var actor_radius := _get_actor_radius(actor)
		if _can_actor_consume_prop(prop, actor_radius):
			continue

		var actor_position := _get_actor_position(actor)
		var actor_flat := Vector2(actor_position.x, actor_position.z)
		if not _does_prop_footprint_touch_consume_radius(prop, actor_flat, actor_radius):
			continue

		var distance := actor_flat.distance_to(prop_flat)
		if distance < best_distance:
			best_actor = actor
			best_distance = distance

	return best_actor


func _apply_too_big_prop_pose(prop: Dictionary, actor: Dictionary) -> void:
	var prop_node := prop["node"] as Node3D
	if not is_instance_valid(prop_node):
		return

	var prop_position: Vector3 = prop["position"]
	var actor_position := _get_actor_position(actor)
	var direction := Vector2(actor_position.x - prop_position.x, actor_position.z - prop_position.z)
	if direction.length() <= 0.001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()

	var pressure_ratio: float = clamp(float(prop["pressure"]) / TOO_BIG_FALL_PRESSURE_SECONDS, 0.0, 1.0)
	var tilt_degrees: float = lerp(TOO_BIG_TILT_DEGREES * 0.35, TOO_BIG_TILT_DEGREES, pressure_ratio)
	if bool(prop["fallen"]):
		tilt_degrees = TOO_BIG_FALL_DEGREES

	var base_rotation: Vector3 = prop["base_rotation"]
	prop_node.rotation = base_rotation + Vector3(
		deg_to_rad(direction.y * tilt_degrees),
		0.0,
		deg_to_rad(-direction.x * tilt_degrees)
	)


func _recover_too_big_prop(prop: Dictionary, delta: float) -> void:
	prop["pressure"] = max(0.0, float(prop["pressure"]) - delta * PROP_RECOVER_RATE)

	var prop_node := prop["node"] as Node3D
	if not is_instance_valid(prop_node):
		return

	var base_rotation: Vector3 = prop["base_rotation"]
	var recovery_weight: float = clamp(delta * PROP_RECOVER_RATE, 0.0, 1.0)
	prop_node.rotation = prop_node.rotation.lerp(base_rotation, recovery_weight)
	if float(prop["pressure"]) <= 0.01:
		prop["fallen"] = false
		prop_node.rotation = base_rotation


func _update_prop_markers() -> void:
	var player_flat := Vector2(player_root.position.x, player_root.position.z)
	var fast_bound := hole_radius * CONSUME_RADIUS_FACTOR + PROP_MARKER_NEAR_MARGIN + 2.5
	var fast_bound_sq := fast_bound * fast_bound

	for prop in props:
		var marker := prop["marker"] as MeshInstance3D
		if not is_instance_valid(marker):
			continue

		if bool(prop["consumed"]) or match_phase != MatchPhase.PLAYING or not player_alive:
			marker.hide()
			continue

		var prop_position: Vector3 = prop["position"]
		var prop_flat := Vector2(prop_position.x, prop_position.z)
		if player_flat.distance_squared_to(prop_flat) > fast_bound_sq:
			marker.hide()
			continue

		var is_touching_player := _does_prop_footprint_touch_consume_radius(prop, player_flat, hole_radius)
		var is_near_player := _is_prop_near_consume_radius(prop, player_flat, hole_radius)
		if not is_touching_player and not is_near_player:
			marker.hide()
			continue

		marker.show()
		if _can_actor_consume_prop(prop, hole_radius):
			marker.material_override = materials["marker_edible"]
		else:
			marker.material_override = materials["marker_too_big"]


func _is_prop_near_consume_radius(prop: Dictionary, actor_flat: Vector2, actor_radius: float) -> bool:
	var prop_position: Vector3 = prop["position"]
	var prop_flat := Vector2(prop_position.x, prop_position.z)
	var distance_to_footprint: float = _get_distance_to_prop_footprint(prop, actor_flat, prop_flat)
	var consume_radius: float = actor_radius * CONSUME_RADIUS_FACTOR
	return distance_to_footprint <= consume_radius + PROP_MARKER_NEAR_MARGIN


func _check_consumption() -> void:
	for prop in props:
		if bool(prop["consumed"]):
			continue

		var prop_position: Vector3 = prop["position"]
		if not _is_prop_potentially_interactive(Vector2(prop_position.x, prop_position.z), 0.0):
			continue

		var winning_actor := _find_consumption_winner(prop)
		if winning_actor.is_empty():
			continue

		_consume_prop(prop, winning_actor)

		if remaining_count <= 0:
			_end_match("Arena cleared")
			return


func _check_hole_consumption() -> void:
	if match_phase != MatchPhase.PLAYING:
		return

	var actors := _get_consumption_actors()
	for predator in actors:
		if not _is_actor_alive(predator):
			continue

		var predator_radius := _get_actor_radius(predator)
		var predator_position := _get_actor_position(predator)
		var predator_flat := Vector2(predator_position.x, predator_position.z)

		for prey in actors:
			if int(predator["id"]) == int(prey["id"]) or not _is_actor_alive(prey):
				continue

			var prey_radius := _get_actor_radius(prey)
			if predator_radius < prey_radius * HOLE_EAT_RADIUS_MARGIN:
				continue

			var prey_position := _get_actor_position(prey)
			var distance := predator_flat.distance_to(Vector2(prey_position.x, prey_position.z))
			if distance > predator_radius * CONSUME_RADIUS_FACTOR:
				continue

			_consume_hole(predator, prey)
			break


func _consume_hole(predator: Dictionary, prey: Dictionary) -> void:
	var prey_position := _get_actor_position(prey)
	var prey_area := _get_actor_area(prey)
	var score_value := HOLE_EAT_SCORE_BASE + int(_get_actor_score(prey) * 0.25)
	if bool(predator["is_player"]):
		player_holes_eaten += 1
	if bool(prey["is_player"]):
		player_times_eaten += 1
	_apply_actor_growth(predator, prey_area * HOLE_EAT_AREA_FACTOR, score_value)
	_play_growth_feedback(predator, score_value)
	_play_hole_eaten_feedback(prey_position)
	_add_event_feed_message("%s ate %s  +%d" % [_get_actor_name(predator), _get_actor_name(prey), score_value])
	_knockout_actor(prey)


func _play_hole_eaten_feedback(world_position: Vector3) -> void:
	if not effects_root:
		return

	var burst := MeshInstance3D.new()
	burst.name = "HoleEatenBurst"
	var burst_mesh := SphereMesh.new()
	burst_mesh.radius = 0.45
	burst_mesh.height = 0.9
	burst.mesh = burst_mesh
	burst.position = Vector3(world_position.x, 0.16, world_position.z)
	burst.material_override = _make_transparent_material(Color(1.0, 0.92, 0.32, 0.42))
	effects_root.add_child(burst)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector3(2.4, 0.18, 2.4), GROWTH_PULSE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free()
	)


func _knockout_actor(actor: Dictionary) -> void:
	if bool(actor["is_player"]):
		player_alive = false
		player_respawn_remaining = RESPAWN_SECONDS
		velocity = Vector3.ZERO
		player_root.hide()
		return

	actor["alive"] = false
	actor["respawn_remaining"] = RESPAWN_SECONDS
	actor["velocity"] = Vector3.ZERO
	actor["target_id"] = -1
	var actor_root := actor["root"] as Node3D
	actor_root.hide()


func _find_consumption_winner(prop: Dictionary) -> Dictionary:
	var prop_position: Vector3 = prop["position"]
	var prop_flat := Vector2(prop_position.x, prop_position.z)
	var winning_actor := {}
	var winning_distance := INF

	for actor in consumption_actors_cache:
		var actor_radius := _get_actor_radius(actor)
		if not _can_actor_consume_prop(prop, actor_radius):
			continue

		var actor_position := _get_actor_position(actor)
		var actor_flat := Vector2(actor_position.x, actor_position.z)
		var distance := actor_flat.distance_to(prop_flat)
		if not _does_prop_footprint_touch_consume_radius(prop, actor_flat, actor_radius):
			continue

		if _is_better_consumption_candidate(actor, actor_radius, distance, winning_actor, winning_distance):
			winning_actor = actor
			winning_distance = distance

	return winning_actor


func _does_prop_footprint_touch_consume_radius(prop: Dictionary, actor_flat: Vector2, actor_radius: float) -> bool:
	var prop_position: Vector3 = prop["position"]
	var prop_flat := Vector2(prop_position.x, prop_position.z)
	var distance_to_footprint: float = _get_distance_to_prop_footprint(prop, actor_flat, prop_flat)
	var consume_radius: float = actor_radius * CONSUME_RADIUS_FACTOR
	return distance_to_footprint <= consume_radius


func _can_actor_consume_prop(prop: Dictionary, actor_radius: float) -> bool:
	return actor_radius >= _get_prop_fit_radius(prop)


func _get_prop_fit_radius(prop: Dictionary) -> float:
	if String(prop["shape"]) == "box":
		var footprint: Vector2 = prop["footprint"]
		return footprint.length()
	if String(prop["shape"]) == "tree":
		return float(prop["collision_radius"])

	return float(prop["required_radius"])


func _get_tier_fit_radius(tier: Dictionary) -> float:
	return MathUtil.tier_fit_radius(
		String(tier["shape"]),
		tier["scale"],
		float(tier["required_radius"]),
		float(tier["collision_radius"])
	)


func _get_distance_to_prop_footprint(prop: Dictionary, actor_flat: Vector2, prop_flat: Vector2) -> float:
	if String(prop["shape"]) == "box":
		var footprint: Vector2 = prop["footprint"]
		return _distance_to_rotated_rect(actor_flat, prop_flat, footprint, float(prop["rotation_y"]))

	return max(0.0, actor_flat.distance_to(prop_flat) - float(prop["collision_radius"]))


func _distance_to_rotated_rect(point: Vector2, rect_center: Vector2, half_extents: Vector2, rotation_y: float) -> float:
	return MathUtil.distance_to_rotated_rect(point, rect_center, half_extents, rotation_y)


func _get_consumption_actors() -> Array:
	var actors := []
	if player_alive:
		actors.append({
			"id": 0,
			"name": player_name,
			"root": player_root,
			"is_player": true,
		})

	for bot in bots:
		if bool(bot["enabled"]) and bool(bot["alive"]):
			actors.append(bot)

	return actors


func _refresh_interaction_cache() -> void:
	consumption_actors_cache = _get_consumption_actors()
	consumption_actor_positions_cache.resize(consumption_actors_cache.size())
	max_actor_radius_cache = INITIAL_RADIUS
	for i in range(consumption_actors_cache.size()):
		var actor: Dictionary = consumption_actors_cache[i]
		var actor_position := _get_actor_position(actor)
		consumption_actor_positions_cache[i] = Vector2(actor_position.x, actor_position.z)
		var actor_radius := _get_actor_radius(actor)
		if actor_radius > max_actor_radius_cache:
			max_actor_radius_cache = actor_radius


# Cheap broad-phase: skip props whose centre is clearly out of reach of every
# actor. PROP_MAX_HALF_EXTENT (2.5) is a generous bound on prop footprints so
# the cull never rejects something that could actually interact.
func _is_prop_potentially_interactive(prop_flat: Vector2, extra_margin: float) -> bool:
	if consumption_actor_positions_cache.is_empty():
		return false
	var reach := max_actor_radius_cache * CONSUME_RADIUS_FACTOR + 2.5 + extra_margin
	var reach_sq := reach * reach
	for actor_flat in consumption_actor_positions_cache:
		if prop_flat.distance_squared_to(actor_flat) <= reach_sq:
			return true
	return false


func _is_better_consumption_candidate(
	actor: Dictionary,
	actor_radius: float,
	distance: float,
	winning_actor: Dictionary,
	winning_distance: float
) -> bool:
	if winning_actor.is_empty():
		return true
	if distance < winning_distance - 0.001:
		return true
	if abs(distance - winning_distance) > 0.001:
		return false

	var winning_radius := _get_actor_radius(winning_actor)
	if actor_radius > winning_radius + 0.001:
		return true
	if abs(actor_radius - winning_radius) > 0.001:
		return false

	return int(actor["id"]) < int(winning_actor["id"])


func _consume_prop(prop: Dictionary, actor: Dictionary) -> void:
	prop["consumed"] = true
	remaining_count -= 1
	_apply_actor_growth(actor, float(prop["area"]), int(prop["score"]))
	_play_consume_effect(prop, _get_actor_position(actor))
	_play_growth_feedback(actor, int(prop["score"]))
	if bool(actor["is_player"]):
		_record_player_prop_eaten(prop)
	if bool(actor["is_player"]) or int(prop["score"]) >= 75:
		_add_event_feed_message("%s ate %s  +%d" % [_get_actor_name(actor), String(prop["object_type"]), int(prop["score"])])


func _record_player_prop_eaten(prop: Dictionary) -> void:
	player_props_eaten += 1
	var prop_area := float(prop["area"])
	if prop_area > player_biggest_prop_area:
		player_biggest_prop_area = prop_area
		player_biggest_prop_name = String(prop["object_type"])


func _apply_actor_growth(actor: Dictionary, area_value: float, score_value: int) -> void:
	if bool(actor["is_player"]):
		var previous_radius := hole_radius
		score += score_value
		hole_area = min(hole_area + area_value, MAX_AREA)
		hole_radius = sqrt(hole_area / PI)
		_update_hole_visual()
		_announce_new_player_unlocks(previous_radius, hole_radius)
		return

	actor["score"] = int(actor["score"]) + score_value
	actor["area"] = min(float(actor["area"]) + area_value, MAX_AREA)
	actor["radius"] = sqrt(float(actor["area"]) / PI)
	_update_bot_visual(actor)


func _announce_new_player_unlocks(previous_radius: float, current_radius: float) -> void:
	var unlocked_names := []
	for tier in prop_tiers:
		var tier_name := String(tier["name"])
		var required_radius := _get_tier_fit_radius(tier)
		if player_unlocked_prop_names.has(tier_name):
			continue
		if previous_radius < required_radius and current_radius >= required_radius:
			player_unlocked_prop_names[tier_name] = true
			unlocked_names.append(tier_name)

	if unlocked_names.is_empty():
		return

	var unlock_text := "Now eating %s" % ", ".join(unlocked_names)
	_play_unlock_popup(unlock_text)
	_add_event_feed_message(unlock_text)


func _get_bot_difficulty_name() -> String:
	match selected_bot_difficulty:
		BOT_DIFFICULTY_CASUAL:
			return "Casual"
		BOT_DIFFICULTY_HARD:
			return "Hard"
		_:
			return "Normal"


func _get_bot_speed_scale() -> float:
	match selected_bot_difficulty:
		BOT_DIFFICULTY_CASUAL:
			return 0.78
		BOT_DIFFICULTY_HARD:
			return 1.16
		_:
			return 1.0


func _get_bot_hunt_scale() -> float:
	match selected_bot_difficulty:
		BOT_DIFFICULTY_CASUAL:
			return 0.55
		BOT_DIFFICULTY_HARD:
			return 1.35
		_:
			return 1.0


func _get_bot_avoid_scale() -> float:
	match selected_bot_difficulty:
		BOT_DIFFICULTY_CASUAL:
			return 0.75
		BOT_DIFFICULTY_HARD:
			return 1.20
		_:
			return 1.0


func _get_bot_detection_scale() -> float:
	match selected_bot_difficulty:
		BOT_DIFFICULTY_CASUAL:
			return 0.78
		BOT_DIFFICULTY_HARD:
			return 1.22
		_:
			return 1.0


func _get_bot_score_seek_scale() -> float:
	match selected_bot_difficulty:
		BOT_DIFFICULTY_CASUAL:
			return 0.008
		BOT_DIFFICULTY_HARD:
			return 0.024
		_:
			return 0.015


func _get_actor_radius(actor: Dictionary) -> float:
	if bool(actor["is_player"]):
		return hole_radius
	return float(actor["radius"])


func _get_actor_area(actor: Dictionary) -> float:
	if bool(actor["is_player"]):
		return hole_area
	return float(actor["area"])


func _get_actor_score(actor: Dictionary) -> int:
	if bool(actor["is_player"]):
		return score
	return int(actor["score"])


func _get_actor_name(actor: Dictionary) -> String:
	if bool(actor["is_player"]):
		return player_name
	return String(actor["name"])


func _is_actor_alive(actor: Dictionary) -> bool:
	if bool(actor["is_player"]):
		return player_alive
	return bool(actor["alive"])


func _get_actor_position(actor: Dictionary) -> Vector3:
	var actor_root := actor["root"] as Node3D
	return actor_root.position


func _play_consume_effect(prop: Dictionary, target_position: Vector3) -> void:
	var prop_node := prop["node"] as Node3D
	if not is_instance_valid(prop_node):
		return

	target_position.y = 0.0
	var target_rotation := Vector3(0.0, rad_to_deg(float(prop["rotation_y"])) + 300.0, 0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(prop_node, "position", target_position, CONSUME_EFFECT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(prop_node, "scale", Vector3.ZERO, CONSUME_EFFECT_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(prop_node, "rotation_degrees", target_rotation, CONSUME_EFFECT_SECONDS)
	tween.finished.connect(func() -> void:
		if is_instance_valid(prop_node):
			prop_node.hide()
	)


func _play_growth_feedback(actor: Dictionary, score_value: int) -> void:
	var actor_position := _get_actor_position(actor)
	_play_growth_pulse(actor, actor_position)
	_play_score_popup(actor_position, score_value)


func _play_growth_pulse(actor: Dictionary, actor_position: Vector3) -> void:
	if not effects_root:
		return

	var pulse := MeshInstance3D.new()
	pulse.name = "GrowthPulse"
	var pulse_mesh := CylinderMesh.new()
	var actor_radius := _get_actor_radius(actor)
	pulse_mesh.top_radius = actor_radius * CONSUME_RADIUS_FACTOR
	pulse_mesh.bottom_radius = actor_radius * CONSUME_RADIUS_FACTOR
	pulse_mesh.height = 0.022
	pulse_mesh.radial_segments = 72
	pulse.mesh = pulse_mesh
	pulse.position = Vector3(actor_position.x, 0.045, actor_position.z)
	pulse.material_override = _make_transparent_material(_get_actor_feedback_color(actor, 0.30))
	effects_root.add_child(pulse)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector3(1.45, 1.0, 1.45), GROWTH_PULSE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse, "position:y", 0.07, GROWTH_PULSE_SECONDS)
	tween.finished.connect(func() -> void:
		if is_instance_valid(pulse):
			pulse.queue_free()
	)


func _play_score_popup(world_position: Vector3, score_value: int) -> void:
	if not camera or not floating_text_root:
		return

	var popup := Label.new()
	popup.text = "+%d" % score_value
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_color_override("font_color", Color(1.0, 0.96, 0.66))
	popup.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	popup.add_theme_constant_override("shadow_offset_x", 2)
	popup.add_theme_constant_override("shadow_offset_y", 2)
	var screen_position := camera.unproject_position(world_position + Vector3(0.0, 1.2, 0.0))
	popup.position = screen_position - Vector2(22.0, 14.0)
	floating_text_root.add_child(popup)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position", popup.position + Vector2(0.0, -38.0), SCORE_POPUP_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, SCORE_POPUP_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(popup):
			popup.queue_free()
	)


func _play_unlock_popup(text: String) -> void:
	if not floating_text_root:
		return

	var popup := Label.new()
	popup.text = text
	popup.add_theme_font_size_override("font_size", 28)
	popup.add_theme_color_override("font_color", Color(0.72, 1.0, 0.82))
	popup.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	popup.add_theme_constant_override("shadow_offset_x", 2)
	popup.add_theme_constant_override("shadow_offset_y", 2)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.set_anchors_preset(Control.PRESET_TOP_WIDE)
	popup.offset_left = 220.0
	popup.offset_top = 96.0
	popup.offset_right = -220.0
	popup.offset_bottom = 138.0
	floating_text_root.add_child(popup)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position", popup.position + Vector2(0.0, -24.0), UNLOCK_POPUP_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, UNLOCK_POPUP_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(popup):
			popup.queue_free()
	)


func _get_actor_feedback_color(actor: Dictionary, alpha: float) -> Color:
	var color := Color(0.1, 0.68, 0.78, alpha)
	if not bool(actor["is_player"]):
		var bot_index := int(actor["id"]) - 1
		if bot_index >= 0 and bot_index < BOT_COLORS.size():
			color = BOT_COLORS[bot_index]
			color.a = alpha

	return color


func _clear_feedback_effects() -> void:
	if effects_root:
		for child in effects_root.get_children():
			child.queue_free()
	if floating_text_root:
		for child in floating_text_root.get_children():
			child.queue_free()


func _clear_event_feed() -> void:
	event_feed_messages.clear()
	_refresh_event_feed()


func _add_event_feed_message(text: String) -> void:
	if text.is_empty():
		return

	event_feed_messages.push_front(text)
	while event_feed_messages.size() > EVENT_FEED_MAX_LINES:
		event_feed_messages.pop_back()
	_refresh_event_feed()


func _refresh_event_feed() -> void:
	if not event_feed_label:
		return

	if event_feed_messages.is_empty():
		event_feed_label.text = "Event feed"
		return

	var lines := PackedStringArray()
	for message in event_feed_messages:
		lines.append(String(message))
	event_feed_label.text = "Event feed\n%s" % "\n".join(lines)


func _load_profile() -> void:
	var config := ConfigFile.new()
	var error := config.load(PROFILE_SAVE_PATH)
	if error != OK:
		return

	var stored_best: Variant = config.get_value("profile", "best_score", 0)
	if stored_best is int or stored_best is float or stored_best is String:
		best_score = max(0, int(stored_best))


func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "best_score", best_score)
	config.save(PROFILE_SAVE_PATH)


func _end_match(reason: String) -> void:
	match_phase = MatchPhase.ENDED
	velocity = Vector3.ZERO
	var had_new_best := score > best_score
	if had_new_best:
		best_score = score
		_save_profile()
	var rankings := _get_rankings()
	var winner: Dictionary = rankings[0]
	if had_new_best:
		_add_event_feed_message("New best score: %d" % best_score)
	_add_event_feed_message("%s: %s wins" % [reason, String(winner["name"])])
	message_label.text = ""
	if result_label:
		result_label.text = _format_result_text(reason, winner, rankings)
	if result_panel:
		result_panel.show()
	if restart_button:
		restart_button.show()


func _update_hole_visual() -> void:
	var hole_disc := CylinderMesh.new()
	hole_disc.top_radius = hole_radius
	hole_disc.bottom_radius = hole_radius
	hole_disc.height = 0.08
	hole_disc.radial_segments = 72
	hole_mesh.mesh = hole_disc
	hole_mesh.position.y = 0.015

	var consume_disc := CylinderMesh.new()
	consume_disc.top_radius = hole_radius * CONSUME_RADIUS_FACTOR
	consume_disc.bottom_radius = hole_radius * CONSUME_RADIUS_FACTOR
	consume_disc.height = 0.025
	consume_disc.radial_segments = 72
	consume_mesh.mesh = consume_disc


func _update_camera(delta: float) -> void:
	if not camera or not player_root:
		return

	var height: float = clamp(14.0 + hole_radius * 2.25, 14.0, 30.0)
	var back: float = clamp(9.5 + hole_radius * 0.75, 9.5, 16.0)
	var look_ahead := Vector3.ZERO
	var velocity_flat := Vector2(velocity.x, velocity.z)
	if player_alive and velocity_flat.length() > 0.1:
		var ahead_strength: float = clamp(velocity_flat.length() * 0.30, 0.0, 3.5)
		look_ahead = Vector3(velocity.x, 0.0, velocity.z).normalized() * ahead_strength
	var target_position := player_root.position + look_ahead + Vector3(0.0, height, back)
	var weight: float = clamp(delta * 4.5, 0.0, 1.0)
	camera.position = camera.position.lerp(target_position, weight)
	camera.look_at(player_root.position + look_ahead * 0.5, Vector3.UP)


func _update_hud() -> void:
	match match_phase:
		MatchPhase.MENU:
			phase_label.text = "Menu"
			message_label.text = ""
			if menu_best_label:
				menu_best_label.text = "Best score %d" % best_score
			if menu_panel:
				menu_panel.show()
			if pause_panel:
				pause_panel.hide()
			if result_panel:
				result_panel.hide()
		MatchPhase.COUNTDOWN:
			phase_label.text = "Countdown"
			message_label.text = "Ready\n%d" % max(1, ceili(countdown_remaining))
			if menu_panel:
				menu_panel.hide()
			if pause_panel:
				pause_panel.hide()
			if result_panel:
				result_panel.hide()
		MatchPhase.PLAYING:
			phase_label.text = "Playing"
			if player_alive:
				message_label.text = ""
			else:
				message_label.text = "Eaten\nRespawning in %.1f" % player_respawn_remaining
			if menu_panel:
				menu_panel.hide()
			if pause_panel:
				pause_panel.hide()
			if result_panel:
				result_panel.hide()
		MatchPhase.PAUSED:
			phase_label.text = "Paused"
			message_label.text = ""
			if menu_panel:
				menu_panel.hide()
			if pause_panel:
				pause_panel.show()
			if result_panel:
				result_panel.hide()
		MatchPhase.ENDED:
			phase_label.text = "Ended"
			if menu_panel:
				menu_panel.hide()
			if pause_panel:
				pause_panel.hide()

	score_label.text = "Score %d" % score
	size_label.text = "Radius %.2f" % hole_radius
	var seconds_left := int(time_remaining)
	timer_label.text = "Time %02d:%02d" % [floori(seconds_left / 60.0), seconds_left % 60]
	var timer_urgent := match_phase == MatchPhase.PLAYING and time_remaining <= 10.0 and time_remaining > 0.0
	if timer_urgent:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
		timer_label.add_theme_font_size_override("font_size", 22)
	else:
		timer_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
		timer_label.add_theme_font_size_override("font_size", 18)
	remaining_label.text = "Props %d" % remaining_count
	rank_label.text = "Rank %d/%d" % [_get_player_rank(), _get_rankings().size()]
	growth_label.text = _format_growth_progress()
	stats_label.text = "Eaten %d  Best %d" % [player_props_eaten, best_score]
	leaderboard_label.text = _format_leaderboard()
	if minimap:
		minimap.queue_redraw()


func _draw_minimap() -> void:
	if not minimap:
		return

	var rect := Rect2(Vector2.ZERO, Vector2(MINIMAP_SIZE, MINIMAP_SIZE))
	minimap.draw_rect(rect, Color(0.035, 0.045, 0.050, 0.72), true)
	minimap.draw_rect(rect, Color(0.72, 0.86, 0.94, 0.24), false, 1.0)

	_draw_minimap_props()
	_draw_minimap_actors()


func _draw_minimap_props() -> void:
	var player_flat := Vector2(player_root.position.x, player_root.position.z)
	var drawn_count := 0
	for prop in props:
		if drawn_count >= MINIMAP_PROP_LIMIT:
			return
		if bool(prop["consumed"]):
			continue

		var prop_position: Vector3 = prop["position"]
		var prop_flat := Vector2(prop_position.x, prop_position.z)
		if player_flat.distance_to(prop_flat) > 12.0:
			continue

		var marker_color := Color(1.0, 0.72, 0.18, 0.68)
		if _can_actor_consume_prop(prop, hole_radius):
			marker_color = Color(0.24, 0.92, 0.46, 0.72)

		minimap.draw_circle(_world_to_minimap(prop_position), 2.0, marker_color)
		drawn_count += 1


func _draw_minimap_actors() -> void:
	if player_alive:
		minimap.draw_circle(_world_to_minimap(player_root.position), 5.0, Color(0.1, 0.68, 0.78, 0.95))

	for bot in bots:
		if not bool(bot["enabled"]):
			continue
		if not bool(bot["alive"]):
			continue

		var bot_root := bot["root"] as Node3D
		var bot_index := int(bot["id"]) - 1
		var bot_color := Color(0.95, 0.70, 0.14, 0.95)
		if bot_index >= 0 and bot_index < BOT_COLORS.size():
			bot_color = BOT_COLORS[bot_index]
			bot_color.a = 0.95
		minimap.draw_circle(_world_to_minimap(bot_root.position), 4.0, bot_color)


func _world_to_minimap(world_position: Vector3) -> Vector2:
	var x: float = inverse_lerp(-ARENA_HALF_SIZE, ARENA_HALF_SIZE, world_position.x) * MINIMAP_SIZE
	var y: float = inverse_lerp(-ARENA_HALF_SIZE, ARENA_HALF_SIZE, world_position.z) * MINIMAP_SIZE
	return Vector2(x, y)


func _format_growth_progress() -> String:
	var next_tier := _get_next_locked_tier()
	if next_tier.is_empty():
		return "All props unlocked"

	var required_radius := _get_tier_fit_radius(next_tier)
	var current_area := PI * hole_radius * hole_radius
	var required_area := PI * required_radius * required_radius
	var progress: float = clamp(current_area / required_area, 0.0, 1.0)
	return "Next: %s (%d%%)" % [String(next_tier["name"]), int(progress * 100.0)]


func _get_next_locked_tier() -> Dictionary:
	var best_tier := {}
	var best_required_radius := INF

	for tier in prop_tiers:
		var required_radius := _get_tier_fit_radius(tier)
		if required_radius <= hole_radius:
			continue
		if required_radius < best_required_radius:
			best_required_radius = required_radius
			best_tier = tier

	return best_tier


func _format_result_text(reason: String, winner: Dictionary, rankings: Array) -> String:
	var result_text := "%s\nWinner: %s  Score %d\n" % [reason, winner["name"], int(winner["score"])]
	for index in range(rankings.size()):
		var row: Dictionary = rankings[index]
		var marker := "*" if bool(row["is_player"]) else " "
		result_text += "\n%s%d. %s  score %d  radius %.2f" % [
			marker,
			index + 1,
			String(row["name"]),
			int(row["score"]),
			float(row["radius"]),
		]

	result_text += "\n\nYour stats"
	result_text += "\nProps eaten %d  Holes eaten %d  Eaten by rivals %d" % [
		player_props_eaten,
		player_holes_eaten,
		player_times_eaten,
	]
	result_text += "\nBiggest prop %s  Best score %d" % [player_biggest_prop_name, best_score]
	result_text += "\n\nSpace, Enter, or Restart"
	return result_text


func _format_leaderboard() -> String:
	var rankings := _get_rankings()
	var text := "Leaderboard"
	for index in range(rankings.size()):
		var row: Dictionary = rankings[index]
		var marker := "*" if bool(row["is_player"]) else " "
		text += "\n%s%d. %-6s %4d  r%.1f" % [
			marker,
			index + 1,
			String(row["name"]),
			int(row["score"]),
			float(row["radius"]),
		]

	return text


func _get_player_rank() -> int:
	var rankings := _get_rankings()
	for index in range(rankings.size()):
		var row: Dictionary = rankings[index]
		if bool(row["is_player"]):
			return index + 1

	return rankings.size()


func _get_rankings() -> Array:
	var rankings := [{
		"name": player_name,
		"score": score,
		"radius": hole_radius,
		"is_player": true,
	}]

	for bot in bots:
		if not bool(bot["enabled"]):
			continue
		rankings.append({
			"name": bot["name"],
			"score": int(bot["score"]),
			"radius": float(bot["radius"]),
			"is_player": false,
		})

	rankings.sort_custom(_compare_ranking_rows)
	return rankings


func _compare_ranking_rows(a: Dictionary, b: Dictionary) -> bool:
	if int(a["score"]) != int(b["score"]):
		return int(a["score"]) > int(b["score"])

	return float(a["radius"]) > float(b["radius"])


func _build_touch_joystick(hud: CanvasLayer) -> void:
	var joystick_root := Control.new()
	joystick_root.name = "MoveJoystick"
	joystick_root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_root.offset_left = 24.0
	joystick_root.offset_top = -JOYSTICK_SIZE - 24.0
	joystick_root.offset_right = 24.0 + JOYSTICK_SIZE
	joystick_root.offset_bottom = -24.0
	joystick_root.mouse_filter = Control.MOUSE_FILTER_STOP
	joystick_root.gui_input.connect(_on_joystick_gui_input)
	hud.add_child(joystick_root)

	joystick_base = Panel.new()
	joystick_base.size = Vector2(JOYSTICK_SIZE, JOYSTICK_SIZE)
	joystick_base.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.045, 0.050, 0.34), JOYSTICK_SIZE * 0.5))
	joystick_root.add_child(joystick_base)

	joystick_knob = Panel.new()
	joystick_knob.size = Vector2(JOYSTICK_KNOB_SIZE, JOYSTICK_KNOB_SIZE)
	joystick_knob.add_theme_stylebox_override("panel", _panel_style(Color(0.94, 0.97, 1.0, 0.58), JOYSTICK_KNOB_SIZE * 0.5))
	joystick_root.add_child(joystick_knob)
	_reset_joystick()


func _on_joystick_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and joystick_pointer_id == -1:
			joystick_dragging = true
			joystick_pointer_id = event.index
			_update_joystick(event.position)
		elif not event.pressed and event.index == joystick_pointer_id:
			_reset_joystick()
	elif event is InputEventScreenDrag:
		if joystick_pointer_id == -1:
			joystick_dragging = true
			joystick_pointer_id = event.index
		if event.index == joystick_pointer_id:
			_update_joystick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			joystick_dragging = true
			joystick_pointer_id = -2
			_update_joystick(event.position)
		elif joystick_pointer_id == -2:
			_reset_joystick()
	elif event is InputEventMouseMotion and joystick_dragging and joystick_pointer_id == -2:
		_update_joystick(event.position)


func _update_joystick(local_position: Vector2) -> void:
	var center := Vector2(JOYSTICK_SIZE * 0.5, JOYSTICK_SIZE * 0.5)
	var max_distance := (JOYSTICK_SIZE - JOYSTICK_KNOB_SIZE) * 0.5
	var offset := (local_position - center).limit_length(max_distance)
	joystick_input_vector = offset / max_distance
	joystick_knob.position = center + offset - Vector2(JOYSTICK_KNOB_SIZE * 0.5, JOYSTICK_KNOB_SIZE * 0.5)


func _reset_joystick() -> void:
	joystick_input_vector = Vector2.ZERO
	joystick_dragging = false
	joystick_pointer_id = -1
	if joystick_knob:
		joystick_knob.position = Vector2(
			(JOYSTICK_SIZE - JOYSTICK_KNOB_SIZE) * 0.5,
			(JOYSTICK_SIZE - JOYSTICK_KNOB_SIZE) * 0.5
		)


func _hud_label(size := 18) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	return label


func _menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _panel_style(color: Color, corner_radius := 6.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(corner_radius))
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func _make_transparent_material(color: Color) -> StandardMaterial3D:
	var material := _make_material(color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
