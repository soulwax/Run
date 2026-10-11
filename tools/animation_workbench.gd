extends Node3D

## Runtime preview stage for checking the portable clips on the actual game rig.
## Use Blender for authoring, then retarget/export and audition the result here.

const RIG_PROFILE := preload("res://scripts/player/animation_rig_profile.gd")
const MODEL_SCENE := preload("res://assets/characters/styloo_elf/elf.glb")
const BASE_LIBRARY := preload("res://assets/characters/styloo_elf/elf_animations.res")
const FEMININE_LIBRARY := preload("res://assets/characters/styloo_elf/feminine/elf_feminine.res")

var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _clip_picker: OptionButton
var _timeline: HSlider
var _timeline_readout: Label
var _speed: HSlider
var _loop: CheckBox
var _play_button: Button
var _report: Label
var _current_clip := ""
var _was_playing_before_scrub := false
var _orbiting := false
var _yaw := 0.0
var _pitch := -0.08
var _distance := 3.7


func _ready() -> void:
	_build_stage()
	_build_interface()
	_refresh_report()
	_rebuild_clip_list()
	if _clip_picker.item_count > 0:
		_select_clip(0)


func _process(_delta: float) -> void:
	if _player and _player.is_playing():
		_timeline.set_value_no_signal(_player.current_animation_position)
		_update_timeline_readout()
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			_orbiting = button.pressed
			get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(2.0, _distance - 0.25)
			get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(6.5, _distance + 0.25)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _orbiting:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * 0.006
		_pitch = clampf(_pitch - motion.relative.y * 0.004, -0.7, 0.45)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _build_stage() -> void:
	var model := MODEL_SCENE.instantiate() as Node3D
	model.name = "AnimationSubject"
	model.scale = Vector3.ONE * RIG_PROFILE.MODEL_SCALE
	model.rotation.y = PI
	add_child(model)
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		push_error("Animation workbench: elf scene has no Skeleton3D")
		return
	var rig_root := _skeleton.get_parent()
	_player = AnimationPlayer.new()
	_player.name = "PreviewPlayer"
	rig_root.add_child(_player)
	_player.root_node = NodePath("..")
	_player.add_animation_library("", (BASE_LIBRARY.duplicate(true) as AnimationLibrary))
	_player.add_animation_library("Feminine", (FEMININE_LIBRARY.duplicate(true) as AnimationLibrary))
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	floor.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("171b20")
	floor_material.roughness = 0.92
	floor.material_override = floor_material
	floor.position.y = -0.025
	add_child(floor)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -24.0, 0.0)
	key.light_color = Color("e5ddcf")
	key.light_energy = 1.25
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.2, 1.9, 1.4)
	fill.light_color = Color("8ca7c2")
	fill.light_energy = 0.7
	fill.omni_range = 7.0
	add_child(fill)
	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.current = true
	add_child(camera)
	_update_camera()
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("090b0e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9aa5b1")
	environment.ambient_light_energy = 0.42
	environment_node.environment = environment
	add_child(environment_node)


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(24.0, 24.0)
	panel.size = Vector2(410.0, 560.0)
	panel.custom_minimum_size = Vector2(410.0, 560.0)
	panel.add_theme_stylebox_override("panel", UiChrome.plate(28, 12))
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := UiChrome.term_label("MOTION WORKBENCH", 22, UiChrome.BONE, true)
	column.add_child(title)
	var subtitle := UiChrome.term_label("HUMANOID PROFILE  //  %s" % RIG_PROFILE.PROFILE_ID, 11, Color(UiChrome.SIGNAL))
	column.add_child(subtitle)
	column.add_child(_rule())
	column.add_child(UiChrome.term_label("CLIP LIBRARY", 11, UiChrome.ASH))
	_clip_picker = OptionButton.new()
	_clip_picker.theme = UiChrome.term_theme()
	_clip_picker.custom_minimum_size.y = 42.0
	_clip_picker.item_selected.connect(_select_clip)
	column.add_child(_clip_picker)
	var transport := HBoxContainer.new()
	transport.add_theme_constant_override("separation", 8)
	_play_button = _button("PAUSE")
	_play_button.pressed.connect(_toggle_play)
	transport.add_child(_play_button)
	var stop_button := _button("STOP / RESET")
	stop_button.pressed.connect(_stop)
	transport.add_child(stop_button)
	_loop = CheckBox.new()
	_loop.text = "LOOP"
	_loop.button_pressed = true
	_loop.toggled.connect(_set_loop)
	transport.add_child(_loop)
	column.add_child(transport)
	var timeline_row := HBoxContainer.new()
	_timeline_readout = UiChrome.term_label("0.00 / 0.00 s", 11, UiChrome.BONE)
	_timeline_readout.custom_minimum_size.x = 104.0
	timeline_row.add_child(_timeline_readout)
	_timeline = HSlider.new()
	_timeline.min_value = 0.0
	_timeline.max_value = 1.0
	_timeline.step = 0.001
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.drag_started.connect(_scrub_started)
	_timeline.value_changed.connect(_scrub_changed)
	_timeline.drag_ended.connect(_scrub_ended)
	timeline_row.add_child(_timeline)
	column.add_child(timeline_row)
	var speed_row := HBoxContainer.new()
	speed_row.add_child(UiChrome.term_label("PLAYBACK RATE", 11, UiChrome.ASH))
	_speed = HSlider.new()
	_speed.min_value = 0.25
	_speed.max_value = 2.0
	_speed.step = 0.05
	_speed.value = 1.0
	_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed.value_changed.connect(_set_speed)
	speed_row.add_child(_speed)
	var speed_label := UiChrome.term_label("1.00×", 11, UiChrome.BONE)
	speed_label.custom_minimum_size.x = 44.0
	_speed.value_changed.connect(func(value: float) -> void: speed_label.text = "%.2f×" % value)
	speed_row.add_child(speed_label)
	column.add_child(speed_row)
	column.add_child(_rule())
	column.add_child(UiChrome.term_label("RIG / TRACK VALIDATION", 11, UiChrome.ASH))
	_report = UiChrome.term_label("", 12, UiChrome.BONE)
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report.custom_minimum_size.y = 108.0
	column.add_child(_report)
	var help := UiChrome.term_label("MIDDLE DRAG  /  ORBIT     WHEEL  /  ZOOM\nESC  /  CLOSE WORKBENCH", 10, Color(UiChrome.ASH))
	column.add_child(help)


