extends Screen
## إحاطة القضية + اختيار الحقيبة (سعة محدودة - الوثيقة 6.4).

var case_def: Dictionary
var _list: VBoxContainer


func _ready() -> void:
	setup(Loc.t("briefing_title"))
	case_def = Game.load_case(Game.active_case)
	var c := UI.card(box)
	c.add_child(UI.label(Loc.pick(case_def["title"]), 46, UI.GOLD, true))
	c.add_child(UI.label(Loc.pick(Game.DISTRICTS[case_def["district"]]), 30, UI.MUTED, true))
	c.add_child(UI.label(Loc.pick(case_def["summary"]), 32))
	c.add_child(UI.label(Loc.f("price_agreed", [Game.case_state["price"]]), 34, UI.GOLD))
	c.add_child(UI.label(Loc.f("hours_limit", [Game.case_state["hours_left"]]), 30, UI.MUTED))

	box.add_child(UI.label(Loc.f("bag_title", [Game.BAG_SIZE]), 38, UI.GLOW))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	box.add_child(_list)
	_render_bag()
	box.add_child(UI.button(Loc.t("start_case"), func(): Game.goto("case_hub")))


func _render_bag() -> void:
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	var bag: Array = Game.case_state["bag"]
	for t in Game.owned:
		if not Game.TOOLS.has(t):
			continue
		var on: bool = t in bag
		var b := UI.button(("✔ " if on else "") + Loc.pick(Game.TOOLS[t]), func(): _toggle(t), 90)
		if on:
			b.add_theme_color_override("font_color", UI.GLOW)
		_list.add_child(b)


func _toggle(t: String) -> void:
	var bag: Array = Game.case_state["bag"]
	if t in bag:
		if t == "flashlight":
			return   # الكشاف دائمًا في الحقيبة
		bag.erase(t)
	elif bag.size() < Game.BAG_SIZE:
		bag.append(t)
	else:
		toast(Loc.t("bag_full"))
	_render_bag()
