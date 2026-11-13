class_name Screen
extends Control
## قاعدة كل الشاشات: خلفية داكنة + شريط علوي (مال/يوم/أعصاب) + منطقة تمرير `box`.

var box: VBoxContainer
var topbar: Label
var _toast: Label


func setup(title: String = "", with_topbar: bool = true) -> void:
	theme = UI.make_theme()
	layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = UI.BG
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 36)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	margin.add_child(outer)

	if with_topbar:
		topbar = UI.label("", 28, UI.GOLD, true)
		outer.add_child(topbar)
		refresh_topbar()
		Game.state_changed.connect(refresh_topbar)
	if title != "":
		outer.add_child(UI.label(title, 56, UI.GLOW, true))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 22)
	scroll.add_child(box)

	_toast = UI.label("", 32, Color.WHITE, true)
	_toast.modulate.a = 0.0
	_toast.z_index = 50
	add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_top = -330
	_toast.offset_bottom = -150
	_toast.offset_left = 40
	_toast.offset_right = -40


func refresh_topbar() -> void:
	if topbar == null:
		return
	topbar.text = Loc.f("topbar", [Game.money, Game.day, Game.nerves])


func clear_box() -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func toast(msg: String) -> void:
	_toast.text = msg
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


func back_button(target: String, text_key: String = "back") -> Button:
	return UI.button(Loc.t(text_key), func(): Game.goto(target), 100)
