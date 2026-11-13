class_name UI
extends RefCounted
## أدوات بناء الواجهة بالكود + الثيم البنفسجي (لوحة الألوان من الوثيقة).

const BG := Color("0B0A14")
const UV := Color("8A2BE2")
const GLOW := Color("B66DFF")
const GOLD := Color("F2B84B")
const RED := Color("D7263D")
const TEXT := Color("EDEAF5")
const PANEL := Color("17142A")
const MUTED := Color("8F8AA8")


static func fs(base: int) -> int:
	var k := 1.25 if Game.settings.get("big_font", false) else 1.0
	return int(base * k)


static func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	var font_path := "res://assets/fonts/Cairo-Regular.ttf"
	if not ResourceLoader.exists(font_path):
		font_path = "res://assets/fonts/DejaVuSans.ttf"
	if ResourceLoader.exists(font_path):
		t.default_font = load(font_path)
	t.default_font_size = fs(34)
	t.set_stylebox("normal", "Button", _box(PANEL, UV, 2, 20))
	t.set_stylebox("hover", "Button", _box(Color("221C40"), GLOW, 3, 20))
	t.set_stylebox("pressed", "Button", _box(UV, GLOW, 3, 20))
	t.set_stylebox("disabled", "Button", _box(Color("100E1C"), Color("3A3358"), 1, 20))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GLOW, 2, 20))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("6C6784"))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, Color("3A3358"), 2, 22))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_color", "CheckButton", TEXT)
	return t


static func label(text: String, size: int = 34, color: Color = TEXT, center: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, cb: Callable, height: int = 110) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", fs(34))
	b.pressed.connect(cb)
	return b


## بطاقة (لوحة بإطار) ترجع الـ VBox الداخلي لإضافة المحتوى.
static func card(parent: Control) -> VBoxContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	return v


static func bar(value: float, maxv: float, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = maxv
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 26)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("100E1C")
	bg.set_corner_radius_all(12)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	return b


static func stars(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(3 - n)
