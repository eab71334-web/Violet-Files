extends Screen
## القائمة الرئيسية (الوثيقة 3).

var _title: Label


func _ready() -> void:
	setup("", false)
	box.add_theme_constant_override("separation", 26)
	box.add_child(Control.new())
	box.get_child(0).custom_minimum_size = Vector2(0, 160)

	_title = UI.label(Loc.t("game_title"), 84, UI.GLOW, true)
	box.add_child(_title)
	box.add_child(UI.label(Loc.t("tagline"), 34, UI.MUTED, true))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 80)
	box.add_child(gap)

	if Game.has_save():
		box.add_child(UI.button(Loc.t("continue"), _continue))
	box.add_child(UI.button(Loc.t("new_game"), _new_game))
	var mp := UI.button(Loc.t("multiplayer"), func(): toast(Loc.t("coming_soon")))
	mp.modulate = Color(1, 1, 1, 0.55)
	box.add_child(mp)
	box.add_child(UI.button(Loc.t("archive"), _open_archive))
	if Game.has_save():
		box.add_child(UI.button(Loc.t("shop"), _open_shop))
	box.add_child(UI.button(Loc.t("settings"), func(): Game.goto("settings")))
	box.add_child(UI.button(Loc.t("credits"), func(): Game.goto("credits")))

	# شعار يتوهج (الوثيقة: كتابة بنفسجية تتوهج)
	var tw := create_tween().set_loops()
	tw.tween_property(_title, "modulate", Color(1.4, 1.0, 1.6), 1.4)
	tw.tween_property(_title, "modulate", Color(0.8, 0.7, 1.0), 1.4)


func _open_archive() -> void:
	Game.return_to = "main_menu"
	Game.goto("archive")


func _open_shop() -> void:
	Game.return_to = "main_menu"
	Game.goto("shop")


func _continue() -> void:
	if Game.load_game():
		Game.goto("home")


func _new_game() -> void:
	Game.new_game()
	Game.goto("home")
