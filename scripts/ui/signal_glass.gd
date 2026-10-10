extends CanvasLayer

## A quiet CRT pass shared by every screen. Japanese corner marks belong to
## the instrument display, while the center of the image stays unobstructed.
const CRT_SHADER := preload("res://shaders/signal_glass.gdshader")

var _glass: ColorRect
var _material: ShaderMaterial
var _status: Label
var _japanese: Label
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
	_flicker_left = maxf(_flicker_left - delta, 0.0)
	_next_flicker -= delta
	if _next_flicker <= 0.0:
		_next_flicker = randf_range(5.0, 11.0)
		_flicker_left = randf_range(0.025, 0.055)
	if _material:
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
	_indicator = ColorRect.new()
	_indicator.color = Color(UiChrome.SIGNAL, 0.82)
	_indicator.position = Vector2(12.0, 25.0)
	indicator_size()
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_indicator)


func indicator_size() -> void:
	_indicator.size = Vector2(4.0, 8.0)


func _sync_strength() -> void:
	if not _material:
		return
	var effects := float(Game.settings.screen_effects) if Game.settings else 1.0
	_material.set_shader_parameter("strength", clampf(effects, 0.0, 1.0) * 0.14)
	if _status:
		_status.visible = effects > 0.01
	if _japanese:
		_japanese.visible = effects > 0.01
	if _indicator:
		_indicator.visible = effects > 0.01


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
