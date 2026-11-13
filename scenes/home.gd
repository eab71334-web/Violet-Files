extends Screen
## الشقة والمكتب (الوثيقة 7): تستيقظ، تفحص الهاتف، تنزل للمكتب وينتظرك العميل.

var tab := "flat"   # flat | office
var _phone_open := false


func _ready() -> void:
	setup("")
	_render()


func _render() -> void:
	clear_box()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var b1 := UI.button(Loc.t("tab_flat"), _show_flat, 90)
	var b2 := UI.button(Loc.t("tab_office"), _show_office, 90)
	(b1 if tab == "flat" else b2).disabled = true
	row.add_child(b1)
	row.add_child(b2)
	if tab == "flat":
		_flat()
	else:
		_office()
	box.add_child(UI.button(Loc.t("menu"), _to_menu, 90))


func _show_flat() -> void:
	tab = "flat"
	_render()


func _show_office() -> void:
	tab = "office"
	_render()


func _to_menu() -> void:
	Game.save()
	Game.goto("main_menu")


func _flat() -> void:
	var apt: Dictionary = Game.APARTMENTS[Game.apartment_tier]
	var c := UI.card(box)
	c.add_child(UI.label(Loc.pick(apt), 44, UI.GLOW, true))
	c.add_child(UI.label(Loc.f("rent_info", [Game.rent_now(), maxi(0, Game.next_rent_day - Game.day)]), 32, UI.GOLD))
	c.add_child(UI.label(Loc.f("nerves_info", [Game.nerves]), 30))
	c.add_child(UI.bar(Game.nerves, 100, UI.UV))

	box.add_child(UI.button(Loc.t("check_phone"), _toggle_phone))
	if _phone_open:
		_phone_card()
	box.add_child(UI.button(Loc.t("sleep"), _sleep))


func _phone_card() -> void:
	var c := UI.card(box)
	c.add_child(UI.label(Loc.t("phone_messages"), 36, UI.GLOW))
	var due := Game.next_rent_day - Game.day
	c.add_child(UI.label(Loc.f("msg_rent", [Game.rent_now(), maxi(0, due)]), 30))
	if Game.money < 150:
		c.add_child(UI.label(Loc.t("msg_low_money"), 30, UI.RED))
	if Game.next_case_id() != "":
		c.add_child(UI.label(Loc.t("msg_client_waiting"), 30, UI.GOLD))
	if Game.yasser_pieces.size() > 0:
		c.add_child(UI.label(Loc.f("msg_yasser", [Game.yasser_pieces.size()]), 30, UI.GLOW))
	else:
		c.add_child(UI.label(Loc.t("msg_yasser_none"), 30, UI.MUTED))


func _toggle_phone() -> void:
	_phone_open = not _phone_open
	_render()


func _sleep() -> void:
	var msg := Game.sleep()
	_phone_open = false
	_render()
	toast(Loc.t("sleep_" + msg))


func _office() -> void:
	var c := UI.card(box)
	c.add_child(UI.label(Loc.t("office_title"), 44, UI.GLOW, true))
	c.add_child(UI.label(Loc.t("office_desc"), 30, UI.MUTED))
	var next_id := Game.next_case_id()
	if next_id == "":
		c.add_child(UI.label(Loc.t("no_cases"), 32, UI.GOLD))
	else:
		box.add_child(UI.button(Loc.t("wait_client"), func(): _client_arrives(next_id)))
	box.add_child(UI.button(Loc.t("shop_abu_yaqoub"), _open_shop))
	box.add_child(UI.button(Loc.t("archive"), _open_archive))


func _open_shop() -> void:
	Game.return_to = "home"
	Game.goto("shop")


func _open_archive() -> void:
	Game.return_to = "home"
	Game.goto("archive")


func _client_arrives(id: String) -> void:
	Game.pending_case = id
	Game.save()
	Game.goto("negotiation")
