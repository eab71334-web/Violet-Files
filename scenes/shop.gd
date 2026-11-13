extends Screen
## متجر «أبو يعقوب للعتاد» (الوثيقة 8 و16): أدوات بنفسجية وهواتف.


func _ready() -> void:
	setup(Loc.t("shop_title"))
	_render()


func _render() -> void:
	clear_box()
	box.add_child(UI.label(Loc.t("shop_intro"), 30, UI.MUTED, true))
	box.add_child(UI.label(Loc.t("tools"), 38, UI.GLOW))
	for id in Game.TOOLS:
		_row(id, Game.TOOLS[id], false)
	box.add_child(UI.label(Loc.t("phones"), 38, UI.GLOW))
	for id in Game.PHONES:
		_row(id, Game.PHONES[id], true)
	box.add_child(UI.button(Loc.t("back"), func(): Game.goto(Game.return_to), 90))


func _row(id: String, d: Dictionary, is_phone: bool) -> void:
	var have: bool = id in Game.owned
	var price := int(d["price"])
	var txt := Loc.pick(d)
	if is_phone:
		txt += "  (x%.2f)" % float(d["quality"])
	if have:
		txt += "  ✔"
	else:
		txt += "  — %d" % price
	var b := UI.button(txt, func(): _buy(id, price, is_phone), 90)
	b.disabled = have
	box.add_child(b)


func _buy(id: String, price: int, is_phone: bool) -> void:
	if not Game.spend(price):
		toast(Loc.t("not_enough"))
		return
	Game.owned.append(id)
	Game.save()
	toast(Loc.t("bought"))
	_render()