func _rebuild_clip_list() -> void:
	_clip_picker.clear()
	_add_library_items("", BASE_LIBRARY)
	_add_library_items("Feminine", FEMININE_LIBRARY)


func _add_library_items(library_name: String, library: AnimationLibrary) -> void:
	for clip_value: String in library.get_animation_list():
		var full_name: String = clip_value if library_name.is_empty() else "%s/%s" % [library_name, clip_value]
		var animation: Animation = _player.get_animation(full_name)
		var duration: float = animation.length if animation else 0.0
		_clip_picker.add_item("%s   ·   %.2fs" % [full_name.to_upper(), duration])
		_clip_picker.set_item_metadata(_clip_picker.item_count - 1, full_name)


func _select_clip(index: int) -> void:
	if _player == null or index < 0 or index >= _clip_picker.item_count:
		return
	_current_clip = str(_clip_picker.get_item_metadata(index))
	var animation := _player.get_animation(_current_clip)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_LINEAR if _loop.button_pressed else Animation.LOOP_NONE
	_timeline.max_value = maxf(animation.length, 0.001)
	_timeline.value = 0.0
	_player.speed_scale = _speed.value
	_player.play(_current_clip)
	_player.seek(0.0, true)
	_play_button.text = "PAUSE"
	_update_timeline_readout()
	_refresh_report()


func _toggle_play() -> void:
	if _player.is_playing():
		_player.pause()
		_play_button.text = "PLAY"
	else:
		_player.play(_current_clip)
		_play_button.text = "PAUSE"


func _stop() -> void:
	_player.stop()
	_player.seek(0.0, true)
	_timeline.set_value_no_signal(0.0)
	_play_button.text = "PLAY"
	_update_timeline_readout()


func _set_loop(enabled: bool) -> void:
	if _player and _current_clip != "":
		_player.get_animation(_current_clip).loop_mode = Animation.LOOP_LINEAR if enabled else Animation.LOOP_NONE


func _set_speed(value: float) -> void:
	if _player:
		_player.speed_scale = value


func _scrub_started() -> void:
	_was_playing_before_scrub = _player.is_playing()
	_player.pause()


func _scrub_changed(value: float) -> void:
	if _player and _current_clip != "":
		_player.seek(value, true)
		_update_timeline_readout()


func _scrub_ended(_changed: bool) -> void:
	if _was_playing_before_scrub:
		_player.play(_current_clip)
	_play_button.text = "PAUSE" if _player.is_playing() else "PLAY"


func _update_timeline_readout() -> void:
	if _player == null or _current_clip == "":
		return
	var animation := _player.get_animation(_current_clip)
	_timeline_readout.text = "%.2f / %.2f s" % [_timeline.value, animation.length]


func _refresh_report() -> void:
	if _skeleton == null or _report == null:
		return
	var missing: Array[String] = []
	for bone_name in RIG_PROFILE.TARGET_BONES:
		if _skeleton.find_bone(bone_name) < 0:
			missing.append(bone_name)
	var bad_tracks: Array[String] = []
	var animation := _player.get_animation(_current_clip) if _player and _current_clip != "" else null
	if animation:
		for track in animation.get_track_count():
			var type := animation.track_get_type(track)
			if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				continue
			var path_text := str(animation.track_get_path(track))
			var split := path_text.split(":", false)
			if split.size() < 2:
				continue
			var bone_name: String = split[-1]
			if _skeleton.find_bone(bone_name) < 0 and not bad_tracks.has(bone_name):
				bad_tracks.append(bone_name)
	var state := "READY"
	if not missing.is_empty() or not bad_tracks.is_empty():
		state = "CHECK REQUIRED"
	var lines := [
		"PROFILE  %s" % RIG_PROFILE.PROFILE_ID,
		"DEFORM CHANNELS  %d / %d" % [RIG_PROFILE.TARGET_BONES.size(), _skeleton.get_bone_count()],
		"CLIP  %s" % state,
	]
	if not missing.is_empty():
		lines.append("Missing rig bones: %s" % ", ".join(missing))
	if not bad_tracks.is_empty():
		lines.append("Unknown clip bones: %s" % ", ".join(bad_tracks))
	_report.text = "\n".join(lines)


func _update_camera() -> void:
	var camera := get_node_or_null("PreviewCamera") as Camera3D
	if camera == null:
		return
	var target := Vector3(0.0, 1.0, 0.0)
	var direction := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	camera.global_position = target + direction * _distance
	camera.look_at(target, Vector3.UP)


func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(UiChrome.SIGNAL, 0.52)
	line.custom_minimum_size.y = 1.0
	return line


func _button(caption: String) -> Button:
	var button := Button.new()
	button.theme = UiChrome.term_theme()
	button.text = caption
	button.custom_minimum_size = Vector2(112.0, 38.0)
	return button
