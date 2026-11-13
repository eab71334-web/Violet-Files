extends Screen
## التفاوض مع العميل (الوثيقة 6.1).

var eng: NegotiationEngine
var case_def: Dictionary
var face: FaceView
var offer_label: Label
var line_label: Label
var tell_label: Label
var btn_row: VBoxContainer


func _ready() -> void:
	setup(Loc.t("negotiation_title"))
	case_def = Game.load_case(Game.pending_case)
	if case_def.is_empty():
		Game.goto("home")
		return
	var client: Dictionary = case_def["client"]
	var c2: Dictionary = client.duplicate()
	if Game.money < 100:
		# توازن ديناميكي: لو فلوسك تحت 100 تجيك عروض أكثر وأسهل
		c2["opening"] = int(round(float(c2["opening"]) * 1.2))
		c2["patience"] = int(c2["patience"]) + 1
		c2["max"] = int(round(float(c2["max"]) * 1.2))
	eng = NegotiationEngine.new(c2)

	box.add_child(UI.label(Loc.pick(client["name"]), 44, UI.GOLD, true))
	face = FaceView.new()
	face.skin = Color(client.get("skin", "#D9B79A"))
	box.add_child(face)
	line_label = UI.label(Loc.pick(client["intro"]), 32, UI.TEXT, true)
	box.add_child(line_label)
	tell_label = UI.label("", 28, UI.MUTED, true)
	box.add_child(tell_label)
	offer_label = UI.label("", 64, UI.GOLD, true)
	box.add_child(offer_label)
	btn_row = VBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	box.add_child(btn_row)
	_refresh()


func _refresh() -> void:
	offer_label.text = Loc.f("offer_fmt", [eng.offer])
	face.anger = eng.anger()
	face.tension = eng.anger() if eng.honest_anger else 15.0
	face.fake_anger = (not eng.honest_anger) and eng.rejects > 0
	tell_label.text = Loc.t(eng.tell_key())
	for c in btn_row.get_children():
		btn_row.remove_child(c)
		c.queue_free()
	if eng.state == NegotiationEngine.State.OPEN:
		btn_row.add_child(UI.button(Loc.t("accept"), _accept))
		btn_row.add_child(UI.button(Loc.t("reject"), _reject))
		btn_row.add_child(UI.button(Loc.t("kick_out"), _kick))


func _accept() -> void:
	var price := eng.accept()
	Game.start_case(Game.pending_case, price)
	toast(Loc.f("deal_made", [price]))
	await get_tree().create_timer(0.9).timeout
	Game.goto("briefing")


func _reject() -> void:
	var r := eng.reject()
	if r == "explode":
		line_label.text = Loc.t("client_explodes")
		_leave_angry()
	else:
		var keys := ["client_line_1", "client_line_2", "client_line_3", "client_line_4"]
		line_label.text = Loc.t(keys[mini(eng.rejects - 1, keys.size() - 1)])
		if eng.at_cap():
			line_label.text += "\n" + Loc.t("client_cap")
		_refresh()


func _kick() -> void:
	eng.kick_out()
	line_label.text = Loc.t("you_kicked")
	_leave_angry()


func _leave_angry() -> void:
	# الطرد الكثير يضر سمعتك، والعميل المطرود يعود لاحقًا كشاهد أو عدو.
	Game.change_rep("downtown", -2)
	Game.decisions["expelled_" + Game.pending_case] = true
	Game.pending_case = ""
	face.anger = 100.0
	for c in btn_row.get_children():
		btn_row.remove_child(c)
		c.queue_free()
	btn_row.add_child(UI.button(Loc.t("back_office"), func(): Game.goto("home")))
