extends CanvasLayer

## A quiet CRT pass shared by every screen. Japanese corner marks belong to
## the instrument display, while the center of the image stays unobstructed.
const CRT_SHADER := preload("res://shaders/signal_glass.gdshader")

var _glass: ColorRect
var _material: ShaderMaterial
var _status: Label
var _japanese: Label
var _compute: Label
var _record: Label
var _indicator: ColorRect
var _next_flicker := 6.0
var _flicker_left := 0.0
var _last_phase := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	_build_glass()
	_build_marks()
	if Game.settings:
		Game.settings.changed.connect(_sync_strength)
	_sync_strength()
	_refresh_status()


func _process(delta: float) -> void:
	if Game.phase != _last_phase:
		_refresh_status()
		_sync_strength()
	_flicker_left = maxf(_flicker_left - delta, 0.0)
	_next_flicker -= delta
	if _next_flicker <= 0.0:
		_next_flicker = randf_range(5.0, 11.0)
		_flicker_left = randf_range(0.025, 0.055)
	if _material and _glass.visible:
		_material.set_shader_parameter("burst", 0.22 if _flicker_left > 0.0 else 0.0)
	if _indicator:
		_indicator.color = Color(UiChrome.SIGNAL, 0.48 if _flicker_left > 0.0 else 0.82 + sin(Time.get_ticks_msec() * 0.0015) * 0.12)


func _build_glass() -> void:
	_glass = ColorRect.new()
	_glass.name = "SignalGlassCRT"
	_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = CRT_SHADER
	_glass.material = _material
	add_child(_glass)


func _build_marks() -> void:
	var mono := UiChrome.mono_font()
	var japanese := SystemFont.new()
	japanese.font_names = PackedStringArray(["Yu Gothic UI", "Yu Gothic", "Meiryo", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
	_status = UiChrome.term_label("OD-7  //  SYSTEM FEED", 13, Color(UiChrome.BONE, 0.78))
	_status.add_theme_font_override("font", mono)
	_status.add_theme_color_override("font_outline_color", Color(0.015, 0.01, 0.012, 0.82))
	_status.add_theme_constant_override("outline_size", 3)
	_status.position = Vector2(26.0, 22.0)
	add_child(_status)
	_japanese = UiChrome.term_label("観測記録  ·  夢", 14, Color(UiChrome.BONE, 0.78))
	_japanese.add_theme_font_override("font", japanese)
	_japanese.add_theme_color_override("font_outline_color", Color(0.015, 0.01, 0.012, 0.82))
	_japanese.add_theme_constant_override("outline_size", 3)
	_japanese.anchor_left = 1.0
	_japanese.anchor_right = 1.0
	_japanese.offset_left = -184.0
	_japanese.offset_right = -26.0
	_japanese.offset_top = 20.0
	_japanese.offset_bottom = 42.0
	_japanese.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_japanese)
	_compute = UiChrome.term_label("演算  //  CORE 07   ·   04.18", 11, Color(UiChrome.BONE, 0.58))
	_compute.anchor_top = 1.0
	_compute.anchor_bottom = 1.0
	_compute.offset_left = 26.0
	_compute.offset_right = 310.0
	_compute.offset_top = -42.0
	_compute.offset_bottom = -20.0
	add_child(_compute)
	_record = UiChrome.term_label("記録中  /  夢の記録", 11, Color(UiChrome.BONE, 0.58))
	_record.anchor_left = 1.0
	_record.anchor_top = 1.0
	_record.anchor_right = 1.0
	_record.anchor_bottom = 1.0
	_record.offset_left = -260.0
	_record.offset_right = -26.0
	_record.offset_top = -42.0
	_record.offset_bottom = -20.0
	_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_record)
	_indicator = ColorRect.new()
	_indicator.color = Color(UiChrome.SIGNAL, 0.82)
	_indicator.position = Vector2(12.0, 25.0)
	indicator_size()
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_indicator)
	_build_registration_marks()


func _build_registration_marks() -> void:
	# Fine corner ticks make the glass read like a recorder display. They sit
	# inside the safe margin and stay clear of dialogue and paper content.
	for corner in 4:
		var mark := Control.new()
		mark.name = "RegistrationMark%d" % corner
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(mark)
		var horizontal := ColorRect.new()
		horizontal.color = Color(UiChrome.SIGNAL, 0.27)
		horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vertical := ColorRect.new()
		vertical.color = Color(UiChrome.SIGNAL, 0.27)
		vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var left := corner % 2 == 0
		var top := corner < 2
		horizontal.position = Vector2(26.0 if left else -54.0, 58.0 if top else -58.0)
		horizontal.size = Vector2(28.0, 1.0)
		vertical.position = Vector2(26.0 if left else -27.0, 58.0 if top else -86.0)
		vertical.size = Vector2(1.0, 28.0)
		if not left:
			horizontal.anchor_left = 1.0
			horizontal.anchor_right = 1.0
			vertical.anchor_left = 1.0
			vertical.anchor_right = 1.0
		if not top:
			horizontal.anchor_top = 1.0
			horizontal.anchor_bottom = 1.0
			vertical.anchor_top = 1.0
			vertical.anchor_bottom = 1.0
		mark.add_child(horizontal)
		mark.add_child(vertical)


func indicator_size() -> void:
	_indicator.size = Vector2(4.0, 8.0)


func _sync_strength() -> void:
	if not _material:
		return
	var effects := float(Game.settings.screen_effects) if Game.settings else 1.0
	var active := effects > 0.01 and Game.phase != Game.Phase.BOOT
	_material.set_shader_parameter("strength", clampf(effects, 0.0, 1.0) * 0.14)
	# The title and title settings have their own CRT shader. Skip this second
	# full-screen pass there; the status marks remain part of the menu frame.
	_glass.visible = active
	if _status:
		_status.visible = effects > 0.01
	if _japanese:
		_japanese.visible = effects > 0.01
	if _compute:
		_compute.visible = effects > 0.01
	if _record:
		_record.visible = effects > 0.01
	if _indicator:
		_indicator.visible = effects > 0.01
	for mark in get_children():
		if mark is Control and str(mark.name).begins_with("Registration"):
			mark.visible = effects > 0.01


func _refresh_status() -> void:
	_last_phase = Game.phase
	var state := "IDLE"
	match Game.phase:
		Game.Phase.BOOT:
			state = "STANDBY"
		Game.Phase.DREAM:
			state = "DREAM / LIVE"
		Game.Phase.PLAYING:
			state = "FIELD / LIVE"
		Game.Phase.INTRO:
			state = "INITIALIZING"
		Game.Phase.READING:
			state = "DOCUMENT OPEN"
		Game.Phase.JOURNAL:
			state = "JOURNAL / OPEN"
		Game.Phase.PAUSED:
			state = "HOLD"
		Game.Phase.DIALOGUE:
			state = "VOICE / ACTIVE"
		Game.Phase.CAUGHT:
			state = "SIGNAL LOST"
		Game.Phase.ESCAPED:
			state = "END OF RECORD"
	if _status:
		_status.text = "OD-7  //  %s" % state
	if _record:
		var record_state := "記録中"
		if Game.phase == Game.Phase.PAUSED:
			record_state = "一時停止"
		elif Game.phase == Game.Phase.CAUGHT:
			record_state = "信号消失"
		elif Game.phase == Game.Phase.ESCAPED:
			record_state = "記録終了"
		_record.text = "%s  /  夢の記録" % record_state
